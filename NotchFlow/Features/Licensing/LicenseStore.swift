import Foundation
import Combine
import CryptoKit

/// Pro access from three sources: an online key (Lemon Squeezy, 2 Macs), a 14-day trial,
/// or an offline signed `NF1` token (developer keys and keys issued by hand).
@MainActor
final class LicenseStore: ObservableObject {
    static let shared = LicenseStore()

    static let trialLength: TimeInterval = 14 * 86_400
    static let revalidateInterval: TimeInterval = 7 * 86_400
    static let offlineGrace: TimeInterval = 30 * 86_400
    /// Backend certificates: background refresh every 24 h; usable 14 days past `expiresAt` while offline.
    static let certificateRefreshInterval: TimeInterval = 86_400
    static let certificateOfflineGrace: TimeInterval = 14 * 86_400

    enum State: Equatable {
        case free
        case activating
        case trial(daysLeft: Int)
        case proVerified
        /// Pro still works, but the last check couldn't reach the server.
        case proOffline
        /// The certificate ran out while offline; Pro is paused until the next successful check.
        case needsReverification
        case revoked
    }

    /// Online key saved for this Mac.
    struct OnlineRecord: Codable, Equatable {
        var key: String
        var instanceID: String
        var status: ProviderLicense.Status
        var lastValidated: Date
        var activationLimit: Int?
        var activationUsage: Int?
    }

    enum ActivationError: Error, Equatable { case notConfigured }

    private let defaults: UserDefaults
    private let verifier: LicenseVerifier?
    private let storage: LicenseSecureStorage
    private let provider: LicenseProvider?
    private let backend: LicenseBackend?
    private let trustedKeys: [String: Curve25519.Signing.PublicKey]
    private let audience: String
    private lazy var identity = DeviceIdentity(storage: storage)
    private var refreshTimer: Timer?
    private let now: () -> Date
    private var expirationTimer: Timer?
    private static let proKey = "notchflow.license.pro"
    private static let developerKey = "notchflow.license.developer"
    private static let onlineAccount = "online"
    private static let trialAccount = "trialStart"
    private static let certificateAccount = "certificate"
    private static let revokedAccount = "revoked"

    @Published private(set) var revision = 0
    @Published private(set) var online: OnlineRecord?
    @Published private(set) var trialStart: Date?
    @Published private(set) var isWorking = false
    @Published private(set) var certificate: LicenseCertificate?
    @Published private(set) var isRevoked = false
    /// True after a refresh failed for a network or server reason (never means revoked).
    @Published private(set) var lastRefreshFailed = false
    /// Set by a `notchflow://activate` link; Settings opens the License page and clears it.
    @Published var pendingOpenLicensePage = false

    init(defaults: UserDefaults = .standard,
         publicKeyData: Data? = nil,
         storage: LicenseSecureStorage? = nil,
         provider: LicenseProvider? = nil,
         backend: LicenseBackend? = nil,
         certificateKeys: [String: Curve25519.Signing.PublicKey]? = nil,
         audience: String? = nil,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        var configured = (Bundle.main.object(forInfoDictionaryKey: "NotchFlowLicensePublicKey") as? String)
            .flatMap { Data(base64Encoded: $0) }
        #if DEBUG
        // Local test issuer only. Release builds contain no test authority.
        if configured?.count != 32 {
            configured = Data(base64Encoded: "003TiGsrxkZglyDLBVoTQpTU6iJNJy4u7F2go941fMs=")
        }
        #endif
        self.verifier = (publicKeyData ?? configured).flatMap { try? LicenseVerifier(publicKeyData: $0) }
        let isTests = AppEnvironment.isRunningTests
        self.storage = storage ?? (isTests ? InMemoryLicenseStorage() : KeychainLicenseStorage())
        self.provider = provider ?? (isTests ? nil : LemonSqueezyLicenseProvider.configured)
        self.backend = backend ?? (isTests ? nil : HTTPLicenseBackend.configured)
        var keys = certificateKeys ?? LicenseCertificate.configuredKeys()
        #if DEBUG
        if keys.isEmpty, certificateKeys == nil, let dev = Self.debugCertificateKey { keys["dev-1"] = dev }
        #endif
        self.trustedKeys = keys
        self.audience = audience ?? Bundle.main.bundleIdentifier ?? "app.notchflow.mac"
        self.now = now
        self.isRevoked = self.storage.data(for: Self.revokedAccount) != nil
        self.online = self.storage.data(for: Self.onlineAccount).flatMap { try? JSONDecoder().decode(OnlineRecord.self, from: $0) }
        self.trialStart = self.storage.data(for: Self.trialAccount).flatMap { try? JSONDecoder().decode(Date.self, from: $0) }
        if let token = self.storage.data(for: Self.certificateAccount).flatMap({ String(data: $0, encoding: .utf8) }) {
            self.certificate = verifyCertificate(token)
        }
        scheduleExpirationRefresh()
        if !isTests {
            Task { await self.revalidateIfNeeded() }
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in await self?.revalidateIfNeeded() }
            }
        }
    }

    #if DEBUG
    /// Local test certificate authority for Debug builds only.
    private static let debugCertificateKey = Data(base64Encoded: "003TiGsrxkZglyDLBVoTQpTU6iJNJy4u7F2go941fMs=")
        .flatMap { try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }
    #endif

    /// Whether this build talks to the NotchFlow backend (true) or straight to the store (false).
    var usesBackend: Bool { backend != nil }

    var state: State {
        if isRevoked { return .revoked }
        if let certificate {
            let claims = certificate.claims
            if now() < claims.expiresAt {
                return lastRefreshFailed && now() >= claims.refreshAfter ? .proOffline : .proVerified
            }
            if now() < claims.expiresAt.addingTimeInterval(Self.certificateOfflineGrace) { return .proOffline }
            return .needsReverification
        }
        if isWorking { return .activating }
        if validToken(for: .pro) { return .proVerified }
        if let online {
            if online.status != .active { return .revoked }
            return hasOnlinePro ? .proVerified : .needsReverification
        }
        if isTrialActive { return .trial(daysLeft: trialDaysLeft) }
        return .free
    }

    private func verifyCertificate(_ token: String) -> LicenseCertificate? {
        try? LicenseCertificate.verify(token, trustedKeys: trustedKeys, audience: audience,
                                       devicePublicKeyHash: identity.publicKeyHash, now: now())
    }

    private func saveCertificate(_ certificate: LicenseCertificate?) {
        storage.set(certificate.map { Data($0.token.utf8) }, for: Self.certificateAccount)
        self.certificate = certificate
        revision += 1
    }

    private func setRevoked(_ revoked: Bool) {
        storage.set(revoked ? Data([1]) : nil, for: Self.revokedAccount)
        isRevoked = revoked
    }

    // MARK: Access

    var isConfigured: Bool { verifier != nil || provider != nil || backend != nil }
    var hasPro: Bool { hasPaidPro || isTrialActive }
    var hasPaidPro: Bool { validToken(for: .pro) || hasOnlinePro }
    var hasDeveloperAccess: Bool { validToken(for: .developer) }

    var hasOnlinePro: Bool {
        if isRevoked { return false }
        if let certificate {
            return now() < certificate.claims.expiresAt.addingTimeInterval(Self.certificateOfflineGrace)
        }
        guard let online, online.status == .active else { return false }
        return now().timeIntervalSince(online.lastValidated) < Self.offlineGrace
    }

    var isTrialActive: Bool { trialDaysLeft > 0 }
    var canStartTrial: Bool { trialStart == nil && !hasPaidPro }
    var trialDaysLeft: Int {
        guard let trialStart else { return 0 }
        let left = Self.trialLength - now().timeIntervalSince(trialStart)
        return left > 0 ? Int((left / 86_400).rounded(.up)) : 0
    }

    // MARK: Trial

    func startTrial() {
        guard canStartTrial else { return }
        let start = now()
        storage.set(try? JSONEncoder().encode(start), for: Self.trialAccount)
        trialStart = start
        scheduleExpirationRefresh()
        revision += 1
    }

    // MARK: Online keys

    /// Activates a short store key on this Mac (uses 1 of the key's 2 seats).
    func activateOnline(_ rawKey: String, instanceName: String = Host.current().localizedName ?? "Mac") async throws {
        let key = Self.normalize(rawKey)
        guard !key.isEmpty else { throw LicenseProviderError.invalidKey }
        if let backend {
            isWorking = true
            defer { isWorking = false }
            let token = try await backend.activate(licenseKey: key, devicePublicKey: identity.publicKeyBase64,
                                                   deviceName: instanceName)
            guard let certificate = verifyCertificate(token) else { throw LicenseBackendError.server }
            setRevoked(false)
            lastRefreshFailed = false
            saveCertificate(certificate)
            return
        }
        guard let provider else { throw ActivationError.notConfigured }
        isWorking = true
        defer { isWorking = false }
        let license = try await provider.activate(key: key, instanceName: instanceName)
        guard license.status == .active, let instanceID = license.instanceID else {
            throw LicenseProviderError.invalidKey
        }
        save(OnlineRecord(key: key, instanceID: instanceID, status: license.status, lastValidated: now(),
                          activationLimit: license.activationLimit, activationUsage: license.activationUsage))
    }

    /// Frees this Mac's seat. With the backend, local data is cleared only after the server confirms;
    /// the store-direct path forgets the key even if the store can't be reached.
    func deactivateOnline() async throws {
        if let backend, let certificate {
            isWorking = true
            defer { isWorking = false }
            let id = certificate.claims.activationId
            let path = HTTPLicenseBackend.deactivatePath
            let request = try SignedRequest.make(method: "POST", path: path, body: HTTPLicenseBackend.activationBody(id),
                                                 identity: identity, now: now())
            try await backend.deactivate(activationId: id, request: request)
            saveCertificate(nil)
            return
        }
        guard let online else { return }
        isWorking = true
        defer { isWorking = false }
        try? await provider?.deactivate(key: online.key, instanceID: online.instanceID)
        save(nil)
    }

    /// Rechecks the key every 7 days. Network failures keep the current state (30-day grace).
    func revalidateIfNeeded(force: Bool = false) async {
        if let backend, let current = certificate {
            let claims = current.claims
            let due = force || now() >= claims.refreshAfter
                || now().timeIntervalSince(claims.issuedAt) >= Self.certificateRefreshInterval
            guard due, !isWorking else { return }
            do {
                let id = claims.activationId
                let request = try SignedRequest.make(method: "POST", path: HTTPLicenseBackend.refreshPath,
                                                     body: HTTPLicenseBackend.activationBody(id), identity: identity, now: now())
                let token = try await backend.refresh(activationId: id, request: request)
                guard let renewed = verifyCertificate(token) else {
                    lastRefreshFailed = true
                    return
                }
                lastRefreshFailed = false
                saveCertificate(renewed)
            } catch LicenseBackendError.revoked {
                setRevoked(true)
                saveCertificate(nil)
            } catch {
                // Network, server, rate limit: keep the certificate; offline grace applies.
                lastRefreshFailed = true
                revision += 1
            }
            return
        }
        guard let provider, var record = online else { return }
        guard force || now().timeIntervalSince(record.lastValidated) >= Self.revalidateInterval else { return }
        do {
            let license = try await provider.validate(key: record.key, instanceID: record.instanceID)
            record.status = license.status
            record.lastValidated = now()
            record.activationLimit = license.activationLimit ?? record.activationLimit
            record.activationUsage = license.activationUsage ?? record.activationUsage
            save(record)
        } catch LicenseProviderError.network {
            return
        } catch {
            record.status = .disabled
            save(record)
        }
    }

    private func save(_ record: OnlineRecord?) {
        storage.set(record.flatMap { try? JSONEncoder().encode($0) }, for: Self.onlineAccount)
        online = record
        revision += 1
    }

    /// Keys pasted from email often carry spaces, line breaks or lowercase letters.
    static func normalize(_ key: String) -> String {
        key.components(separatedBy: .whitespacesAndNewlines).joined().uppercased()
    }

    /// `notchflow://activate?key=…` (checkout redirect). Returns the key, if any.
    static func activationKey(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "notchflow", url.host?.lowercased() == "activate" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "key" }?.value
    }

    // MARK: Offline signed tokens (NF1)

    static func isSignedToken(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("NF1.")
    }

    func activate(_ token: String) throws -> LicenseVerifier.Kind {
        guard let verifier else { throw ActivationError.notConfigured }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let claims = try verifier.verify(trimmed)
        defaults.set(trimmed, forKey: key(for: claims.kind))
        scheduleExpirationRefresh()
        revision += 1
        return claims.kind
    }

    func deactivate(_ kind: LicenseVerifier.Kind) {
        defaults.removeObject(forKey: key(for: kind))
        scheduleExpirationRefresh()
        revision += 1
    }

    private func validToken(for kind: LicenseVerifier.Kind) -> Bool {
        guard let verifier, let token = defaults.string(forKey: key(for: kind)),
              let claims = try? verifier.verify(token) else { return false }
        return claims.kind == kind
    }

    private func key(for kind: LicenseVerifier.Kind) -> String {
        kind == .pro ? Self.proKey : Self.developerKey
    }

    /// Fires `revision` when a signed token or the trial runs out, so Pro gates update live.
    private func scheduleExpirationRefresh() {
        expirationTimer?.invalidate()
        var ends: [Date] = []
        if let trialStart { ends.append(trialStart.addingTimeInterval(Self.trialLength)) }
        if let verifier {
            ends += [LicenseVerifier.Kind.pro, .developer].compactMap { kind -> Date? in
                guard let token = defaults.string(forKey: key(for: kind)),
                      let claims = try? verifier.verify(token), claims.kind == kind,
                      let expiry = claims.expiresAt else { return nil }
                return Date(timeIntervalSince1970: Double(expiry))
            }
        }
        guard let next = ends.filter({ $0 > now() }).min() else { return }
        expirationTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, next.timeIntervalSince(now())), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleExpirationRefresh()
                self.revision += 1
            }
        }
    }
}
