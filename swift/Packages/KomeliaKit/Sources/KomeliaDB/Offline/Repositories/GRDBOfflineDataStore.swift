import Foundation
import GRDB
import KomeliaOffline
import KomgaAPI

/// GRDB implementation of the offline Unit of Work (`TransactionTemplate` + the `Exposed*Repository` classes of
/// komelia-infra/database/sqlite/.../db/offline).
public struct GRDBOfflineDataStore: OfflineDataStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    public init(database: KomeliaDatabase) { self.init(database.offline) }

    public func read<T: Sendable>(_ body: @escaping @Sendable (any OfflineRepositories) throws -> T) async throws -> T {
        try await writer.read { db in try body(GRDBOfflineRepositories(db: db)) }
    }

    public func write<T: Sendable>(_ body: @escaping @Sendable (any OfflineRepositories) throws -> T) async throws -> T {
        try await writer.write { db in try body(GRDBOfflineRepositories(db: db)) }
    }
}

/// Repositories bound to one open GRDB transaction.
struct GRDBOfflineRepositories: OfflineRepositories {
    let db: Database

    var mediaServers: any OfflineMediaServerRepository { GRDBMediaServerRepository(db: db) }
    var users: any OfflineUserRepository { GRDBUserRepository(db: db) }
    var libraries: any OfflineLibraryRepository { GRDBLibraryRepository(db: db) }
    var series: any OfflineSeriesRepository { GRDBSeriesRepository(db: db) }
    var seriesMetadata: any OfflineSeriesMetadataRepository { GRDBSeriesMetadataRepository(db: db) }
    var seriesThumbnails: any OfflineThumbnailSeriesRepository { GRDBThumbnailSeriesRepository(db: db) }
    var bookMetadataAggregations: any OfflineBookMetadataAggregationRepository {
        GRDBBookMetadataAggregationRepository(db: db)
    }
    var books: any OfflineBookRepository { GRDBBookRepository(db: db) }
    var bookMetadata: any OfflineBookMetadataRepository { GRDBBookMetadataRepository(db: db) }
    var bookThumbnails: any OfflineThumbnailBookRepository { GRDBThumbnailBookRepository(db: db) }
    var media: any OfflineMediaRepository { GRDBMediaRepository(db: db) }
    var readProgress: any OfflineReadProgressRepository { GRDBReadProgressRepository(db: db) }
    var logJournal: any LogJournalRepository { GRDBLogJournalRepository(db: db) }
    var bookDtos: any OfflineBookDtoRepository { GRDBBookDtoRepository(db: db) }
    var seriesDtos: any OfflineSeriesDtoRepository { GRDBSeriesDtoRepository(db: db) }
    var referential: any OfflineReferentialRepository { GRDBReferentialRepository(db: db) }
    var downloads: any BookDownloadRepository { GRDBBookDownloadRepository(db: db) }
}

/// JSON columns (`MEDIA.extension`, `READ_PROGRESS.locator`) use the Komga wire encoding.
enum OfflineJSON {
    static func encode(_ value: some Encodable) throws -> String {
        String(decoding: try KomgaJSON.makeEncoder().encode(value), as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String?) -> T? {
        guard let string, !string.isEmpty else { return nil }
        return try? KomgaJSON.makeDecoder().decode(type, from: Data(string.utf8))
    }
}
