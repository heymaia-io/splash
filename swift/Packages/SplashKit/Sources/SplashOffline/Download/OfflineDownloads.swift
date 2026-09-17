import Foundation
import KomgaAPI

/// Facade for the downloads UI and other features that need downloaded files (e.g. the EPUB reader).
/// [NUEVO] — Kotlin screens talked to the task emitter and repositories directly.
public struct OfflineDownloads: Sendable {
    private let store: any OfflineDataStore
    private let taskEmitter: OfflineTaskEmitter
    private let fileLocator: OfflineFileLocator
    private let manager: URLSessionDownloadManager

    public init(
        store: any OfflineDataStore, taskEmitter: OfflineTaskEmitter, fileLocator: OfflineFileLocator,
        manager: URLSessionDownloadManager
    ) {
        self.store = store
        self.taskEmitter = taskEmitter
        self.fileLocator = fileLocator
        self.manager = manager
    }

    // MARK: Queueing (always through the task emitter, like Kotlin)

    public func downloadBook(_ bookId: KomgaBookId) async throws { try await taskEmitter.downloadBook(bookId) }
    public func downloadSeries(_ seriesId: KomgaSeriesId) async throws { try await taskEmitter.downloadSeries(seriesId) }
    public func cancel(_ bookId: KomgaBookId) async throws { try await taskEmitter.cancelBookDownload(bookId) }
    /// Re-queues a FAILED download.
    public func retry(_ bookId: KomgaBookId) async throws { try await taskEmitter.downloadBook(bookId) }
    public func deleteBook(_ bookId: KomgaBookId) async throws { try await taskEmitter.deleteBook(bookId) }
    public func deleteSeries(_ seriesId: KomgaSeriesId) async throws { try await taskEmitter.deleteSeries(seriesId) }
    public func deleteLibrary(_ libraryId: KomgaLibraryId) async throws {
        try await taskEmitter.deleteLibrary(libraryId)
    }

    /// Removes the rows of finished (COMPLETE / FAILED) downloads from the list.
    public func clearFinished() async throws {
        try await store.write { repos in
            let finished = try repos.downloads.findAll().filter { $0.status == .complete || $0.status == .failed }
            try repos.downloads.delete(finished.map(\.bookId))
        }
    }

    // MARK: State

    /// Persisted state of every known download, newest first.
    public func downloads() async throws -> [BookDownload] {
        try await store.read { try $0.downloads.findAll() }
    }

    public func events() -> AsyncStream<DownloadEvent> { manager.events() }

    /// Local file of a downloaded book, or `nil` if the book is not downloaded / the file is missing.
    /// The EPUB (Readium) reader opens this URL directly.
    public func localFileURL(for bookId: KomgaBookId) async throws -> URL? {
        guard let book = try await store.read({ try $0.books.find(bookId) }) else { return nil }
        let url = fileLocator.fileURL(for: book.fileDownloadPath)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// Total size in bytes of the downloaded files that exist on disk.
    public func downloadedBytes() async throws -> Int64 {
        let paths = try await store.read { try $0.books.findAll().map(\.fileDownloadPath) }
        let locator = fileLocator
        return paths.reduce(Int64(0)) { total, path in
            let url = locator.fileURL(for: path)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.size]
            return total + ((size as? NSNumber)?.int64Value ?? 0)
        }
    }
}
