import Foundation
import Synchronization

/// Port of `snd.komelia.http.ApiKeyStore`: caches the API key for the current server so the HTTP client can
/// read it synchronously on every request.
public final class ApiKeyStore: Sendable {
    private let secrets: any SecretsRepository
    private let cached = Mutex<String?>(nil)

    public init(secrets: any SecretsRepository) {
        self.secrets = secrets
    }

    public var apiKey: String? { cached.withLock { $0 } }

    public func loadStoredApiKey(serverURL: String) async {
        let key = try? await secrets.getApiKey(url: serverURL)
        cached.withLock { $0 = key }
    }

    public func setApiKey(_ apiKey: String, serverURL: String) async throws {
        try await secrets.setApiKey(url: serverURL, apiKey: apiKey)
        cached.withLock { $0 = apiKey }
    }

    public func deleteApiKey(serverURL: String) async throws {
        try await secrets.deleteApiKey(url: serverURL)
        cached.withLock { $0 = nil }
    }
}

/// Normalizes user-typed server addresses ("localhost:25600" -> "http://localhost:25600"),
/// like `OutlinedHttpTextField` does in the Kotlin login form. Trailing slashes are dropped so the
/// value is a stable key for secrets.
public enum ServerURL {
    public static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host != nil
        else { return nil }
        return text
    }
}
