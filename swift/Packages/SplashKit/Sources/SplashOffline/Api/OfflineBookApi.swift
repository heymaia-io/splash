import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.api.OfflineBookApi`.
public struct OfflineBookApi: KomgaBookApi {
    private let store: any OfflineDataStore
    private let actions: OfflineActions
    private let extractors: BookContentExtractors
    private let settings: any OfflineSettingsRepository

    public init(
        store: any OfflineDataStore, actions: OfflineActions, extractors: BookContentExtractors,
        settings: any OfflineSettingsRepository
    ) {
        self.store = store
        self.actions = actions
        self.extractors = extractors
        self.settings = settings
    }

    private var userId: KomgaUserId { settings.userId }

    public func getOne(_ bookId: KomgaBookId) async throws -> SplashBook {
        let userId = userId
        return try await store.read { try $0.bookDtos.get(bookId: bookId, userId: userId) }
    }

    public func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> {
        let userId = userId
        return try await store.read {
            try $0.bookDtos.findAll(userId: userId, search: search, pageRequest: pageRequest ?? .init(unpaged: true))
        }
    }

    public func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> {
        var request = pageRequest ?? KomgaPageRequest()
        request.sort = KomgaBooksSort.byLastModifiedDate(.desc)
        let userId = userId
        let finalRequest = request
        return try await store.read {
            try $0.bookDtos.findAll(userId: userId, search: KomgaBookSearch(), pageRequest: finalRequest)
        }
    }

    public func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<SplashBook>
    {
        let userId = userId
        return try await store.read {
            try $0.bookDtos.findAllOnDeck(
                userId: userId, libraryIds: libraryIds, pageRequest: pageRequest ?? KomgaPageRequest())
        }
    }

    public func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { .empty() }

    public func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> SplashBook? {
        let userId = userId
        return try await store.read { try $0.bookDtos.findPreviousInSeries(bookId: bookId, userId: userId) }
    }

    public func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> SplashBook? {
        let userId = userId
        return try await store.read { try $0.bookDtos.findNextInSeries(bookId: bookId, userId: userId) }
    }

    public func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws {
        throw KomgaAPIError.unsupported("Editing book metadata is not available offline")
    }

    public func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] {
        let media = try await store.read { try $0.media.get(bookId) }
        switch media.status {
        case .unknown: throw OfflineError.invalidState("Book has not been analyzed yet")
        case .outdated: throw OfflineError.invalidState("Book is outdated and must be re-analyzed")
        case .error: throw OfflineError.invalidState("Book analysis failed")
        case .unsupported: throw OfflineError.invalidState("Book format is not supported")
        case .ready:
            return media.pages.enumerated().map { index, page in
                KomgaBookPage(
                    number: index + 1, fileName: page.fileName, mediaType: page.mediaType, width: page.width,
                    height: page.height, sizeBytes: page.fileSize,
                    size: page.fileSize.map(OfflineFormat.mebibytes) ?? "")
            }
        }
    }

    public func analyze(_ bookId: KomgaBookId) async throws {
        throw KomgaAPIError.unsupported("Book analysis is not available offline")
    }

    public func refreshMetadata(_ bookId: KomgaBookId) async throws {
        throw KomgaAPIError.unsupported("Metadata refresh is not available offline")
    }

    /// Stored locally; `SyncReadProgressAction` pushes it when the server is reachable again.
    public func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws {
        if request.completed == true {
            try await actions.progressCompleteForBook.execute(bookId: bookId, userId: userId)
        } else {
            guard let page = request.page else { throw OfflineError.invalidArgument("page is required") }
            try await actions.progressMark.execute(bookId: bookId, userId: userId, page: page)
        }
    }

    public func deleteReadProgress(_ bookId: KomgaBookId) async throws {
        try await actions.progressDeleteForBook.execute(bookId: bookId, userId: userId)
    }

    /// Deletes the *downloaded copy* (the server file is untouched), like Kotlin.
    public func deleteBook(_ bookId: KomgaBookId) async throws {
        try await actions.bookDelete.execute(bookId)
    }

    public func regenerateThumbnails(forBiggerResultOnly: Bool) async throws {}

    public func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data? {
        try await store.read { try $0.bookThumbnails.findSelectedByBookId(bookId)?.thumbnail }
    }

    public func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        // Kotlin: TODO(). Only stored (downloaded) thumbnails exist offline.
        guard let data = try await store.read({ try $0.bookThumbnails.find(thumbnailId)?.thumbnail }) else {
            throw KomgaAPIError.httpStatus(code: 404, body: Data())
        }
        return data
    }

    public func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail] {
        let thumbnails = try await store.read { try $0.bookThumbnails.findAllByBookId(bookId) }
        return try thumbnails.map { thumb in
            try WireValues.decode(
                KomgaBookThumbnail.self,
                from: [
                    "id": thumb.id.rawValue, "bookId": thumb.bookId.rawValue, "type": thumb.type.rawValue,
                    "selected": thumb.selected, "mediaType": thumb.mediaType, "fileSize": thumb.fileSize,
                    "width": thumb.width, "height": thumb.height,
                ])
        }
    }

    public func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaBookThumbnail
    {
        throw KomgaAPIError.unsupported("Thumbnail upload is not available offline")
    }

    public func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {
        throw KomgaAPIError.unsupported("Thumbnail selection is not available offline")
    }

    public func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {
        throw KomgaAPIError.unsupported("Thumbnail deletion is not available offline")
    }

    public func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList] { [] }

    public func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data {
        let (book, media) = try await bookAndMedia(bookId)
        return try await extractors.bookPage(book: book, media: media, page: page)
    }

    /// Kotlin returns the raw page too ("resize is handled in client").
    public func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data {
        try await getPage(bookId, page: page)
    }

    public func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? {
        let userId = userId
        let progress = try await store.read { try $0.readProgress.find(bookId: bookId, userId: userId) }
        return progress.map {
            R2Progression(
                modified: $0.readDate, device: R2Device(id: $0.deviceId, name: $0.deviceName),
                locator: $0.locator ?? R2Locator())
        }
    }

    public func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws {
        try await actions.progressMarkProgression.execute(bookId: bookId, userId: userId, progression: progression)
    }

    public func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions {
        let media = try await store.read { try $0.media.get(bookId) }
        guard let epub = media.epubExtension else { throw OfflineError.invalidState("Unsupported book type") }
        return try WireValues.decodeEncodable(
            R2Positions.self, from: PositionsWire(total: epub.positions.count, positions: epub.positions))
    }

    private func bookAndMedia(_ bookId: KomgaBookId) async throws -> (OfflineBook, OfflineMedia) {
        try await store.read { repos in (try repos.books.get(bookId), try repos.media.get(bookId)) }
    }

    public func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication {
        let media = try await store.read { try $0.media.get(bookId) }
        guard let epub = media.epubExtension else { throw OfflineError.invalidState("Unsupported book type") }
        return epub.manifest
    }

    public func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data {
        let (book, media) = try await bookAndMedia(bookId)
        guard media.mediaProfile == .epub else {
            throw OfflineError.invalidState("Unsupported media profile \(String(describing: media.mediaProfile))")
        }
        return try await extractors.fileContent(book: book, media: media, fileName: resourceName)
    }
}

private struct PositionsWire: Encodable {
    var total: Int
    var positions: [R2Locator]
}
