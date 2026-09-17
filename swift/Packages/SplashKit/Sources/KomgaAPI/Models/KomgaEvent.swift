import Foundation

/// Server-sent events — port of snd.komga.client.sse.KomgaEvent + `Json.toKomgaEvent`.
public enum KomgaEvent: Hashable, Sendable {
    case libraryAdded(LibraryPayload)
    case libraryChanged(LibraryPayload)
    case libraryDeleted(LibraryPayload)

    case seriesAdded(SeriesPayload)
    case seriesChanged(SeriesPayload)
    case seriesDeleted(SeriesPayload)

    case bookAdded(BookPayload)
    case bookChanged(BookPayload)
    case bookDeleted(BookPayload)
    case bookImported(BookImportedPayload)

    case readListAdded(ReadListPayload)
    case readListChanged(ReadListPayload)
    case readListDeleted(ReadListPayload)

    case collectionAdded(CollectionPayload)
    case collectionChanged(CollectionPayload)
    case collectionDeleted(CollectionPayload)

    case readProgressChanged(ReadProgressPayload)
    case readProgressDeleted(ReadProgressPayload)
    case readProgressSeriesChanged(ReadProgressSeriesPayload)
    case readProgressSeriesDeleted(ReadProgressSeriesPayload)

    case thumbnailBookAdded(ThumbnailBookPayload)
    case thumbnailBookDeleted(ThumbnailBookPayload)
    case thumbnailSeriesAdded(ThumbnailSeriesPayload)
    case thumbnailSeriesDeleted(ThumbnailSeriesPayload)
    case thumbnailSeriesCollectionAdded(ThumbnailCollectionPayload)
    case thumbnailSeriesCollectionDeleted(ThumbnailCollectionPayload)
    case thumbnailReadListAdded(ThumbnailReadListPayload)
    case thumbnailReadListDeleted(ThumbnailReadListPayload)

    case sessionExpired(SessionExpiredPayload)
    case taskQueueStatus(TaskQueueStatusPayload)
    case unknown(event: String?, data: String?)

    public struct LibraryPayload: Codable, Hashable, Sendable {
        public var libraryId: KomgaLibraryId
        public init(libraryId: KomgaLibraryId) { self.libraryId = libraryId }
    }

    public struct SeriesPayload: Codable, Hashable, Sendable {
        public var seriesId: KomgaSeriesId
        public var libraryId: KomgaLibraryId
        public init(seriesId: KomgaSeriesId, libraryId: KomgaLibraryId) {
            self.seriesId = seriesId
            self.libraryId = libraryId
        }
    }

    public struct BookPayload: Codable, Hashable, Sendable {
        public var bookId: KomgaBookId
        public var seriesId: KomgaSeriesId
        public var libraryId: KomgaLibraryId
        public init(bookId: KomgaBookId, seriesId: KomgaSeriesId, libraryId: KomgaLibraryId) {
            self.bookId = bookId
            self.seriesId = seriesId
            self.libraryId = libraryId
        }
    }

    public struct BookImportedPayload: Codable, Hashable, Sendable {
        public var bookId: KomgaBookId?
        public var sourceFile: String
        public var success: Bool
        public var message: String?
    }

    public struct ReadListPayload: Codable, Hashable, Sendable {
        public var readListId: KomgaReadListId
        public var bookIds: [KomgaBookId]
    }

    public struct CollectionPayload: Codable, Hashable, Sendable {
        public var collectionId: KomgaCollectionId
        public var seriesIds: [KomgaSeriesId]
    }

    public struct ReadProgressPayload: Codable, Hashable, Sendable {
        public var bookId: KomgaBookId
        public var userId: KomgaUserId
        public init(bookId: KomgaBookId, userId: KomgaUserId) {
            self.bookId = bookId
            self.userId = userId
        }
    }

    public struct ReadProgressSeriesPayload: Codable, Hashable, Sendable {
        public var seriesId: KomgaSeriesId
        public var userId: KomgaUserId
    }

    public struct ThumbnailBookPayload: Codable, Hashable, Sendable {
        public var bookId: KomgaBookId
        public var seriesId: KomgaSeriesId
        public var selected: Bool
    }

    public struct ThumbnailSeriesPayload: Codable, Hashable, Sendable {
        public var seriesId: KomgaSeriesId
        public var selected: Bool
    }

    public struct ThumbnailCollectionPayload: Codable, Hashable, Sendable {
        public var collectionId: KomgaCollectionId
        public var selected: Bool
    }

    public struct ThumbnailReadListPayload: Codable, Hashable, Sendable {
        public var readListId: KomgaReadListId
        public var selected: Bool
    }

    public struct SessionExpiredPayload: Codable, Hashable, Sendable {
        public var userId: KomgaUserId
    }

    public struct TaskQueueStatusPayload: Codable, Hashable, Sendable {
        public var count: Int
        public var countByType: [String: Int]
    }
}

extension KomgaEvent {
    /// Lookup table instead of a 30-branch `when` (open/closed: new events = one new entry).
    private static let decoders: [String: @Sendable (JSONDecoder, Data) throws -> KomgaEvent] = [
        "TaskQueueStatus": { .taskQueueStatus(try $0.decode(TaskQueueStatusPayload.self, from: $1)) },
        "LibraryAdded": { .libraryAdded(try $0.decode(LibraryPayload.self, from: $1)) },
        "LibraryChanged": { .libraryChanged(try $0.decode(LibraryPayload.self, from: $1)) },
        "LibraryDeleted": { .libraryDeleted(try $0.decode(LibraryPayload.self, from: $1)) },
        "SeriesAdded": { .seriesAdded(try $0.decode(SeriesPayload.self, from: $1)) },
        "SeriesChanged": { .seriesChanged(try $0.decode(SeriesPayload.self, from: $1)) },
        "SeriesDeleted": { .seriesDeleted(try $0.decode(SeriesPayload.self, from: $1)) },
        "BookAdded": { .bookAdded(try $0.decode(BookPayload.self, from: $1)) },
        "BookChanged": { .bookChanged(try $0.decode(BookPayload.self, from: $1)) },
        "BookDeleted": { .bookDeleted(try $0.decode(BookPayload.self, from: $1)) },
        "BookImported": { .bookImported(try $0.decode(BookImportedPayload.self, from: $1)) },
        "ReadListAdded": { .readListAdded(try $0.decode(ReadListPayload.self, from: $1)) },
        "ReadListChanged": { .readListChanged(try $0.decode(ReadListPayload.self, from: $1)) },
        "ReadListDeleted": { .readListDeleted(try $0.decode(ReadListPayload.self, from: $1)) },
        "CollectionAdded": { .collectionAdded(try $0.decode(CollectionPayload.self, from: $1)) },
        "CollectionChanged": { .collectionChanged(try $0.decode(CollectionPayload.self, from: $1)) },
        "CollectionDeleted": { .collectionDeleted(try $0.decode(CollectionPayload.self, from: $1)) },
        "ReadProgressChanged": { .readProgressChanged(try $0.decode(ReadProgressPayload.self, from: $1)) },
        "ReadProgressDeleted": { .readProgressDeleted(try $0.decode(ReadProgressPayload.self, from: $1)) },
        "ReadProgressSeriesChanged": {
            .readProgressSeriesChanged(try $0.decode(ReadProgressSeriesPayload.self, from: $1))
        },
        "ReadProgressSeriesDeleted": {
            .readProgressSeriesDeleted(try $0.decode(ReadProgressSeriesPayload.self, from: $1))
        },
        "ThumbnailBookAdded": { .thumbnailBookAdded(try $0.decode(ThumbnailBookPayload.self, from: $1)) },
        "ThumbnailBookDeleted": { .thumbnailBookDeleted(try $0.decode(ThumbnailBookPayload.self, from: $1)) },
        "ThumbnailSeriesAdded": { .thumbnailSeriesAdded(try $0.decode(ThumbnailSeriesPayload.self, from: $1)) },
        "ThumbnailSeriesDeleted": { .thumbnailSeriesDeleted(try $0.decode(ThumbnailSeriesPayload.self, from: $1)) },
        "ThumbnailSeriesCollectionAdded": {
            .thumbnailSeriesCollectionAdded(try $0.decode(ThumbnailCollectionPayload.self, from: $1))
        },
        "ThumbnailSeriesCollectionDeleted": {
            .thumbnailSeriesCollectionDeleted(try $0.decode(ThumbnailCollectionPayload.self, from: $1))
        },
        "ThumbnailReadListAdded": {
            .thumbnailReadListAdded(try $0.decode(ThumbnailReadListPayload.self, from: $1))
        },
        "ThumbnailReadListDeleted": {
            .thumbnailReadListDeleted(try $0.decode(ThumbnailReadListPayload.self, from: $1))
        },
        "SessionExpired": { .sessionExpired(try $0.decode(SessionExpiredPayload.self, from: $1)) },
    ]

    /// `Json.toKomgaEvent(event, data)`; malformed payloads degrade to `.unknown` instead of killing the stream.
    public static func decode(event: String?, data: String?, decoder: JSONDecoder = KomgaJSON.makeDecoder())
        -> KomgaEvent
    {
        guard let data, let event, let decode = decoders[event] else { return .unknown(event: event, data: data) }
        return (try? decode(decoder, Data(data.utf8))) ?? .unknown(event: event, data: data)
    }
}

/// `KomgaSSESession` — a cancellable stream of events.
public protocol KomgaSSESession: Sendable {
    var incoming: AsyncStream<KomgaEvent> { get }
    func cancel()
}
