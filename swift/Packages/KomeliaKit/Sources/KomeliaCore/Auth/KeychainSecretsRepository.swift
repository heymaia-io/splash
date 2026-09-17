import Foundation
import Security

/// Thin seam over Security.framework so the repository logic is testable without touching a real keychain.
public protocol KeychainClient: Sendable {
    func read(_ query: [String: Any]) -> (OSStatus, Data?)
    func add(_ attributes: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

public struct SystemKeychainClient: KeychainClient {
    public init() {}

    public func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    public func add(_ attributes: [String: Any]) -> OSStatus { SecItemAdd(attributes as CFDictionary, nil) }

    public func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    public func delete(_ query: [String: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}

public enum KeychainError: Error, Equatable {
    case status(OSStatus)
}

/// iOS implementation of `SecretsRepository` (plan Phase 2, [NUEVO]).
/// Kotlin used SharedPreferences (Android) / Secret Service (desktop). Items are internet passwords keyed by
/// server host/port/path; `kSecAttrAccessibleAfterFirstUnlock` so background downloads after a reboot can
/// still authenticate (Phase 11).
public struct KeychainSecretsRepository: SecretsRepository {
    private enum Kind: String {
        case cookie = "komelia.remember-me-cookie"
        case apiKey = "komelia.api-key"
    }

    private let keychain: any KeychainClient

    public init(keychain: any KeychainClient = SystemKeychainClient()) {
        self.keychain = keychain
    }

    public func getCookie(url: String) async throws -> String? { try read(.cookie, url) }
    public func setCookie(url: String, cookie: String) async throws { try write(.cookie, url, cookie) }
    public func deleteCookie(url: String) async throws { try delete(.cookie, url) }
    public func getApiKey(url: String) async throws -> String? { try read(.apiKey, url) }
    public func setApiKey(url: String, apiKey: String) async throws { try write(.apiKey, url, apiKey) }
    public func deleteApiKey(url: String) async throws { try delete(.apiKey, url) }

    // MARK: - Private

    static func baseQuery(kind: String, url: String) -> [String: Any] {
        let components = URLComponents(string: url)
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: kind,
            kSecAttrServer as String: components?.host ?? url,
            kSecAttrPath as String: components?.path.isEmpty == false ? components!.path : "/",
        ]
        if let port = components?.port { query[kSecAttrPort as String] = port }
        if components?.scheme == "https" {
            query[kSecAttrProtocol as String] = kSecAttrProtocolHTTPS
        } else {
            query[kSecAttrProtocol as String] = kSecAttrProtocolHTTP
        }
        return query
    }

    private func read(_ kind: Kind, _ url: String) throws -> String? {
        var query = Self.baseQuery(kind: kind.rawValue, url: url)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, data) = keychain.read(query)
        switch status {
        case errSecSuccess: return data.map { String(decoding: $0, as: UTF8.self) }
        case errSecItemNotFound: return nil
        default: throw KeychainError.status(status)
        }
    }

    private func write(_ kind: Kind, _ url: String, _ value: String) throws {
        let query = Self.baseQuery(kind: kind.rawValue, url: url)
        let data = Data(value.utf8)
        let status = keychain.update(query, [kSecValueData as String: data])
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = keychain.add(attributes)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    private func delete(_ kind: Kind, _ url: String) throws {
        let status = keychain.delete(Self.baseQuery(kind: kind.rawValue, url: url))
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}

/// Volatile secrets (previews, tests).
public actor InMemorySecretsRepository: SecretsRepository {
    private var cookies: [String: String] = [:]
    private var apiKeys: [String: String] = [:]

    public init() {}

    public func getCookie(url: String) async throws -> String? { cookies[url] }
    public func setCookie(url: String, cookie: String) async throws { cookies[url] = cookie }
    public func deleteCookie(url: String) async throws { cookies[url] = nil }
    public func getApiKey(url: String) async throws -> String? { apiKeys[url] }
    public func setApiKey(url: String, apiKey: String) async throws { apiKeys[url] = apiKey }
    public func deleteApiKey(url: String) async throws { apiKeys[url] = nil }
}
