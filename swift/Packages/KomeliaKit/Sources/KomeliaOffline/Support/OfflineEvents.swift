import Foundation
import KomgaAPI

/// Factories for the `KomgaEvent`s the offline actions emit. A few payload types have no public memberwise init
/// in KomgaAPI (they are only ever decoded from SSE), so those are built through the public SSE decoder — the
/// same path a server event takes. See the integration notes for the suggested KomgaAPI change.
enum OfflineEvents {
    static func bookAdded(_ book: OfflineBook) -> KomgaEvent {
        .bookAdded(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId))
    }

    static func bookChanged(_ book: OfflineBook) -> KomgaEvent {
        .bookChanged(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId))
    }

    static func bookDeleted(_ book: OfflineBook) -> KomgaEvent {
        .bookDeleted(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId))
    }

    static func seriesChanged(_ series: OfflineSeries) -> KomgaEvent {
        .seriesChanged(.init(seriesId: series.id, libraryId: series.libraryId))
    }

    static func seriesDeleted(_ series: OfflineSeries) -> KomgaEvent {
        .seriesDeleted(.init(seriesId: series.id, libraryId: series.libraryId))
    }

    static func libraryDeleted(_ id: KomgaLibraryId) -> KomgaEvent { .libraryDeleted(.init(libraryId: id)) }

    static func readProgressChanged(_ bookId: KomgaBookId, _ userId: KomgaUserId) -> KomgaEvent {
        .readProgressChanged(.init(bookId: bookId, userId: userId))
    }

    static func readProgressDeleted(_ bookId: KomgaBookId, _ userId: KomgaUserId) -> KomgaEvent {
        .readProgressDeleted(.init(bookId: bookId, userId: userId))
    }

    static func readProgressSeriesChanged(_ seriesId: KomgaSeriesId, _ userId: KomgaUserId) -> KomgaEvent {
        decoded("ReadProgressSeriesChanged", ["seriesId": seriesId.rawValue, "userId": userId.rawValue])
    }

    static func readProgressSeriesDeleted(_ seriesId: KomgaSeriesId, _ userId: KomgaUserId) -> KomgaEvent {
        decoded("ReadProgressSeriesDeleted", ["seriesId": seriesId.rawValue, "userId": userId.rawValue])
    }

    static func sessionExpired(_ userId: KomgaUserId) -> KomgaEvent {
        decoded("SessionExpired", ["userId": userId.rawValue])
    }

    private static func decoded(_ name: String, _ payload: [String: String]) -> KomgaEvent {
        let data = (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) }
        return KomgaEvent.decode(event: name, data: data)
    }
}

/// Builds wire values whose KomgaAPI types only have an internal memberwise init, via their `Codable` form.
enum WireValues {
    static func decode<T: Decodable>(_ type: T.Type, from object: [String: any Sendable]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try KomgaJSON.makeDecoder().decode(type, from: data)
    }

    static func decodeEncodable<T: Decodable>(_ type: T.Type, from value: some Encodable) throws -> T {
        try KomgaJSON.makeDecoder().decode(type, from: KomgaJSON.makeEncoder().encode(value))
    }
}
