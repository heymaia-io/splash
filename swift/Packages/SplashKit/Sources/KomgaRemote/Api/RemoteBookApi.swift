import Foundation
import KomgaAPI

/// Port of `RemoteBookApi.kt` + `HttpBookClient.kt`.
public struct RemoteBookApi: KomgaBookApi {
    let http: KomgaHTTPClient
    let offlineBooks: (any OfflineBookStateProvider)?

    public init(http: KomgaHTTPClient, offlineBooks: (any OfflineBookStateProvider)?) {
        self.http = http
        self.offlineBooks = offlineBooks
    }

    public func getOne(_ bookId: KomgaBookId) async throws -> SplashBook {
        let book: KomgaBook = try await http.fetch(http.request(.get, "api/v1/books/\(bookId)"))
        return try await komeliaBook(book)
    }

    public func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> {
        var query: [URLQueryItem] = []
        query.appendPage(pageRequest)
        let page: Page<KomgaBook> = try await http.fetch(
            http.jsonRequest(.post, "api/v1/books/list", query: query, body: search))
        return try await komeliaPage(page)
    }

    public func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> {
        var query: [URLQueryItem] = []
        query.appendPage(pageRequest)
        let page: Page<KomgaBook> = try await http.fetch(http.request(.get, "api/v1/books/latest", query: query))
        return try await komeliaPage(page)
    }

    public func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<SplashBook>
    {
        var query: [URLQueryItem] = []
        query.appendPage(pageRequest)
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        let page: Page<KomgaBook> = try await http.fetch(http.request(.get, "api/v1/books/ondeck", query: query))
        return try await komeliaPage(page)
    }

    public func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> {
        var query: [URLQueryItem] = []
        query.appendPage(pageRequest)
        let page: Page<KomgaBook> = try await http.fetch(http.request(.get, "api/v1/books/duplicates", query: query))
        return try await komeliaPage(page)
    }

    public func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> SplashBook? {
        try await sibling("api/v1/books/\(bookId)/previous")
    }

    public func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> SplashBook? {
        try await sibling("api/v1/books/\(bookId)/next")
    }

    public func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/books/\(bookId)/metadata", body: request))
    }

    public func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] {
        try await http.fetch(http.request(.get, "api/v1/books/\(bookId)/pages"))
    }

    public func analyze(_ bookId: KomgaBookId) async throws {
        try await http.send(http.request(.post, "api/v1/books/\(bookId)/analyze"))
    }

    public func refreshMetadata(_ bookId: KomgaBookId) async throws {
        try await http.send(http.request(.post, "api/v1/books/\(bookId)/metadata/refresh"))
    }

    public func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/books/\(bookId)/read-progress", body: request))
    }

    public func deleteReadProgress(_ bookId: KomgaBookId) async throws {
        try await http.send(http.request(.delete, "api/v1/books/\(bookId)/read-progress"))
    }

    public func deleteBook(_ bookId: KomgaBookId) async throws {
        try await http.send(http.request(.delete, "api/v1/books/\(bookId)/file"))
    }

    public func regenerateThumbnails(forBiggerResultOnly: Bool) async throws {
        var query: [URLQueryItem] = []
        query.append("for_bigger_result_only", forBiggerResultOnly)
        try await http.send(http.request(.put, "api/v1/books/thumbnails", query: query))
    }

    public func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data? {
        try await http.nilIfNotFound { try await http.fetchBytes("api/v1/books/\(bookId)/thumbnail") }
    }

    public func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        try await http.fetchBytes("api/v1/books/\(bookId)/thumbnails/\(thumbnailId)")
    }

    public func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail] {
        try await http.fetch(http.request(.get, "api/v1/books/\(bookId)/thumbnails"))
    }

    public func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaBookThumbnail
    {
        try await http.uploadThumbnail(
            path: "api/v1/books/\(bookId)/thumbnails", file: file, filename: filename, selected: selected)
    }

    public func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.put, "api/v1/books/\(bookId)/thumbnails/\(thumbnailId)/selected"))
    }

    public func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.delete, "api/v1/books/\(bookId)/thumbnails/\(thumbnailId)"))
    }

    public func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList] {
        try await http.fetch(http.request(.get, "api/v1/books/\(bookId)/readlists"))
    }

    public func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data {
        try await http.fetchBytes("api/v1/books/\(bookId)/pages/\(page)")
    }

    public func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data {
        try await http.fetchBytes("api/v1/books/\(bookId)/pages/\(page)/thumbnail")
    }

    public func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? {
        let (data, response) = try await http.send(
            http.request(.get, "api/v1/books/\(bookId)/progression", headers: ["Accept": "*/*"]))
        if response.statusCode == 204 { return nil }
        return try http.decode(R2Progression.self, from: data)
    }

    public func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws {
        try await http.send(http.jsonRequest(.put, "api/v1/books/\(bookId)/progression", body: progression))
    }

    public func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions {
        try await http.fetch(http.request(.get, "api/v1/books/\(bookId)/positions", headers: ["Accept": "*/*"]))
    }

    public func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication {
        try await http.fetch(http.request(.get, "api/v1/books/\(bookId)/manifest", headers: ["Accept": "*/*"]))
    }

    public func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data {
        try await http.fetchBytes("api/v1/books/\(bookId)/resource/\(resourceName)")
    }

    // MARK: - Download seam (used by the offline download manager, Phase 11)

    /// `GET api/v1/books/{id}/file` with auth headers, suitable for a background `URLSession` download task.
    /// Note: Komga 1.27 ignores `Range`, so downloads cannot be resumed from `resumeData`.
    public func bookFileRequest(_ bookId: KomgaBookId) -> URLRequest {
        http.request(.get, "api/v1/books/\(bookId)/file", headers: ["Accept": "*/*"])
    }

    // MARK: - SplashBook mapping (getSplashBook / getSplashBookPage)

    private func sibling(_ path: String) async throws -> SplashBook? {
        guard let book: KomgaBook = try await http.nilIfNotFound({ try await http.fetch(http.request(.get, path)) })
        else { return nil }
        return try await komeliaBook(book)
    }

    private func komeliaBook(_ book: KomgaBook) async throws -> SplashBook {
        let state = try await offlineBooks?.offlineStates(for: [book.id])[book.id]
        return SplashBook(book: book, offlineState: state)
    }

    private func komeliaPage(_ page: Page<KomgaBook>) async throws -> Page<SplashBook> {
        let states = try await offlineBooks?.offlineStates(for: page.content.map(\.id)) ?? [:]
        return page.map { SplashBook(book: $0, offlineState: states[$0.id]) }
    }
}
