import Foundation
import Synchronization

/// Persists the remember-me cookie per server URL (implemented by the Keychain-backed
/// `SecretsRepository` in KomeliaCore — `getCookie/setCookie/deleteCookie`).
public protocol KomgaCookiePersistence: Sendable {
    func loadCookie(serverURL: String) async throws -> String?
    func saveCookie(_ setCookieHeader: String, serverURL: String) async throws
    func deleteCookie(serverURL: String) async throws
}

/// Port of `RememberMePersistingCookieStore` (komelia-domain/core/http).
/// In-memory cookie jar + persistence of `komga-remember-me` for the configured server.
public final class KomgaCookieStore: Sendable {
    public static let rememberMeCookie = "komga-remember-me"
    public static let sessionCookie = "KOMGA-SESSION"

    private let serverURL: @Sendable () -> URL
    private let persistence: (any KomgaCookiePersistence)?
    private let cookies = Mutex<[HTTPCookie]>([])

    public init(serverURL: @escaping @Sendable () -> URL, persistence: (any KomgaCookiePersistence)?) {
        self.serverURL = serverURL
        self.persistence = persistence
    }

    /// `loadRememberMeCookie()`
    public func loadRememberMeCookie() async {
        let server = serverURL()
        guard let header = try? await persistence?.loadCookie(serverURL: server.absoluteString) else { return }
        let parsed = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": header], for: server)
        cookies.withLock { jar in
            for cookie in parsed { Self.replace(cookie, in: &jar) }
        }
    }

    /// Drops every cookie and the persisted remember-me (logout / server change).
    public func clear() async {
        cookies.withLock { $0.removeAll() }
        try? await persistence?.deleteCookie(serverURL: serverURL().absoluteString)
    }

    public var hasRememberMe: Bool {
        cookies.withLock { $0.contains { $0.name == Self.rememberMeCookie && !$0.value.isEmpty } }
    }

    func cookieHeader(for url: URL) -> String? {
        let now = Date()
        let matching = cookies.withLock { jar -> [HTTPCookie] in
            jar.removeAll { ($0.expiresDate.map { $0 < now }) ?? false }
            return jar.filter { Self.matches($0, url: url) }
        }
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    func capture(response: HTTPURLResponse, requestURL: URL) {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        let received = HTTPCookie.cookies(withResponseHeaderFields: headers, for: requestURL)
        guard !received.isEmpty else { return }
        let server = serverURL()
        let basePath = server.path.isEmpty ? "/" : server.path

        for cookie in received {
            // Verbatim workaround from the Kotlin store: a session/remember-me cookie echoed with a different
            // path (SSE reconnection re-sends request cookies) would shadow the real one and break every
            // other request — ignore it.
            if [Self.rememberMeCookie, Self.sessionCookie].contains(cookie.name), cookie.path != basePath {
                continue
            }
            cookies.withLock { jar in
                if cookie.expiresDate.map({ $0 < Date() }) ?? false {
                    jar.removeAll { Self.sameIdentity($0, cookie) }
                } else {
                    Self.replace(cookie, in: &jar)
                }
            }
            if cookie.name == Self.rememberMeCookie, !cookie.value.isEmpty, server.host == requestURL.host,
               let persistence
            {
                let header = Self.renderSetCookie(cookie)
                let key = server.absoluteString
                Task { try? await persistence.saveCookie(header, serverURL: key) }
            }
        }
    }

    // MARK: - Helpers

    private static func sameIdentity(_ a: HTTPCookie, _ b: HTTPCookie) -> Bool {
        a.name == b.name && a.domain == b.domain && a.path == b.path
    }

    private static func replace(_ cookie: HTTPCookie, in jar: inout [HTTPCookie]) {
        jar.removeAll { sameIdentity($0, cookie) }
        jar.append(cookie)
    }

    static func matches(_ cookie: HTTPCookie, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased()
        let domainMatches: Bool
        if domain.hasPrefix(".") {
            domainMatches = host == String(domain.dropFirst()) || host.hasSuffix(domain)
        } else {
            domainMatches = host == domain
        }
        guard domainMatches else { return false }
        if cookie.isSecure, url.scheme?.lowercased() != "https" { return false }
        let path = url.path.isEmpty ? "/" : url.path
        let cookiePath = cookie.path.isEmpty ? "/" : cookie.path
        guard path.hasPrefix(cookiePath) else { return false }
        return cookiePath.hasSuffix("/") || path.count == cookiePath.count
            || path.dropFirst(cookiePath.count).hasPrefix("/")
    }

    /// `renderSetCookieHeader(cookie)` — round-trips through `HTTPCookie.cookies(withResponseHeaderFields:)`.
    static func renderSetCookie(_ cookie: HTTPCookie) -> String {
        var parts = ["\(cookie.name)=\(cookie.value)", "Path=\(cookie.path)"]
        if let expires = cookie.expiresDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "GMT")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            parts.append("Expires=\(formatter.string(from: expires))")
        }
        if cookie.isSecure { parts.append("Secure") }
        if cookie.isHTTPOnly { parts.append("HttpOnly") }
        return parts.joined(separator: "; ")
    }
}
