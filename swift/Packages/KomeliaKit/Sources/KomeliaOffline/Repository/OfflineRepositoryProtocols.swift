import Foundation
import KomgaAPI

// Ports of the repository interfaces under komelia-domain/offline/.../{server,user,library,series,book,media,
// readprogress,sync}/repository. Methods are synchronous because they run inside an `OfflineDataStore`
// transaction; `get` variants throw `OfflineError.notFound` where Kotlin threw `IllegalStateException`.

public enum OfflineError: Error, Sendable, Equatable, CustomStringConvertible {
    case notFound(String)
    case invalidState(String)
    case invalidArgument(String)
    case fileUnavailable(String)
    case integrityCheckFailed(String)

    public var description: String {
        switch self {
        case .notFound(let m): "Not found: \(m)"
        case .invalidState(let m): "Invalid state: \(m)"
        case .invalidArgument(let m): "Invalid argument: \(m)"
        case .fileUnavailable(let m): "File unavailable: \(m)"
        case .integrityCheckFailed(let m): "Integrity check failed: \(m)"
        }
    }
}

extension Optional {
    /// `find(id) ?: throw …` helper.
    public func orThrow(_ message: @autoclosure () -> String) throws -> Wrapped {
        guard let self else { throw OfflineError.notFound(message()) }
        return self
    }
}

/// `OfflineMediaServerRepository`
public protocol OfflineMediaServerRepository {
    func save(_ server: OfflineMediaServer) throws
    func find(_ id: OfflineMediaServerId) throws -> OfflineMediaServer?
    func findAll() throws -> [OfflineMediaServer]
    func findByUrl(_ url: String) throws -> OfflineMediaServer?
    func findByUserId(_ userId: KomgaUserId) throws -> OfflineMediaServer?
    func delete(_ id: OfflineMediaServerId) throws
}

extension OfflineMediaServerRepository {
    public func get(_ id: OfflineMediaServerId) throws -> OfflineMediaServer {
        try find(id).orThrow("server id \(id)")
    }
}

/// `OfflineUserRepository`
public protocol OfflineUserRepository {
    func save(_ user: OfflineUser) throws
    func find(_ id: KomgaUserId) throws -> OfflineUser?
    func findAll() throws -> [OfflineUser]
    func findAllByServer(_ serverId: OfflineMediaServerId) throws -> [OfflineUser]
    func delete(_ id: KomgaUserId) throws
}

extension OfflineUserRepository {
    public func get(_ id: KomgaUserId) throws -> OfflineUser { try find(id).orThrow("user \(id)") }
}

/// `OfflineLibraryRepository`
public protocol OfflineLibraryRepository {
    func save(_ library: OfflineLibrary) throws
    func find(_ id: KomgaLibraryId) throws -> OfflineLibrary?
    func findAll() throws -> [OfflineLibrary]
    func findAllByMediaServer(_ serverId: OfflineMediaServerId) throws -> [OfflineLibrary]
    func delete(_ id: KomgaLibraryId) throws
}

extension OfflineLibraryRepository {
    public func get(_ id: KomgaLibraryId) throws -> OfflineLibrary { try find(id).orThrow("library \(id)") }
}

/// `OfflineSeriesRepository`
public protocol OfflineSeriesRepository {
    func save(_ series: OfflineSeries) throws
    func find(_ id: KomgaSeriesId) throws -> OfflineSeries?
    func findAllByLibraryId(_ libraryId: KomgaLibraryId) throws -> [OfflineSeries]
    func delete(_ ids: [KomgaSeriesId]) throws
}

extension OfflineSeriesRepository {
    public func get(_ id: KomgaSeriesId) throws -> OfflineSeries { try find(id).orThrow("series \(id)") }
}

/// `OfflineSeriesMetadataRepository`
public protocol OfflineSeriesMetadataRepository {
    func save(_ metadata: OfflineSeriesMetadata) throws
    func find(_ id: KomgaSeriesId) throws -> OfflineSeriesMetadata?
    func delete(_ ids: [KomgaSeriesId]) throws
}

/// `OfflineThumbnailSeriesRepository`
public protocol OfflineThumbnailSeriesRepository {
    func save(_ thumbnail: OfflineThumbnailSeries) throws
    func find(_ id: KomgaThumbnailId) throws -> OfflineThumbnailSeries?
    func findSelectedBySeriesId(_ seriesId: KomgaSeriesId) throws -> OfflineThumbnailSeries?
    func findAllBySeriesId(_ seriesId: KomgaSeriesId) throws -> [OfflineThumbnailSeries]
    func deleteBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws
}

/// `OfflineBookMetadataAggregationRepository`
public protocol OfflineBookMetadataAggregationRepository {
    func save(_ aggregation: OfflineBookMetadataAggregation) throws
    func find(_ seriesId: KomgaSeriesId) throws -> OfflineBookMetadataAggregation?
    func delete(_ seriesIds: [KomgaSeriesId]) throws
}

/// `OfflineBookRepository`
public protocol OfflineBookRepository {
    func save(_ book: OfflineBook) throws
    func find(_ id: KomgaBookId) throws -> OfflineBook?
    func findIn(_ ids: [KomgaBookId]) throws -> [OfflineBook]
    func findAll() throws -> [OfflineBook]
    func findFirstIdInSeries(_ seriesId: KomgaSeriesId) throws -> KomgaBookId?
    func findLastIdInSeries(_ seriesId: KomgaSeriesId) throws -> KomgaBookId?
    func findFirstUnreadIdInSeries(_ seriesId: KomgaSeriesId, userId: KomgaUserId) throws -> KomgaBookId?
    func findAllBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws -> [OfflineBook]
    func findAllIdsBySeriesId(_ seriesId: KomgaSeriesId) throws -> [KomgaBookId]
    func findAllIdsByLibraryId(_ libraryId: KomgaLibraryId) throws -> [KomgaBookId]
    /// Kotlin `findAllNotDeleted`: books whose remote file is still available.
    func findAllNotDeleted(_ seriesId: KomgaSeriesId) throws -> [OfflineBook]
    func delete(_ ids: [KomgaBookId]) throws
}

extension OfflineBookRepository {
    public func get(_ id: KomgaBookId) throws -> OfflineBook { try find(id).orThrow("book \(id)") }
    public func exists(_ id: KomgaBookId) throws -> Bool { try find(id) != nil }
    public func findAll(seriesId: KomgaSeriesId) throws -> [OfflineBook] { try findAllBySeriesIds([seriesId]) }
}

/// `OfflineBookMetadataRepository`
public protocol OfflineBookMetadataRepository {
    func save(_ metadata: OfflineBookMetadata) throws
    func findAllByIds(_ bookIds: [KomgaBookId]) throws -> [OfflineBookMetadata]
    func delete(_ bookIds: [KomgaBookId]) throws
}

extension OfflineBookMetadataRepository {
    public func find(_ id: KomgaBookId) throws -> OfflineBookMetadata? { try findAllByIds([id]).first }
    public func get(_ id: KomgaBookId) throws -> OfflineBookMetadata { try find(id).orThrow("metadata for \(id)") }
}

/// `OfflineThumbnailBookRepository`
public protocol OfflineThumbnailBookRepository {
    func save(_ thumbnail: OfflineThumbnailBook) throws
    func find(_ id: KomgaThumbnailId) throws -> OfflineThumbnailBook?
    func findSelectedByBookId(_ bookId: KomgaBookId) throws -> OfflineThumbnailBook?
    func findAllByBookId(_ bookId: KomgaBookId) throws -> [OfflineThumbnailBook]
    func deleteByBookIds(_ bookIds: [KomgaBookId]) throws
}

/// `OfflineMediaRepository` (+ `OfflineBookPageRepository`, whose rows are saved with the media).
public protocol OfflineMediaRepository {
    func save(_ media: OfflineMedia) throws
    func findAll(_ ids: [KomgaBookId]) throws -> [OfflineMedia]
    func delete(_ bookIds: [KomgaBookId]) throws
}

extension OfflineMediaRepository {
    public func find(_ id: KomgaBookId) throws -> OfflineMedia? { try findAll([id]).first }
    public func get(_ id: KomgaBookId) throws -> OfflineMedia { try find(id).orThrow("media for book \(id)") }
}

/// `OfflineReadProgressRepository`. Every mutation re-aggregates `READ_PROGRESS_SERIES`, like Kotlin.
public protocol OfflineReadProgressRepository {
    func save(_ progress: [OfflineReadProgress]) throws
    func find(bookId: KomgaBookId, userId: KomgaUserId) throws -> OfflineReadProgress?
    func findAllByBookIds(_ bookIds: [KomgaBookId], userId: KomgaUserId) throws -> [OfflineReadProgress]
    func findAllModifiedAfter(_ date: Date, userId: KomgaUserId, serverId: OfflineMediaServerId) throws
        -> [OfflineReadProgress]
    func findAllByServer(userId: KomgaUserId, serverId: OfflineMediaServerId) throws -> [OfflineReadProgress]
    func deleteByUserId(_ userId: KomgaUserId) throws
    func deleteByBookIds(_ bookIds: [KomgaBookId], userId: KomgaUserId) throws
    func deleteBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws
    /// All users.
    func deleteByBookIds(_ bookIds: [KomgaBookId]) throws
}

extension OfflineReadProgressRepository {
    public func save(_ progress: OfflineReadProgress) throws { try save([progress]) }
}

/// `LogJournalRepository`
public protocol LogJournalRepository {
    func save(_ entry: OfflineLogEntry) throws
    func findAll(type: OfflineLogEntry.EntryType?, limit: Int, offset: Int) throws -> Page<OfflineLogEntry>
    func deleteAll() throws
}

/// [NUEVO] `BOOK_DOWNLOAD` persistence.
public protocol BookDownloadRepository {
    func save(_ download: BookDownload) throws
    func find(_ bookId: KomgaBookId) throws -> BookDownload?
    func findAll() throws -> [BookDownload]
    func delete(_ bookIds: [KomgaBookId]) throws
}
