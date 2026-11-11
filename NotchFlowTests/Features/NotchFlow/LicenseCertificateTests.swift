import XCTest
import CryptoKit
@testable import NotchFlow

/// Test certificate authority + mock backend that behaves like docs/licensing-api.md.
private final class MockBackend: LicenseBackend, @unchecked Sendable {
    let signer = Curve25519.Signing.PrivateKey()
    var keyId = "k1"
    var now: () -> Date = Date.init
    var audience = "app.notchflow.mac"
    var refreshError: LicenseBackendError?
    var deactivateError: LicenseBackendError?
    var activateError: LicenseBackendError?
    var devices: [String: String] = [:] // activationId -> device public key (base64)
    var seats = 2
    var seenNonces: Set<String> = []

    func certificate(activationId: String, deviceKey: String, issuedAt: Date? = nil, ttl: TimeInterval = 30 * 86_400,
                     entitlements: [String] = ["notchflow.pro"], audience: String? = nil) -> String {
        let issued = issuedAt ?? now()
        let hash = DeviceIdentity.sha256Hex(Data(base64Encoded: deviceKey)!)
        let claims: [String: Any] = [
            "schemaVersion": 1, "issuer": "notchflow", "audience": audience ?? self.audience,
            "licenseId": "lic-1", "activationId": activationId, "devicePublicKeyHash": hash,
            "entitlements": entitlements, "licenseType": "lifetime",
            "issuedAt": Self.iso(issued), "refreshAfter": Self.iso(issued.addingTimeInterval(86_400)),
            "expiresAt": Self.iso(issued.addingTimeInterval(ttl)), "keyId": keyId
        ]
        let payload = Base64URL.encode(try! JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys]))
        let message = "NFC2.\(payload)"
        return "\(message).\(Base64URL.encode(try! signer.signature(for: Data(message.utf8))))"
    }

    static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    func activate(licenseKey: String, devicePublicKey: String, deviceName: String) async throws -> String {
        if let activateError { throw activateError }
        if let existing = devices.first(where: { $0.value == devicePublicKey }) {
            return certificate(activationId: existing.key, deviceKey: devicePublicKey)
        }
        guard devices.count < seats else { throw LicenseBackendError.limitReached }
        let id = "act-\(devices.count + 1)"
        devices[id] = devicePublicKey
        return certificate(activationId: id, deviceKey: devicePublicKey)
    }

    func verify(_ id: String, _ request: SignedRequest, path: String) throws {
        guard let device = devices[id], device == request.devicePublicKey,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: device)!),
              let signature = Base64URL.decode(Substring(request.signature)),
              key.isValidSignature(signature, for: SignedRequest.message(method: "POST", path: path, timestamp: request.timestamp,
                                                                         nonce: request.nonce, body: request.body)),
              seenNonces.insert(request.nonce).inserted else { throw LicenseBackendError.revoked }
    }

    func refresh(activationId: String, request: SignedRequest) async throws -> String {
        if let refreshError { throw refreshError }
        try verify(activationId, request, path: HTTPLicenseBackend.refreshPath)
        return certificate(activationId: activationId, deviceKey: devices[activationId]!)
    }

    func deactivate(activationId: String, request: SignedRequest) async throws {
        if let deactivateError { throw deactivateError }
        try verify(activationId, request, path: HTTPLicenseBackend.deactivatePath)
        devices[activationId] = nil
    }
}

@MainActor
final class LicenseCertificateTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var defaults: UserDefaults!
    private var suite = ""
    private var backend: MockBackend!

    override func setUp() {
        suite = "NotchFlowTests.cert.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        backend = MockBackend()
        backend.now = { [unowned self] in self.clock }
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    private func makeStore(_ storage: LicenseSecureStorage = InMemoryLicenseStorage(),
                           keys: [String: Curve25519.Signing.PublicKey]? = nil) -> LicenseStore {
        LicenseStore(defaults: defaults, storage: storage, backend: backend,
                     certificateKeys: keys ?? ["k1": backend.signer.publicKey], audience: "app.notchflow.mac",
                     now: { [unowned self] in self.clock })
    }

    // MARK: Verifier

    private func verify(_ token: String, device: DeviceIdentity, keys: [String: Curve25519.Signing.PublicKey]? = nil,
                        audience: String = "app.notchflow.mac") throws -> LicenseCertificate {
        try LicenseCertificate.verify(token, trustedKeys: keys ?? ["k1": backend.signer.publicKey], audience: audience,
                                      devicePublicKeyHash: device.publicKeyHash, now: clock)
    }

    func testVerifierRejectsTamperingWrongAppDeviceKeyAndEntitlement() throws {
        let device = DeviceIdentity(storage: InMemoryLicenseStorage())
        let token = backend.certificate(activationId: "a", deviceKey: device.publicKeyBase64)
        XCTAssertEqual(try verify(token, device: device).claims.activationId, "a")

        var parts = token.split(separator: ".").map(String.init)
        let otherPayload = backend.certificate(activationId: "b", deviceKey: device.publicKeyBase64).split(separator: ".")[1]
        parts[1] = String(otherPayload)
        XCTAssertThrowsError(try verify(parts.joined(separator: "."), device: device)) {
            XCTAssertEqual($0 as? LicenseCertificate.VerificationError, .invalidSignature)
        }
        XCTAssertThrowsError(try verify(token, device: device, audience: "com.other.app")) {
            XCTAssertEqual($0 as? LicenseCertificate.VerificationError, .wrongAudience)
        }
        XCTAssertThrowsError(try verify(token, device: DeviceIdentity(storage: InMemoryLicenseStorage()))) {
            XCTAssertEqual($0 as? LicenseCertificate.VerificationError, .wrongDevice)
        }
        XCTAssertThrowsError(try verify(token, device: device, keys: ["k2": backend.signer.publicKey])) {
            XCTAssertEqual($0 as? LicenseCertificate.VerificationError, .unknownKey)
        }
        let noPro = backend.certificate(activationId: "a", deviceKey: device.publicKeyBase64, entitlements: ["other"])
        XCTAssertThrowsError(try verify(noPro, device: device)) {
            XCTAssertEqual($0 as? LicenseCertificate.VerificationError, .missingEntitlement)
        }
        XCTAssertThrowsError(try verify("NFC2.abc.def", device: device))
    }

    func testKeyRotationAcceptsAnyTrustedKey() throws {
        let device = DeviceIdentity(storage: InMemoryLicenseStorage())
        let oldKey = Curve25519.Signing.PrivateKey().publicKey
        backend.keyId = "k2"
        let token = backend.certificate(activationId: "a", deviceKey: device.publicKeyBase64)
        XCTAssertNoThrow(try verify(token, device: device, keys: ["k1": oldKey, "k2": backend.signer.publicKey]))
    }

    // MARK: Store

    func testActivateSameMacTwiceUsesOneSeatAndThirdMacIsRefused() async throws {
        let first = InMemoryLicenseStorage()
        try await makeStore(first).activateOnline("KEY")
        try await makeStore(first).activateOnline("KEY")
        XCTAssertEqual(backend.devices.count, 1, "same device must not take a second seat")
        try await makeStore().activateOnline("KEY")
        XCTAssertEqual(backend.devices.count, 2)
        let third = makeStore()
        do {
            try await third.activateOnline("KEY")
            XCTFail("third Mac must be refused")
        } catch {
            XCTAssertEqual(error as? LicenseBackendError, .limitReached)
        }
        XCTAssertFalse(third.hasPro)
    }

    func testProSurvivesRelaunchWithoutNetwork() async throws {
        let storage = InMemoryLicenseStorage()
        try await makeStore(storage).activateOnline("KEY")
        backend.refreshError = .network
        let relaunched = makeStore(storage)
        XCTAssertEqual(relaunched.state, .proVerified)
        XCTAssertTrue(relaunched.allows(.fileTray))
    }

    func testNetworkFailureIsNeverRevocation() async throws {
        let store = makeStore()
        try await store.activateOnline("KEY")
        backend.refreshError = .network
        clock += 2 * 86_400
        await store.revalidateIfNeeded()
        XCTAssertEqual(store.state, .proOffline)
        XCTAssertTrue(store.hasPro)
        clock += 29 * 86_400 // past expiresAt, inside 14-day grace
        XCTAssertEqual(store.state, .proOffline)
        XCTAssertTrue(store.hasPro)
        clock += 14 * 86_400 // grace over
        XCTAssertEqual(store.state, .needsReverification)
        XCTAssertFalse(store.hasPro)
        backend.refreshError = nil
        await store.revalidateIfNeeded()
        XCTAssertEqual(store.state, .proVerified, "a later successful check restores Pro")
    }

    func testServerErrorKeepsPro() async throws {
        let store = makeStore()
        try await store.activateOnline("KEY")
        backend.refreshError = .server
        clock += 2 * 86_400
        await store.revalidateIfNeeded()
        XCTAssertTrue(store.hasPro)
    }

    func testRevokedAtRefreshTurnsProOff() async throws {
        let store = makeStore()
        try await store.activateOnline("KEY")
        backend.refreshError = .revoked
        clock += 2 * 86_400
        await store.revalidateIfNeeded()
        XCTAssertEqual(store.state, .revoked)
        XCTAssertFalse(store.hasPro)
    }

    func testRefreshIsSignedAndRenewsCertificate() async throws {
        let store = makeStore()
        try await store.activateOnline("KEY")
        let firstIssued = try XCTUnwrap(store.certificate?.claims.issuedAt)
        clock += 2 * 86_400
        await store.revalidateIfNeeded()
        XCTAssertGreaterThan(try XCTUnwrap(store.certificate?.claims.issuedAt), firstIssued)
        XCTAssertEqual(backend.seenNonces.count, 1)
    }

    func testDeactivateFreesSeatOnlyAfterServerConfirms() async throws {
        let store = makeStore()
        try await store.activateOnline("KEY")
        backend.deactivateError = .network
        do {
            try await store.deactivateOnline()
            XCTFail("expected network error")
        } catch {}
        XCTAssertTrue(store.hasPro, "kept until the server confirms")
        XCTAssertEqual(backend.devices.count, 1)
        backend.deactivateError = nil
        try await store.deactivateOnline()
        XCTAssertEqual(backend.devices.count, 0)
        XCTAssertNil(store.certificate)
        XCTAssertEqual(store.state, .free)
    }

    func testForgedDeactivateFromAnotherDeviceIsRejected() async throws {
        try await makeStore().activateOnline("KEY")
        let attacker = DeviceIdentity(storage: InMemoryLicenseStorage())
        let body = try HTTPLicenseBackend.activationBody("act-1")
        let forged = try SignedRequest.make(method: "POST", path: HTTPLicenseBackend.deactivatePath, body: body,
                                            identity: attacker, now: clock)
        do {
            try await backend.deactivate(activationId: "act-1", request: forged)
            XCTFail("forged request must fail")
        } catch {}
        XCTAssertEqual(backend.devices.count, 1)
    }

    func testCertificateFromAnotherMacIsIgnored() async throws {
        let storage = InMemoryLicenseStorage()
        let otherDevice = DeviceIdentity(storage: InMemoryLicenseStorage())
        storage.set(Data(backend.certificate(activationId: "x", deviceKey: otherDevice.publicKeyBase64).utf8), for: "certificate")
        let store = makeStore(storage)
        XCTAssertNil(store.certificate)
        XCTAssertFalse(store.hasPro)
    }

    func testHTTPErrorMapping() {
        func body(_ code: String) -> Data { Data("{\"error\":\"\(code)\"}".utf8) }
        XCTAssertEqual(HTTPLicenseBackend.error(status: 409, data: body("limit_reached")), .limitReached)
        XCTAssertEqual(HTTPLicenseBackend.error(status: 403, data: body("revoked")), .revoked)
        XCTAssertEqual(HTTPLicenseBackend.error(status: 429, data: Data()), .rateLimited)
        XCTAssertEqual(HTTPLicenseBackend.error(status: 503, data: Data()), .server)
    }
}
