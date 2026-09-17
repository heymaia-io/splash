import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.sync.PlatformDownloadManager`: starts and manages long-running downloads with the
/// platform's own mechanism (a `URLSession` here).
public protocol PlatformDownloadManager: Sendable {
    /// Runs a download to completion (download → verify → import). Returns normally when the download was
    /// cancelled by the user; throws when it failed (the failure is also persisted as `BookDownload.failed`).
    func launchBookDownload(_ bookId: KomgaBookId) async throws
    func cancelBookDownload(_ bookId: KomgaBookId) async
}

/// What the offline module needs from the online side. Supplied by the composition root on demand, so logins and
/// server changes are picked up without rebuilding the module.
public struct OfflineRemoteContext: Sendable {
    public var api: any KomgaApi
    /// The server URL as configured by the user (Kotlin `onlineServerUrl`).
    public var serverURL: URL

    public init(api: any KomgaApi, serverURL: URL) {
        self.api = api
        self.serverURL = serverURL
    }
}

/// Port of `snd.komelia.offline.sync.BookDownloadService`, split around the transfer (which the download manager
/// owns): `prepare` fetches the metadata and decides where the file goes; `finish` verifies the file and runs the
/// import sequence of the Kotlin `downloadBook` flow (server → library → series → user → book).
public struct BookDownloadService: Sendable {
    /// Metadata fetched before the transfer (Kotlin fetched it in the same order at the start of `downloadBook`).
    public struct PreparedDownload: Sendable {
        public var book: KomgaBook
        public var series: KomgaSeries
        public var library: KomgaLibrary
        public var user: KomgaUser
        public var serverURL: URL
        /// Download-root-relative path stored in `BOOK.file_download_path`.
        public var storedPath: String
    }

    private let actions: OfflineActions
    private let remote: @Sendable () async throws -> OfflineRemoteContext
    /// Verify `fileHash` (XXH3-128) after the transfer; size is always checked.
    private let verifyHash: Bool

    public init(
        actions: OfflineActions, remote: @escaping @Sendable () async throws -> OfflineRemoteContext,
        verifyHash: Bool = true
    ) {
        self.actions = actions
        self.remote = remote
        self.verifyHash = verifyHash
    }

    var fileLocator: OfflineFileLocator { actions.environment.fileLocator }

    public func prepare(_ bookId: KomgaBookId) async throws -> PreparedDownload {
        let context = try await remote()
        let api = context.api
        let book = try await api.bookApi.getOne(bookId).book
        let user = try await api.userApi.getMe()
        let library = try await api.libraryApi.getLibrary(book.libraryId)
        let series = try await api.seriesApi.getOneSeries(book.seriesId)
        let storedPath = DownloadPathBuilder.relativePath(
            serverURL: context.serverURL, libraryName: library.name, seriesName: series.name, bookURL: book.url)
        return PreparedDownload(
            book: book, series: series, library: library, user: user, serverURL: context.serverURL,
            storedPath: storedPath)
    }

    /// Checks the downloaded bytes against the book's size and (when present) Komga's XXH3-128 `fileHash`.
    public func verify(file: URL, book: KomgaBook) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        if book.sizeBytes > 0, size != book.sizeBytes {
            throw OfflineError.integrityCheckFailed("expected \(book.sizeBytes) bytes, got \(size)")
        }
        guard verifyHash, !book.fileHash.isEmpty else { return }
        let hash = try FileHasher.xxh3_128Hex(of: file)
        if hash.caseInsensitiveCompare(book.fileHash) != .orderedSame {
            throw OfflineError.integrityCheckFailed("file hash \(hash) does not match \(book.fileHash)")
        }
    }

    /// Moves the verified staging file into place and imports everything. The file is removed again if the import
    /// fails (Kotlin: `file?.let { deleteFile(it) }`).
    public func finish(_ prepared: PreparedDownload, stagedFile: URL) async throws {
        try verify(file: stagedFile, book: prepared.book)
        let destination = fileLocator.fileURL(for: prepared.storedPath)
        try Self.moveReplacing(stagedFile, to: destination)
        do {
            let context = try await remote()
            let source = RemoteImportSource(api: context.api)
            let server = try await actions.mediaServerSave.execute(serverUrl: prepared.serverURL.absoluteString)
            try await actions.libraryImport.execute(prepared.library, serverId: server.id)
            try await actions.seriesImport.execute(prepared.series, source: source)
            let user = try await actions.userImport.execute(prepared.user, serverId: server.id)
            try await actions.bookImport.execute(
                book: prepared.book, fileDownloadPath: prepared.storedPath, userId: user.id,
                localFileModifiedDate: prepared.book.fileLastModified, source: source)
        } catch {
            let alreadyImported = try? await actions.environment.store.read { try $0.books.exists(prepared.book.id) }
            if alreadyImported != true { try? FileManager.default.removeItem(at: destination) }
            throw error
        }
    }

    static func moveReplacing(_ source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: source)
        } else {
            try fileManager.moveItem(at: source, to: destination)
        }
    }
}
