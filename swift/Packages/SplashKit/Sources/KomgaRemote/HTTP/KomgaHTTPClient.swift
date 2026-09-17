import Foundation
import KomgaAPI

public enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

/// Shared HTTP plumbing for every `Remote*Api` — the Swift counterpart of the ktor client configured in
/// `KomgaClientFactory.configureKtor` (base URL + trailing slash, `X-API-Key`, cookies, user agent,
/// `expectSuccess = true`, JSON with ignored unknown keys).
public final class KomgaHTTPClient: Sendable {
    public static let defaultUserAgent = "Splash (https://komga.org client)"

    private let baseURL: @Sendable () -> URL
    private let apiKey: @Sendable () -> String?
    private let session: URLSession
    private let cookieStore: KomgaCookieStore?
    private let userAgent: String
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    public init(
        baseURL: @escaping @Sendable () -> URL,
        apiKey: @escaping @Sendable () -> String? = { nil },
        cookieStore: KomgaCookieStore? = nil,
        session: URLSession = KomgaHTTPClient.makeSession(),
        userAgent: String = KomgaHTTPClient.defaultUserAgent
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.cookieStore = cookieStore
        self.session = session
        self.userAgent = userAgent
        self.decoder = KomgaJSON.makeDecoder()
        self.encoder = KomgaJSON.makeEncoder()
    }

    /// Cookies are handled by `KomgaCookieStore`, not Foundation, so the SSE path workaround can be applied
    /// (plan Phase 2 risk: HTTPCookieStorage's automatic matching).
    public static func makeSession(configuration: URLSessionConfiguration = .default) -> URLSession {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

    public var currentBaseURL: URL { baseURL() }

    // MARK: Request building

    /// `defaultRequest { url { takeFrom(baseUrl); pathSegments = segments.filter(notBlank) + "" } }`
    public func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        let base = baseURL()
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        let baseSegments = components.percentEncodedPath.split(separator: "/").map(String.init)
        let pathSegments = path.split(separator: "/", omittingEmptySubsequences: true).map {
            String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }
        components.percentEncodedPath = "/" + (baseSegments + pathSegments).joined(separator: "/")
        components.queryItems = query.isEmpty ? nil : query
        // URLComponents leaves '+' unescaped in queries; servers read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url ?? base
    }

    public func request(
        _ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], headers: [String: String] = [:],
        body: Data? = nil, contentType: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url(path, query: query))
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let key = apiKey() { request.setValue(key, forHTTPHeaderField: "X-API-Key") }
        if let cookie = cookieStore?.cookieHeader(for: request.url!) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return request
    }

    /// Auth headers (`X-API-Key` / `Cookie`) for requests made by other HTTP stacks (e.g. Readium's EPUB
    /// resource loader), so they authenticate exactly like this client.
    public func authorizationHeaders(for url: URL) -> [String: String] {
        var headers: [String: String] = ["User-Agent": userAgent]
        if let key = apiKey() { headers["X-API-Key"] = key }
        if let cookie = cookieStore?.cookieHeader(for: url) { headers["Cookie"] = cookie }
        return headers
    }

    public func jsonRequest<Body: Encodable>(
        _ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], body: Body
    ) throws -> URLRequest {
        request(method, path, query: query, body: try encoder.encode(body), contentType: "application/json")
    }

    // MARK: Execution

    /// Executes and validates the status code; captures `Set-Cookie`.
    @discardableResult
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KomgaAPIError.invalidResponse }
        cookieStore?.capture(response: http, requestURL: request.url!)
        guard (200..<300).contains(http.statusCode) else {
            throw KomgaAPIError.httpStatus(code: http.statusCode, body: data)
        }
        return (data, http)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw KomgaAPIError.decoding(String(describing: error))
        }
    }

    public func fetch<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await send(request)
        return try decode(type, from: data)
    }

    /// Binary endpoints (`accept(ContentType.Any)`).
    public func fetchBytes(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        try await send(request(.get, path, query: query, headers: ["Accept": "*/*"])).0
    }

    /// `catch (ClientRequestException) { if 404 null else throw }`
    public func nilIfNotFound<T>(_ operation: () async throws -> T) async throws -> T? {
        do {
            return try await operation()
        } catch let error as KomgaAPIError where error.isNotFound {
            return nil
        }
    }

    /// Streams a long-lived response (SSE). Caller owns cancellation.
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw KomgaAPIError.invalidResponse }
        cookieStore?.capture(response: http, requestURL: request.url!)
        guard (200..<300).contains(http.statusCode) else {
            throw KomgaAPIError.httpStatus(code: http.statusCode, body: Data())
        }
        return (bytes, http)
    }
}

// MARK: - Query helpers

extension Array where Element == URLQueryItem {
    mutating func append(_ name: String, _ value: String?) {
        guard let value else { return }
        append(URLQueryItem(name: name, value: value))
    }

    mutating func append(_ name: String, _ value: Bool?) {
        append(name, value.map { String($0) })
    }

    /// Comma-joined list, skipped when nil/empty. (Kotlin mixes `joinToString()` = ", " and ","; Spring
    /// trims list elements, so "," is used everywhere.)
    mutating func appendList<S: Sequence>(_ name: String, _ values: S?, transform: (S.Element) -> String) {
        guard let values else { return }
        let joined = values.map(transform)
        guard !joined.isEmpty else { return }
        append(URLQueryItem(name: name, value: joined.joined(separator: ",")))
    }

    mutating func appendPage(_ request: KomgaPageRequest?) {
        guard let request else { return }
        append(contentsOf: request.queryItems)
    }
}
