import Foundation
import Combine

/// Local verification adapter. A future activation service must return signed tokens.
@MainActor
final class LicenseStore: ObservableObject {
    static let shared = LicenseStore()
    private let defaults: UserDefaults
    private let verifier: LicenseVerifier?
    private var expirationTimer: Timer?
    private static let proKey = "notchflow.license.pro"
    private static let developerKey = "notchflow.license.developer"
    @Published private(set) var revision = 0

    init(defaults: UserDefaults = .standard, publicKeyData: Data? = nil) {
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
        scheduleExpirationRefresh()
    }

    var isConfigured: Bool { verifier != nil }
    var hasPro: Bool { validToken(for: .pro) }
    var hasDeveloperAccess: Bool { validToken(for: .developer) }

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

    enum ActivationError: Error { case notConfigured }

    private func validToken(for kind: LicenseVerifier.Kind) -> Bool {
        guard let verifier, let token = defaults.string(forKey: key(for: kind)),
              let claims = try? verifier.verify(token) else { return false }
        return claims.kind == kind
    }

    private func key(for kind: LicenseVerifier.Kind) -> String {
        kind == .pro ? Self.proKey : Self.developerKey
    }

    private func scheduleExpirationRefresh() {
        expirationTimer?.invalidate()
        guard let verifier else { return }
        let expiries = [LicenseVerifier.Kind.pro, .developer].compactMap { kind -> Date? in
            guard let token = defaults.string(forKey: key(for: kind)),
                  let claims = try? verifier.verify(token), claims.kind == kind,
                  let expiry = claims.expiresAt else { return nil }
            return Date(timeIntervalSince1970: Double(expiry))
        }
        guard let next = expiries.min() else { return }
        expirationTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleExpirationRefresh()
                self.revision += 1
            }
        }
    }
}
