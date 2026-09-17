import Foundation
import KomgaAPI

// Ports of komelia-domain/offline/.../book/actions/*. Not ported (Kotlin bodies are `TODO()`):
// BookAnalyzeAction, BookMetadataRefreshAction, BookMetadataUpdateAction, BookThumbnail{Upload,Select,Delete}Action —
// the offline API throws `KomgaAPIError.unsupported` for those operations instead.

/// Port of `BookDeleteManyAction`.
public struct BookDeleteManyAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ books: [OfflineBook]) async throws {
        let outcome = try await env.store.write { try Self.delete(books, in: $0) }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
    }

    /// Transaction body, reusable by the series/library deletes.
    static func delete(_ books: [OfflineBook], in repos: any OfflineRepositories) throws -> DeletionOutcome {
        guard !books.isEmpty else { return DeletionOutcome() }
        let ids = books.map(\.id)
        try repos.readProgress.deleteByBookIds(ids)
        try repos.media.delete(ids)
        try repos.bookThumbnails.deleteByBookIds(ids)
        try repos.bookMetadata.delete(ids)
        try repos.downloads.delete(ids)  // [NUEVO] download state goes with the book
        try repos.books.delete(ids)
        return DeletionOutcome(events: books.map(OfflineEvents.bookDeleted), filePaths: books.map(\.fileDownloadPath))
    }
}

/// Port of `BookDeleteAction`.
public struct BookDeleteAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ bookId: KomgaBookId) async throws {
        let book = try await env.store.write { repos in
            let book = try repos.books.get(bookId)
            _ = try BookDeleteManyAction.delete([book], in: repos)
            return book
        }
        env.events.emit(env.isOffline ? OfflineEvents.bookDeleted(book) : OfflineEvents.bookChanged(book))
        try await env.taskEmitter.deleteBookFiles(book.fileDownloadPath)
    }
}

/// Port of `BookDeleteFilesAction` (jvm actual): deletes the file and then the series / library / server folders
/// if they became empty. An actor replaces the Kotlin `Mutex`.
public actor BookDeleteFilesAction {
    private let fileLocator: OfflineFileLocator
    private let fileManager = FileManager()

    public init(fileLocator: OfflineFileLocator) { self.fileLocator = fileLocator }

    public func execute(_ storedPath: String) throws {
        let file = fileLocator.fileURL(for: storedPath)
        if fileManager.fileExists(atPath: file.path(percentEncoded: false)) {
            try fileManager.removeItem(at: file)
        }
        let root = fileLocator.downloadRoot().standardizedFileURL
        var directory = file.deletingLastPathComponent()
        for _ in 0..<3 {  // series, library, server
            guard directory.standardizedFileURL != root, isEmptyDirectory(directory) else { break }
            try? fileManager.removeItem(at: directory)
            directory = directory.deletingLastPathComponent()
        }
    }

    private func isEmptyDirectory(_ url: URL) -> Bool {
        let contents = try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false))
        return contents?.filter { $0 != ".DS_Store" }.isEmpty ?? false
    }
}

/// Port of `BookMarkRemoteDeletedAction`.
public struct BookMarkRemoteDeletedAction: Sendable {
    let env: OfflineActionEnvironment

    @discardableResult
    public func execute(_ bookId: KomgaBookId) async throws -> OfflineBook {
        let book = try await env.store.write { repos in
            let book = try repos.books.get(bookId).markRemoteUnavailable()
            try repos.books.save(book)
            return book
        }
        env.events.emit(OfflineEvents.bookChanged(book))
        return book
    }
}

/// Port of `BookKomgaImportAction`: stores a downloaded book with its metadata, media + pages, selected thumbnail
/// and the user's read progress.
///
/// Deviation: everything remote is fetched *before* the write transaction (Kotlin performed HTTP calls while
/// holding it).
public struct BookKomgaImportAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(
        book: KomgaBook, fileDownloadPath: String, userId: KomgaUserId?, localFileModifiedDate: Date,
        source: any OfflineImportSource
    ) async throws {
        do {
            let remote = try await fetchRemote(book: book, userId: userId, source: source)
            let offlineBook = book.toOfflineBook(
                fileDownloadPath: fileDownloadPath, localFileModifiedDate: localFileModifiedDate)
            let (existing, event) = try await env.store.write { repos in
                let existing = try repos.books.find(book.id)
                try repos.books.save(offlineBook)
                try repos.bookMetadata.save(OfflineBookMetadata(bookId: book.id, metadata: book.metadata))
                try repos.media.save(remote.media)
                if let thumbnail = remote.thumbnail {
                    try repos.bookThumbnails.deleteByBookIds([book.id])
                    try repos.bookThumbnails.save(thumbnail)
                }
                if let progress = remote.readProgress {
                    // [NUEVO] last-write-wins: never overwrite a newer local (not yet synced) progress.
                    let local = try repos.readProgress.find(bookId: book.id, userId: progress.userId)
                    if local == nil || local!.lastModifiedDate <= progress.lastModifiedDate {
                        try repos.readProgress.save(progress)
                    }
                }
                try repos.logJournal.save(.info("Book updated '\(book.metadata.title)'"))
                let event = existing == nil ? OfflineEvents.bookAdded(offlineBook) : OfflineEvents.bookChanged(offlineBook)
                return (existing, event)
            }
            if let existing, existing.fileDownloadPath != fileDownloadPath {
                try await env.taskEmitter.deleteBookFiles(existing.fileDownloadPath)
            }
            try await env.taskEmitter.aggregateSeriesMetadata(book.seriesId)
            env.events.emit(event)
        } catch {
            await env.store.log(.error("Book update error '\(book.metadata.title)'", error))
            throw error
        }
    }

    private struct RemoteData: Sendable {
        var media: OfflineMedia
        var thumbnail: OfflineThumbnailBook?
        var readProgress: OfflineReadProgress?
    }

    private func fetchRemote(book: KomgaBook, userId: KomgaUserId?, source: any OfflineImportSource) async throws
        -> RemoteData
    {
        let pages: [OfflineBookPage]
        let mediaExtension: MediaExtensionEpub?
        if book.media.mediaProfile == .epub {
            // [NUEVO] EPUBs must import even without a page list (non-Divina EPUBs have none) or Readium data;
            // the EPUB reader opens the downloaded file directly.
            pages = ((try? await source.bookPages(book.id)) ?? []).map { $0.toOfflineBookPage(bookId: book.id) }
            mediaExtension = try? await epubExtension(book, source: source)
        } else {
            pages = try await source.bookPages(book.id).map { $0.toOfflineBookPage(bookId: book.id) }
            mediaExtension = nil
        }
        let media = OfflineMedia(
            bookId: book.id, status: book.media.status, mediaType: book.media.mediaType,
            mediaProfile: book.media.mediaProfile, comment: book.media.comment,
            epubDivinaCompatible: book.media.epubDivinaCompatible, epubIsKepub: book.media.epubIsKepub,
            pageCount: book.media.pagesCount, pages: pages, extension: mediaExtension.map(MediaExtension.epub))
        let thumbnail = try await source.selectedBookThumbnail(book.id)
        let progress: OfflineReadProgress? =
            if let userId { try await readProgress(book, userId: userId, source: source) } else { nil }
        return RemoteData(media: media, thumbnail: thumbnail, readProgress: progress)
    }

    private func epubExtension(_ book: KomgaBook, source: any OfflineImportSource) async throws
        -> MediaExtensionEpub?
    {
        guard book.media.mediaProfile == .epub else { return nil }
        let positions = try await source.readiumPositions(book.id).positions
        let manifest = try await source.webPubManifest(book.id)
        let isFixedLayout = manifest.metadata.rendition?["layout"] == .string("fixed")
        return MediaExtensionEpub(
            toc: manifest.toc.map(Self.tocEntry), landmarks: manifest.landmarks.map(Self.tocEntry),
            pageList: manifest.pageList.map(Self.tocEntry), isFixedLayout: isFixedLayout, positions: positions,
            manifest: manifest)
    }

    private func readProgress(_ book: KomgaBook, userId: KomgaUserId, source: any OfflineImportSource) async throws
        -> OfflineReadProgress?
    {
        guard let progress = book.readProgress else { return nil }
        switch book.media.mediaProfile {
        case .divina, .pdf:
            return progress.toOfflineReadProgress(bookId: book.id, userId: userId)
        case .epub:
            guard let locator = try? await source.readiumProgression(book.id)?.locator else { return nil }
            return progress.toOfflineReadProgress(bookId: book.id, userId: userId, locator: locator)
        case nil:
            return nil
        }
    }

    private static func tocEntry(_ link: WPLink) -> EpubTocEntry {
        EpubTocEntry(title: link.title ?? "", href: link.href, children: (link.children ?? []).map(tocEntry))
    }
}
