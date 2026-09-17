import Foundation
import KomgaAPI

/// Port of `RemoteCollectionsApi.kt` + `HttpCollectionClient.kt`.
public struct RemoteCollectionsApi: KomgaCollectionsApi {
    let http: KomgaHTTPClient

    public init(http: KomgaHTTPClient) { self.http = http }

    public func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaCollection>
    {
        var query: [URLQueryItem] = []
        query.append("search", search)
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        query.appendPage(pageRequest)
        return try await http.fetch(http.request(.get, "api/v1/collections", query: query))
    }

    public func getOne(_ id: KomgaCollectionId) async throws -> KomgaCollection {
        try await http.fetch(http.request(.get, "api/v1/collections/\(id)"))
    }

    public func addOne(_ request: KomgaCollectionCreateRequest) async throws -> KomgaCollection {
        try await http.fetch(http.jsonRequest(.post, "api/v1/collections", body: request))
    }

    public func updateOne(_ id: KomgaCollectionId, request: KomgaCollectionUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/collections/\(id)", body: request))
    }

    public func deleteOne(_ id: KomgaCollectionId) async throws {
        try await http.send(http.request(.delete, "api/v1/collections/\(id)"))
    }

    public func getSeriesForCollection(
        _ id: KomgaCollectionId, query filter: KomgaCollectionQuery?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> {
        var query: [URLQueryItem] = []
        if let filter {
            query.appendList("library_id", filter.libraryIds, transform: \.rawValue)
            query.appendList("read_status", filter.readStatus, transform: \.rawValue)
            query.appendList("status", filter.status, transform: \.rawValue)
            query.appendList("language", filter.languages) { $0 }
            query.appendList("publisher", filter.publishers) { $0 }
            query.appendList("tag", filter.tags) { $0 }
            query.appendList("genre", filter.genres) { $0 }
            query.appendList("age_rating", filter.ageRatings) { $0 }
            query.appendList("release_year", filter.releaseYears) { $0 }
            // Kotlin sends one comma-joined `authors` param; Komga expects repeated `author=name,role`.
            for author in filter.authors ?? [] { query.append("author", "\(author.name),\(author.role)") }
            query.append("complete", filter.complete)
            query.append("deleted", filter.deleted)
        }
        query.appendPage(pageRequest)
        return try await http.fetch(http.request(.get, "api/v1/collections/\(id)/series", query: query))
    }

    public func getDefaultThumbnail(_ collectionId: KomgaCollectionId) async throws -> Data? {
        try await http.nilIfNotFound { try await http.fetchBytes("api/v1/collections/\(collectionId)/thumbnail") }
    }

    public func getThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        try await http.fetchBytes("api/v1/collections/\(collectionId)/thumbnails/\(thumbnailId)")
    }

    public func getThumbnails(_ collectionId: KomgaCollectionId) async throws -> [KomgaCollectionThumbnail] {
        try await http.fetch(http.request(.get, "api/v1/collections/\(collectionId)/thumbnails"))
    }

    public func uploadThumbnail(_ collectionId: KomgaCollectionId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaCollectionThumbnail
    {
        try await http.uploadThumbnail(
            path: "api/v1/collections/\(collectionId)/thumbnails", file: file, filename: filename, selected: selected)
    }

    public func selectThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(
            http.request(.put, "api/v1/collections/\(collectionId)/thumbnails/\(thumbnailId)/selected"))
    }

    public func deleteThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.delete, "api/v1/collections/\(collectionId)/thumbnails/\(thumbnailId)"))
    }
}

/// Port of `RemoteReadListApi.kt` + `HttpReadListClient.kt`.
public struct RemoteReadListApi: KomgaReadListApi {
    let http: KomgaHTTPClient
    let offlineBooks: (any OfflineBookStateProvider)?

    public init(http: KomgaHTTPClient, offlineBooks: (any OfflineBookStateProvider)?) {
        self.http = http
        self.offlineBooks = offlineBooks
    }

    public func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaReadList>
    {
        var query: [URLQueryItem] = []
        query.append("search", search)
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        query.appendPage(pageRequest)
        return try await http.fetch(http.request(.get, "api/v1/readlists", query: query))
    }

    public func getOne(_ id: KomgaReadListId) async throws -> KomgaReadList {
        try await http.fetch(http.request(.get, "api/v1/readlists/\(id)"))
    }

    public func addOne(_ request: KomgaReadListCreateRequest) async throws -> KomgaReadList {
        try await http.fetch(http.jsonRequest(.post, "api/v1/readlists", body: request))
    }

    public func updateOne(_ id: KomgaReadListId, request: KomgaReadListUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/readlists/\(id)", body: request))
    }

    public func deleteOne(_ id: KomgaReadListId) async throws {
        try await http.send(http.request(.delete, "api/v1/readlists/\(id)"))
    }

    public func getBooksForReadList(
        _ id: KomgaReadListId, query filter: KomgaReadListQuery?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<SplashBook> {
        var query: [URLQueryItem] = []
        if let filter {
            query.appendList("library_id", filter.libraryIds, transform: \.rawValue)
            query.appendList("read_status", filter.readStatus, transform: \.rawValue)
            query.appendList("tag", filter.tags) { $0 }
            query.appendList("media_status", filter.mediaStatus, transform: \.rawValue)
            for author in filter.authors ?? [] { query.append("author", "\(author.name),\(author.role)") }
            query.append("deleted", filter.deleted)
        }
        query.appendPage(pageRequest)
        let page: Page<KomgaBook> = try await http.fetch(
            http.request(.get, "api/v1/readlists/\(id)/books", query: query))
        let states = try await offlineBooks?.offlineStates(for: page.content.map(\.id)) ?? [:]
        return page.map { SplashBook(book: $0, offlineState: states[$0.id]) }
    }

    public func getDefaultThumbnail(_ readListId: KomgaReadListId) async throws -> Data? {
        try await http.nilIfNotFound { try await http.fetchBytes("api/v1/readlists/\(readListId)/thumbnail") }
    }

    public func getThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        try await http.fetchBytes("api/v1/readlists/\(readListId)/thumbnails/\(thumbnailId)")
    }

    public func getThumbnails(_ readListId: KomgaReadListId) async throws -> [KomgaReadListThumbnail] {
        try await http.fetch(http.request(.get, "api/v1/readlists/\(readListId)/thumbnails"))
    }

    public func uploadThumbnail(_ readListId: KomgaReadListId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaReadListThumbnail
    {
        try await http.uploadThumbnail(
            path: "api/v1/readlists/\(readListId)/thumbnails", file: file, filename: filename, selected: selected)
    }

    public func selectThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.put, "api/v1/readlists/\(readListId)/thumbnails/\(thumbnailId)/selected"))
    }

    public func deleteThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.delete, "api/v1/readlists/\(readListId)/thumbnails/\(thumbnailId)"))
    }

    public func getBookSiblingNext(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws -> SplashBook? {
        try await sibling("api/v1/readlists/\(readListId)/books/\(bookId)/next")
    }

    public func getBookSiblingPrevious(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws
        -> SplashBook?
    {
        try await sibling("api/v1/readlists/\(readListId)/books/\(bookId)/previous")
    }

    private func sibling(_ path: String) async throws -> SplashBook? {
        guard let book: KomgaBook = try await http.nilIfNotFound({ try await http.fetch(http.request(.get, path)) })
        else { return nil }
        let state = try await offlineBooks?.offlineStates(for: [book.id])[book.id]
        return SplashBook(book: book, offlineState: state)
    }
}
