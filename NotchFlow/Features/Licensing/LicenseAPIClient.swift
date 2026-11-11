import Foundation
import CryptoKit

enum LicenseBackendError: Error, Equatable {
    case invalidKey
    case limitReached
    case wrongProduct
    /// The license was refunded, disabled or the activation was removed by support.
    case revoked
    case rateLimited
    /// Timeout, offline, DNS, TLS: never treated as revocation.
    case network
    /// 5xx or an unreadable response: never treated as revocation.
    case server
}

/// NotchFlow license backend (see docs/licensing-api.md).
protocol LicenseBackend: Sendable {
    func activate(licenseKey: String, devicePublicKey: String, deviceName: String) async throws -> String
    func refresh(activationId: String, request: SignedRequest) async throws -> String
    func deactivate(activationId: String, request: SignedRequest) async throws
}

/// Proof that the caller holds the device private key, with replay protection.
/// Signature covers: `METHOD \n PATH \n TIMESTAMP \n NONCE \n hex(SHA256(body))`.
struct SignedRequest: Equatable, Sendable {
    let body: Data
    let timestamp: Int64
    let nonce: String
    let signature: String
    let devicePublicKey: String

    static func make(method: String, path: String, body: Data, identity: DeviceIdentity, now: Date) throws -> SignedRequest {
        let timestamp = Int64(now.timeIntervalSince1970)
        let nonce = UUID().uuidString.lowercased()
        let message = Self.message(method: method, path: path, timestamp: timestamp, nonce: nonce, body: body)
        return SignedRequest(body: body, timestamp: timestamp, nonce: nonce,
                             signature: Base64URL.encode(try identity.sign(message)),
                             devicePublicKey: identity.publicKeyBase64)
    }

    static func message(method: String, path: String, timestamp: Int64, nonce: String, body: Data) -> Data {
        Data("\(method)\n\(path)\n\(timestamp)\n\(nonce)\n\(DeviceIdentity.sha256Hex(body))".utf8)
    }
}

struct HTTPLicenseBackend: LicenseBackend {
    let baseURL: URL
    var session: URLSession = .shared

    /// `NotchFlowLicenseAPIURL` in Info.plist; must be https. Nil means the backend isn't configured yet.
    static var configured: HTTPLicenseBackend? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "NotchFlowLicenseAPIURL") as? String,
              raw.hasPrefix("https://"), let url = URL(string: raw) else { return nil }
        return HTTPLicenseBackend(baseURL: url)
    }

    static let activatePath = "/v1/licenses/activate"
    static let refreshPath = "/v1/licenses/refresh"
    static let deactivatePath = "/v1/licenses/deactivate"

    func activate(licenseKey: String, devicePublicKey: String, deviceName: String) async throws -> String {
        let body = try JSONEncoder().encode(["licenseKey": licenseKey, "devicePublicKey": devicePublicKey, "deviceName": deviceName])
        return try await certificate(from: send(Self.activatePath, body: body, signed: nil))
    }

    func refresh(activationId: String, request: SignedRequest) async throws -> String {
        try await certificate(from: send(Self.refreshPath, body: request.body, signed: request))
    }

    func deactivate(activationId: String, request: SignedRequest) async throws {
        _ = try await send(Self.deactivatePath, body: request.body, signed: request)
    }

    /// Request body for refresh/deactivate.
    static func activationBody(_ activationId: String) throws -> Data {
        try JSONEncoder().encode(["activationId": activationId])
    }

    private struct CertificateResponse: Decodable { let certificate: String }
    private struct ErrorResponse: Decodable { let error: String }

    private func certificate(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(CertificateResponse.self, from: data) else {
            throw LicenseBackendError.server
        }
        return response.certificate
    }

    private func send(_ path: String, body: Data, signed: SignedRequest?) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let signed {
            request.setValue(String(signed.timestamp), forHTTPHeaderField: "X-NF-Timestamp")
            request.setValue(signed.nonce, forHTTPHeaderField: "X-NF-Nonce")
            request.setValue(signed.signature, forHTTPHeaderField: "X-NF-Signature")
            request.setValue(signed.devicePublicKey, forHTTPHeaderField: "X-NF-Device-Key")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseBackendError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status) { return data }
        throw Self.error(status: status, data: data)
    }

    static func error(status: Int, data: Data) -> LicenseBackendError {
        let code = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
        switch (status, code) {
        case (_, "invalid_key"): return .invalidKey
        case (_, "limit_reached"): return .limitReached
        case (_, "wrong_product"): return .wrongProduct
        case (_, "revoked"), (_, "activation_not_found"): return .revoked
        case (429, _): return .rateLimited
        default: return .server
        }
    }
}
