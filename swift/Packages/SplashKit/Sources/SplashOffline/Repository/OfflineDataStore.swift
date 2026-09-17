import Foundation
import KomgaAPI

/// Unit of work over the offline database — replaces Kotlin's `TransactionTemplate` + injected repositories.
///
/// Kotlin repositories were `suspend` functions that joined an ambient Exposed transaction. GRDB transactions are
/// synchronous closures that cannot be re-entered, so the Swift design inverts it (Unit of Work pattern): an action
/// opens *one* transaction and receives synchronous repositories bound to it. Network I/O is always done before
/// entering `write`, so the write lock is never held across a request (the Kotlin import actions did hold it).
public protocol OfflineDataStore: Sendable {
    /// Read-only snapshot.
    func read<T: Sendable>(_ body: @escaping @Sendable (any OfflineRepositories) throws -> T) async throws -> T
    /// Single write transaction; rolled back if `body` throws.
    func write<T: Sendable>(_ body: @escaping @Sendable (any OfflineRepositories) throws -> T) async throws -> T
}

/// The repositories visible inside a transaction (port of `OfflineRepositories` minus the tasks/settings
/// repositories, which live outside the unit of work).
public protocol OfflineRepositories {
    var mediaServers: any OfflineMediaServerRepository { get }
    var users: any OfflineUserRepository { get }
    var libraries: any OfflineLibraryRepository { get }
    var series: any OfflineSeriesRepository { get }
    var seriesMetadata: any OfflineSeriesMetadataRepository { get }
    var seriesThumbnails: any OfflineThumbnailSeriesRepository { get }
    var bookMetadataAggregations: any OfflineBookMetadataAggregationRepository { get }
    var books: any OfflineBookRepository { get }
    var bookMetadata: any OfflineBookMetadataRepository { get }
    var bookThumbnails: any OfflineThumbnailBookRepository { get }
    var media: any OfflineMediaRepository { get }
    var readProgress: any OfflineReadProgressRepository { get }
    var logJournal: any LogJournalRepository { get }
    var bookDtos: any OfflineBookDtoRepository { get }
    var seriesDtos: any OfflineSeriesDtoRepository { get }
    var referential: any OfflineReferentialRepository { get }
    /// [NUEVO] persisted download state.
    var downloads: any BookDownloadRepository { get }
}

extension OfflineDataStore {
    /// `LogJournalRepository.save` outside any other transaction; logging must never fail the caller.
    public func log(_ entry: OfflineLogEntry) async {
        _ = try? await write { try $0.logJournal.save(entry) }
    }
}
