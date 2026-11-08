import Foundation
import CryptoKit

/// Offline verification of a signed license. The signing key never belongs in the app.
struct LicenseVerifier {
    enum Kind: String, Codable {
        case pro
        case developer
    }

    struct Claims: Codable, Equatable {
        let version: Int
        let product: String
        let id: String
        let kind: Kind
        /// Unix seconds. Absent for a perpetual license.
        let expiresAt: Int64?
    }

    enum VerificationError: Error, Equatable {
        case invalidKey
        case malformed
        case invalidSignature
        case invalidClaims
        case expired
    }

    private let publicKey: Curve25519.Signing.PublicKey

    init(publicKeyData: Data) throws {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            throw VerificationError.invalidKey
        }
        self.publicKey = key
    }

    func verify(_ token: String, now: Date = Date()) throws -> Claims {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count <= 4096 else { throw VerificationError.malformed }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "NF1",
              let payload = Self.decodeBase64URL(parts[1]),
              let signature = Self.decodeBase64URL(parts[2]), signature.count == 64 else {
            throw VerificationError.malformed
        }
        let message = Data("NF1.\(parts[1])".utf8)
        guard publicKey.isValidSignature(signature, for: message) else {
            throw VerificationError.invalidSignature
        }
        guard let claims = try? JSONDecoder().decode(Claims.self, from: payload),
              claims.version == 1, claims.product == "NotchFlow",
              !claims.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              claims.id.utf8.count <= 128 else {
            throw VerificationError.invalidClaims
        }
        if let expiry = claims.expiresAt, now.timeIntervalSince1970 >= Double(expiry) {
            throw VerificationError.expired
        }
        return claims
    }

    private static func decodeBase64URL(_ value: Substring) -> Data? {
        guard !value.isEmpty, value.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { return nil }
        let text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard text.count % 4 != 1 else { return nil }
        return Data(base64Encoded: text + String(repeating: "=", count: (4 - text.count % 4) % 4))
    }
}
