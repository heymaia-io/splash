import Foundation
import KomgaAPI

/// Port of `RemoteSeriesApi.kt` + `HttpSeriesClient.kt` (deprecated GET listing endpoints are not ported).
public struct RemoteSeriesApi: KomgaSeriesApi {
    let http: KomgaHTTPClient

    public init(http: KomgaHTTPClient) { self.http = http }

    public func getOneSeries(_ seriesId: KomgaSeriesId) async throws -> KomgaSeries {
        try await http.fetch(http.request(.get, "api/v1/series/\(seriesId)"))
    }

    public func getSeriesList(search: KomgaSeriesSearch, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaSeries>
    {
        var query: [URLQueryItem] = []
        query.appendPage(pageRequest)
        return try await http.fetch(http.jsonRequest(.post, "api/v1/series/list", query: query, body: search))
    }

    public func getNewSeries(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> {
        try await http.fetch(http.request(
            .get, "api/v1/series/new",
            query: Self.filterQuery(libraryIds: libraryIds, oneshot: oneshot, deleted: deleted, page: pageRequest)))
    }

    public func getUpdatedSeries(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> {
        try await http.fetch(http.request(
            .get, "api/v1/series/updated",
            query: Self.filterQuery(libraryIds: libraryIds, oneshot: oneshot, deleted: deleted, page: pageRequest)))
    }

    public func analyze(_ seriesId: KomgaSeriesId) async throws {
        try await http.send(http.request(.post, "api/v1/series/\(seriesId)/analyze"))
    }

    public func refreshMetadata(_ seriesId: KomgaSeriesId) async throws {
        try await http.send(http.request(.post, "api/v1/series/\(seriesId)/metadata/refresh"))
    }

    public func markAsRead(_ seriesId: KomgaSeriesId) async throws {
        try await http.send(http.request(.post, "api/v1/series/\(seriesId)/read-progress"))
    }

    public func markAsUnread(_ seriesId: KomgaSeriesId) async throws {
        try await http.send(http.request(.delete, "api/v1/series/\(seriesId)/read-progress"))
    }

    public func delete(_ seriesId: KomgaSeriesId) async throws {
        try await http.send(http.request(.delete, "api/v1/series/\(seriesId)/file"))
    }

    public func update(_ seriesId: KomgaSeriesId, request: KomgaSeriesMetadataUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/series/\(seriesId)/metadata", body: request))
    }

    public func getDefaultThumbnail(_ seriesId: KomgaSeriesId) async throws -> Data? {
        try await http.nilIfNotFound { try await http.fetchBytes("api/v1/series/\(seriesId)/thumbnail") }
    }

    public func getThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        try await http.fetchBytes("api/v1/series/\(seriesId)/thumbnails/\(thumbnailId)")
    }

    public func getThumbnails(_ seriesId: KomgaSeriesId) async throws -> [KomgaSeriesThumbnail] {
        try await http.fetch(http.request(.get, "api/v1/series/\(seriesId)/thumbnails"))
    }

    public func uploadThumbnail(_ seriesId: KomgaSeriesId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaSeriesThumbnail
    {
        try await http.uploadThumbnail(
            path: "api/v1/series/\(seriesId)/thumbnails", file: file, filename: filename, selected: selected)
    }

    public func selectThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.put, "api/v1/series/\(seriesId)/thumbnails/\(thumbnailId)/selected"))
    }

    public func deleteThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws {
        try await http.send(http.request(.delete, "api/v1/series/\(seriesId)/thumbnails/\(thumbnailId)"))
    }

    public func getAllCollectionsBySeries(_ seriesId: KomgaSeriesId) async throws -> [KomgaCollection] {
        try await http.fetch(http.request(.get, "api/v1/series/\(seriesId)/collections"))
    }

    private static func filterQuery(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, page: KomgaPageRequest?
    ) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        query.append("oneshot", oneshot)
        query.append("deleted", deleted)
        query.appendPage(page)
        return query
    }
}
