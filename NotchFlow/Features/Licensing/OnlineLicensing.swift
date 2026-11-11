import Foundation
import Security

// MARK: - Provider

/// What a license server says about one key on one Mac.
struct ProviderLicense: Equatable {
    enum Status: String, Codable { case active, inactive, expired, disabled }
    let status: Status
    let instanceID: String?
    let activationLimit: Int?
    let activationUsage: Int?
}

enum LicenseProviderError: Error, Equatable {
    case invalidKey
    case limitReached
    case wrongProduct
    case network
    case server(String)
}

/// Online activation backend. Lemon Squeezy today; a custom server can implement the same calls.
protocol LicenseProvider: Sendable {
    func activate(key: String, instanceName: String) async throws -> ProviderLicense
    func validate(key: String, instanceID: String) async throws -> ProviderLicense
    func deactivate(key: String, instanceID: String) async throws
}

/// Lemon Squeezy License API (https://docs.lemonsqueezy.com/api/license-api).
/// These endpoints need no API secret, so nothing sensitive ships in the app.
struct LemonSqueezyLicenseProvider: LicenseProvider {
    var storeID: Int?
    var productID: Int?
    var session: URLSession = .shared
    var baseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses")!

    /// Reads `NotchFlowLemonStoreID` / `NotchFlowLemonProductID` from Info.plist.
    static var configured: LemonSqueezyLicenseProvider {
        func int(_ key: String) -> Int? {
            (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        return LemonSqueezyLicenseProvider(storeID: int("NotchFlowLemonStoreID"), productID: int("NotchFlowLemonProductID"))
    }

    func activate(key: String, instanceName: String) async throws -> ProviderLicense {
        let response = try await post("activate", ["license_key": key, "instance_name": instanceName])
        if response.activated != true {
            throw Self.error(for: response)
        }
        return try license(from: response)
    }

    func validate(key: String, instanceID: String) async throws -> ProviderLicense {
        let response = try await post("validate", ["license_key": key, "instance_id": instanceID])
        if response.valid != true, response.license_key == nil {
            throw Self.error(for: response)
        }
        return try license(from: response)
    }

    func deactivate(key: String, instanceID: String) async throws {
        let response = try await post("deactivate", ["license_key": key, "instance_id": instanceID])
        if response.deactivated != true {
            throw Self.error(for: response)
        }
    }

    // MARK: Wire format

    struct Response: Decodable {
        struct Key: Decodable {
            let status: String
            let activation_limit: Int?
            let activation_usage: Int?
        }
        struct Instance: Decodable { let id: String }
        struct Meta: Decodable {
            let store_id: Int?
            let product_id: Int?
        }
        let activated: Bool?
        let valid: Bool?
        let deactivated: Bool?
        let error: String?
        let license_key: Key?
        let instance: Instance?
        let meta: Meta?
    }

    private func license(from response: Response) throws -> ProviderLicense {
        if let storeID, response.meta?.store_id != storeID { throw LicenseProviderError.wrongProduct }
        if let productID, response.meta?.product_id != productID { throw LicenseProviderError.wrongProduct }
        guard let key = response.license_key else { throw LicenseProviderError.invalidKey }
        return ProviderLicense(status: ProviderLicense.Status(rawValue: key.status) ?? .disabled,
                               instanceID: response.instance?.id,
                               activationLimit: key.activation_limit,
                               activationUsage: key.activation_usage)
    }

    static func error(for response: Response) -> LicenseProviderError {
        let message = response.error ?? ""
        let lower = message.lowercased()
        if lower.contains("activation limit") { return .limitReached }
        if lower.contains("not found") || lower.contains("invalid") || lower.contains("license_key") { return .invalidKey }
        return .server(message)
    }

    private func post(_ path: String, _ fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw LicenseProviderError.network
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw LicenseProviderError.server("Unreadable response")
        }
        return response
    }
}

// MARK: - Secure storage

/// Small key/value store for license state. Keychain in the app, memory in tests.
protocol LicenseSecureStorage: AnyObject {
    func data(for account: String) -> Data?
    func set(_ data: Data?, for account: String)
}

final class KeychainLicenseStorage: LicenseSecureStorage {
    private let service: String

    init(service: String = "app.notchflow.license") {
        self.service = service
    }

    func data(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func set(_ data: Data?, for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let data else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}

final class InMemoryLicenseStorage: LicenseSecureStorage {
    private var values: [String: Data] = [:]
    func data(for account: String) -> Data? { values[account] }
    func set(_ data: Data?, for account: String) { values[account] = data }
}
