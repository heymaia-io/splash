import Foundation
import Testing
@testable import KomgaAPI
@testable import KomgaRemote

@Suite("KomgaRemote units")
struct UnitTests {
    @Test func urlBuildingKeepsBasePathAndEncodesPlus() {
        let http = KomgaHTTPClient(baseURL: { URL(string: "https://example.com/komga/")! })
        let url = http.url("api/v1/books/B1", query: [URLQueryItem(name: "search", value: "a+b c")])
        #expect(url.absoluteString == "https://example.com/komga/api/v1/books/B1?search=a%2Bb%20c")
        let root = KomgaHTTPClient(baseURL: { URL(string: "http://host:25600")! })
        #expect(root.url("sse/v1/events").absoluteString == "http://host:25600/sse/v1/events")
    }

    @Test func requestCarriesApiKeyAndUserAgent() {
        let http = KomgaHTTPClient(baseURL: { URL(string: "http://h")! }, apiKey: { "secret" })
        let request = http.request(.get, "api/v2/users/me")
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == "secret")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == KomgaHTTPClient.defaultUserAgent)
    }

    @Test func sseParserHandlesCRLFMultilineAndComments() {
        var parser = ServerSentEventParser()
        let stream = ":heartbeat\r\nevent: BookChanged\r\ndata: {\"a\":1,\r\ndata: \"b\":2}\r\n\r\nevent:TaskQueueStatus\ndata:{}\n\n"
        let events = parser.consume(Array(stream.utf8))
        #expect(events == [
            ServerSentEvent(event: "BookChanged", data: "{\"a\":1,\n\"b\":2}", id: nil),
            ServerSentEvent(event: "TaskQueueStatus", data: "{}", id: nil),
        ])
    }

    @Test func cookieStoreIgnoresSessionCookieWithForeignPath() throws {
        let base = URL(string: "http://komga.local:25600/")!
        let store = KomgaCookieStore(serverURL: { base }, persistence: nil)
        let good = try #require(HTTPURLResponse(
            url: base, statusCode: 200, httpVersion: nil,
            headerFields: ["Set-Cookie": "KOMGA-SESSION=abc; Path=/; HttpOnly"]))
        store.capture(response: good, requestURL: base.appending(path: "api/v2/users/me"))
        let bad = try #require(HTTPURLResponse(
            url: base, statusCode: 200, httpVersion: nil,
            headerFields: ["Set-Cookie": "KOMGA-SESSION=zzz; Path=/sse/v1; HttpOnly"]))
        store.capture(response: bad, requestURL: base.appending(path: "sse/v1/events"))
        #expect(store.cookieHeader(for: base.appending(path: "api/v1/books")) == "KOMGA-SESSION=abc")
    }

    @Test func cookieStorePersistsRememberMe() async throws {
        let base = URL(string: "http://komga.local:25600/")!
        let persistence = MemoryPersistence()
        let store = KomgaCookieStore(serverURL: { base }, persistence: persistence)
        let response = try #require(HTTPURLResponse(
            url: base, statusCode: 200, httpVersion: nil,
            headerFields: ["Set-Cookie": "komga-remember-me=token; Path=/; Max-Age=31536000; HttpOnly"]))
        store.capture(response: response, requestURL: base)
        try await Task.sleep(for: .milliseconds(100))
        let saved = try #require(await persistence.value)

        let restored = KomgaCookieStore(serverURL: { base }, persistence: persistence)
        await restored.loadRememberMeCookie()
        #expect(saved.contains("komga-remember-me=token"))
        #expect(restored.hasRememberMe)
        #expect(restored.cookieHeader(for: base.appending(path: "api")) == "komga-remember-me=token")
    }

    @Test func cookiePathMatching() throws {
        let cookie = try #require(HTTPCookie(properties: [
            .name: "a", .value: "1", .domain: "h.local", .path: "/komga",
        ]))
        #expect(KomgaCookieStore.matches(cookie, url: URL(string: "http://h.local/komga/api")!))
        #expect(!KomgaCookieStore.matches(cookie, url: URL(string: "http://h.local/komgaX")!))
        #expect(!KomgaCookieStore.matches(cookie, url: URL(string: "http://other.local/komga")!))
    }
}

actor MemoryPersistence: KomgaCookiePersistence {
    var value: String?
    func loadCookie(serverURL: String) async throws -> String? { value }
    func saveCookie(_ setCookieHeader: String, serverURL: String) async throws { value = setCookieHeader }
    func deleteCookie(serverURL: String) async throws { value = nil }
}
