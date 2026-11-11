import XCTest
import CryptoKit
@testable import NotchFlow

final class LicenseVerifierTests: XCTestCase {
    private func token(_ claims: LicenseVerifier.Claims, key: Curve25519.Signing.PrivateKey) throws -> String {
        func encoded(_ data: Data) -> String {
            data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        let payload = encoded(try JSONEncoder().encode(claims))
        let message = "NF1.\(payload)"
        return "\(message).\(encoded(try key.signature(for: Data(message.utf8))))"
    }

    func testSignedProAndDeveloperLicenses() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        for kind in [LicenseVerifier.Kind.pro, .developer] {
            let claims = LicenseVerifier.Claims(version: 1, product: "NotchFlow", id: "test-1", kind: kind, expiresAt: nil)
            XCTAssertEqual(try verifier.verify(token(claims, key: key)), claims)
        }
    }

    func testRejectsWrongSigningKeyAndMalformedInput() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
        let claims = LicenseVerifier.Claims(version: 1, product: "NotchFlow", id: "1", kind: .pro, expiresAt: nil)
        XCTAssertThrowsError(try verifier.verify(token(claims, key: signer))) { XCTAssertEqual($0 as? LicenseVerifier.VerificationError, .invalidSignature) }
        XCTAssertThrowsError(try verifier.verify("NF1.invalid.bad")) { XCTAssertEqual($0 as? LicenseVerifier.VerificationError, .malformed) }
        XCTAssertThrowsError(try verifier.verify(String(repeating: "x", count: 4097))) { XCTAssertEqual($0 as? LicenseVerifier.VerificationError, .malformed) }
    }

    func testRejectsExpiredAndWrongProduct() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        let expired = LicenseVerifier.Claims(version: 1, product: "NotchFlow", id: "1", kind: .pro, expiresAt: 100)
        XCTAssertThrowsError(try verifier.verify(token(expired, key: key), now: Date(timeIntervalSince1970: 100))) { XCTAssertEqual($0 as? LicenseVerifier.VerificationError, .expired) }
        let other = LicenseVerifier.Claims(version: 1, product: "Other", id: "1", kind: .developer, expiresAt: nil)
        XCTAssertThrowsError(try verifier.verify(token(other, key: key))) { XCTAssertEqual($0 as? LicenseVerifier.VerificationError, .invalidClaims) }
    }

    @MainActor
    func testStoreSeparatesProAndDeveloperAndRejectsTampering() throws {
        let suite = "NotchFlowTests.license.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = Curve25519.Signing.PrivateKey()
        let store = LicenseStore(defaults: defaults, publicKeyData: key.publicKey.rawRepresentation)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.hasDeveloperAccess)
        let developer = LicenseVerifier.Claims(version: 1, product: "NotchFlow", id: "dev", kind: .developer, expiresAt: nil)
        XCTAssertEqual(try store.activate(token(developer, key: key)), .developer)
        XCTAssertTrue(store.hasDeveloperAccess)
        XCTAssertFalse(store.hasPro)
        let pro = LicenseVerifier.Claims(version: 1, product: "NotchFlow", id: "pro", kind: .pro, expiresAt: nil)
        let proToken = try token(pro, key: key)
        XCTAssertEqual(try store.activate(proToken), .pro)
        XCTAssertTrue(store.hasPro)
        defaults.set(proToken + "x", forKey: "notchflow.license.pro")
        XCTAssertFalse(store.hasPro)
        store.deactivate(.developer)
        XCTAssertFalse(store.hasDeveloperAccess)
    }
}
