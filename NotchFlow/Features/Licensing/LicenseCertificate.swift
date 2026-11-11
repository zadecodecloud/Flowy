import Foundation
import CryptoKit

// MARK: - Device identity

/// Per-install Ed25519 key pair. The private key never leaves the Keychain; the backend binds
/// each activation to the public key, and refresh/deactivate requests are signed with it.
/// Deleting the Keychain item (or reinstalling macOS) creates a new identity, which needs a seat
/// reset from support.
final class DeviceIdentity {
    private static let account = "deviceKey"
    let privateKey: Curve25519.Signing.PrivateKey

    init(storage: LicenseSecureStorage) {
        if let raw = storage.data(for: Self.account),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) {
            privateKey = key
        } else {
            privateKey = Curve25519.Signing.PrivateKey()
            storage.set(privateKey.rawRepresentation, for: Self.account)
        }
    }

    var publicKeyData: Data { privateKey.publicKey.rawRepresentation }
    var publicKeyBase64: String { publicKeyData.base64EncodedString() }
    var publicKeyHash: String { Self.sha256Hex(publicKeyData) }

    func sign(_ message: Data) throws -> Data { try privateKey.signature(for: message) }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Certificate

/// Pro certificate issued by the NotchFlow license backend.
/// Wire format: `NFC2.<base64url(payload JSON)>.<base64url(Ed25519 signature)>`.
/// The signature covers the ASCII bytes `NFC2.<base64url(payload)>` exactly as transmitted;
/// the payload is never re-serialized before verification.
struct LicenseCertificate: Equatable {
    struct Claims: Codable, Equatable {
        let schemaVersion: Int
        let issuer: String
        let audience: String
        let licenseId: String
        let activationId: String
        let devicePublicKeyHash: String
        let entitlements: [String]
        let licenseType: String
        let issuedAt: Date
        let refreshAfter: Date
        let expiresAt: Date
        let keyId: String
    }

    enum VerificationError: Error, Equatable {
        case malformed
        case unknownKey
        case invalidSignature
        case wrongIssuer
        case wrongAudience
        case wrongDevice
        case missingEntitlement
        case notYetValid
        case unsupportedSchema
    }

    static let prefix = "NFC2"
    static let issuer = "notchflow"
    static let proEntitlement = "notchflow.pro"

    let token: String
    let claims: Claims

    /// Verifies signature, keyId, issuer, audience, schema, device binding, entitlement and issue time.
    /// Expiry is not an error here: the store decides between Pro, offline grace and re-verification.
    static func verify(_ token: String,
                       trustedKeys: [String: Curve25519.Signing.PublicKey],
                       audience: String,
                       devicePublicKeyHash: String,
                       now: Date,
                       clockSkew: TimeInterval = 300) throws -> LicenseCertificate {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count <= 8192 else { throw VerificationError.malformed }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == Substring(prefix),
              let payload = Base64URL.decode(parts[1]),
              let signature = Base64URL.decode(parts[2]), signature.count == 64 else {
            throw VerificationError.malformed
        }
        // keyId is read before trusting the payload only to pick the key; everything else waits for the signature.
        guard let header = try? JSONDecoder().decode(KeyIDOnly.self, from: payload),
              let key = trustedKeys[header.keyId] else {
            throw VerificationError.unknownKey
        }
        guard key.isValidSignature(signature, for: Data("\(prefix).\(parts[1])".utf8)) else {
            throw VerificationError.invalidSignature
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let claims = try? decoder.decode(Claims.self, from: payload) else { throw VerificationError.malformed }
        guard claims.schemaVersion == 1 else { throw VerificationError.unsupportedSchema }
        guard claims.issuer == issuer else { throw VerificationError.wrongIssuer }
        guard claims.audience == audience else { throw VerificationError.wrongAudience }
        guard claims.devicePublicKeyHash == devicePublicKeyHash else { throw VerificationError.wrongDevice }
        guard claims.entitlements.contains(proEntitlement) else { throw VerificationError.missingEntitlement }
        guard claims.issuedAt.timeIntervalSince(now) <= clockSkew,
              claims.refreshAfter <= claims.expiresAt else { throw VerificationError.notYetValid }
        return LicenseCertificate(token: trimmed, claims: claims)
    }

    private struct KeyIDOnly: Decodable { let keyId: String }

    /// Trusted signing keys: `NotchFlowCertificateKeys` in Info.plist (keyId → base64 Ed25519 public key).
    /// Several keys may be listed to rotate without breaking older certificates.
    static func configuredKeys(bundle: Bundle = .main) -> [String: Curve25519.Signing.PublicKey] {
        let raw = bundle.object(forInfoDictionaryKey: "NotchFlowCertificateKeys") as? [String: String] ?? [:]
        return raw.compactMapValues { value in
            Data(base64Encoded: value).flatMap { try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }
        }
    }
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ value: Substring) -> Data? {
        guard !value.isEmpty, value.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { return nil }
        let text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard text.count % 4 != 1 else { return nil }
        return Data(base64Encoded: text + String(repeating: "=", count: (4 - text.count % 4) % 4))
    }
}
