import Foundation
import Security
import Synchronization
import Testing
@testable import KomeliaCore

/// Fake keychain: dictionary keyed by the identity attributes (never touches the real keychain).
final class FakeKeychain: KeychainClient {
    let items = Mutex<[String: Data]>([:])

    private func key(_ query: [String: Any]) -> String {
        [kSecAttrAccount, kSecAttrServer, kSecAttrPath, kSecAttrPort]
            .map { "\(query[$0 as String] ?? "-")" }.joined(separator: "|")
    }

    func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        let data = items.withLock { $0[key(query)] }
        return data == nil ? (errSecItemNotFound, nil) : (errSecSuccess, data)
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        #expect(attributes[kSecAttrAccessible as String] as! CFString == kSecAttrAccessibleAfterFirstUnlock)
        items.withLock { $0[key(attributes)] = attributes[kSecValueData as String] as? Data }
        return errSecSuccess
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        items.withLock { items in
            guard items[key(query)] != nil else { return errSecItemNotFound }
            items[key(query)] = attributes[kSecValueData as String] as? Data
            return errSecSuccess
        }
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        items.withLock { $0.removeValue(forKey: key(query)) } == nil ? errSecItemNotFound : errSecSuccess
    }
}

@Suite struct AuthTests {
    @Test func keychainRepositoryIsKeyedByServerAndKind() async throws {
        let repo = KeychainSecretsRepository(keychain: FakeKeychain())
        try await repo.setCookie(url: "http://a.local:25600", cookie: "c1")
        try await repo.setApiKey(url: "http://a.local:25600", apiKey: "k1")
        try await repo.setCookie(url: "https://b.local/komga", cookie: "c2")
        try await repo.setCookie(url: "http://a.local:25600", cookie: "c1b")  // update path

        #expect(try await repo.getCookie(url: "http://a.local:25600") == "c1b")
        #expect(try await repo.getApiKey(url: "http://a.local:25600") == "k1")
        #expect(try await repo.getCookie(url: "https://b.local/komga") == "c2")
        #expect(try await repo.getCookie(url: "http://a.local:9999") == nil)

        try await repo.deleteCookie(url: "http://a.local:25600")
        try await repo.deleteCookie(url: "http://a.local:25600")  // idempotent
        #expect(try await repo.getCookie(url: "http://a.local:25600") == nil)
        #expect(try await repo.getApiKey(url: "http://a.local:25600") == "k1")
    }

    @Test(arguments: [
        ("localhost:25600", "http://localhost:25600"),
        ("https://komga.example/", "https://komga.example"),
        ("  http://10.0.0.2:8080/komga// ", "http://10.0.0.2:8080/komga"),
        ("", nil), ("ftp://x", nil), ("http://", nil),
    ] as [(String, String?)])
    func serverURLNormalization(input: String, expected: String?) {
        #expect(ServerURL.normalize(input) == expected)
    }

    @Test func apiKeyStoreCachesValue() async throws {
        let store = ApiKeyStore(secrets: InMemorySecretsRepository())
        #expect(store.apiKey == nil)
        try await store.setApiKey("k", serverURL: "http://h")
        #expect(store.apiKey == "k")
        let reloaded = ApiKeyStore(secrets: InMemorySecretsRepository())
        await reloaded.loadStoredApiKey(serverURL: "http://h")
        #expect(reloaded.apiKey == nil)
        try await store.deleteApiKey(serverURL: "http://h")
        #expect(store.apiKey == nil)
    }
}
