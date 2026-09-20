import Foundation
import Testing
@testable import KomgaAPI

/// These strings reach the user directly in screen error views. Without `LocalizedError`, Foundation renders
/// a plain `Error` enum as "KomgaAPI.KomgaAPIError error 0" — naming the *case index*, which is meaningless.
@Suite struct ErrorMessageTests {
    private func body(_ message: String, status: Int) -> Data {
        Data("""
            {"error":"Bad Request","message":"\(message)","path":"/api/v1/series","status":\(status),
             "timestamp":"2026-01-01T00:00:00Z"}
            """.utf8)
    }

    @Test func neverRendersTheRawEnumDescription() {
        let errors: [KomgaAPIError] = [
            .httpStatus(code: 500, body: Data()), .invalidResponse,
            .decoding("bad"), .unsupported("offline"),
        ]
        for error in errors {
            let text = error.localizedDescription
            #expect(!text.contains("KomgaAPIError"))
            #expect(!text.contains("error 0"))
            #expect(!text.isEmpty)
        }
    }

    /// The server's own message is the only thing that can explain a particular 4xx, so it wins.
    @Test func prefersTheServersOwnMessage() {
        let error = KomgaAPIError.httpStatus(code: 400, body: body("Series name already exists", status: 400))
        #expect(error.localizedDescription == "Series name already exists")
    }

    @Test func fallsBackToTheStatusWhenTheBodyIsUnhelpful() {
        #expect(KomgaAPIError.httpStatus(code: 401, body: Data()).localizedDescription
            .contains("sign in"))
        #expect(KomgaAPIError.httpStatus(code: 404, body: Data()).localizedDescription
            .contains("no longer on the server"))
        #expect(KomgaAPIError.httpStatus(code: 503, body: Data()).localizedDescription
            .contains("503"))
    }

    /// An empty `message` must not produce a blank alert.
    @Test func ignoresAnEmptyServerMessage() {
        let error = KomgaAPIError.httpStatus(code: 500, body: body("", status: 500))
        #expect(error.localizedDescription.contains("500"))
    }

    @Test func detailIsCarriedIntoDecodingAndUnsupported() {
        #expect(KomgaAPIError.decoding("missing field").localizedDescription.contains("missing field"))
        #expect(KomgaAPIError.unsupported("admin while offline").localizedDescription
            .contains("admin while offline"))
    }
}
