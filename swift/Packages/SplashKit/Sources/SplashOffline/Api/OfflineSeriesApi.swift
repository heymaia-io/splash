import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.api.OfflineSeriesApi`.
public struct OfflineSeriesApi: KomgaSeriesApi {
    private let store: any OfflineDataStore
    private let actions: OfflineActions
    private let settings: any OfflineSettingsRepository

    public init(store: any OfflineDataStore, actions: OfflineActions, settings: any OfflineSettingsRepository) {
        self.store = store
        self.actions = actions
        self.settings = settings
    }

    private var userId: KomgaUserId { settings.userId }

    public func getOneSeries(_ seriesId: KomgaSeriesId) async throws -> KomgaSeries {
        let userId = userId
        return try await store.read { try $0.seriesDtos.get(seriesId: seriesId, userId: userId) }
    }

    public func getSeriesList(search: KomgaSeriesSearch, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaSeries>
    {
        let userId = userId
        return try await store.read {
            try $0.seriesDtos.findAll(search: search, userId: userId, pageRequest: pageRequest ?? KomgaPageRequest())
        }
    }

    public func getNewSeries(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> {
        var request = pageRequest ?? KomgaPageRequest()
        request.sort = KomgaSeriesSort.byCreatedDate(.desc)
        let search = KomgaSeriesSearch(condition: Self.condition(libraryIds: libraryIds, oneshot: oneshot, deleted: deleted))
        let userId = userId
        let finalRequest = request
        return try await store.read {
            try $0.seriesDtos.findAll(search: search, userId: userId, pageRequest: finalRequest)
        }
    }

    public func getUpdatedSeries(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> {
        let search = KomgaSeriesSearch(condition: Self.condition(libraryIds: libraryIds, oneshot: oneshot, deleted: deleted))
        let userId = userId
        return try await store.read {
            try $0.seriesDtos.findAllRecentlyUpdated(
                search: search, userId: userId, pageRequest: pageRequest ?? .default)
        }
    }

    /// `allOfSeries { anyOfSeries { library… }; deleted; oneshot }`
    static func condition(libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?) -> SeriesCondition {
        var conditions: [SeriesCondition] = []
        if let libraryIds, !libraryIds.isEmpty {
            conditions.append(.anyOf(libraryIds.map { .libraryId(.isEqualTo($0)) }))
        }
        if let deleted { conditions.append(.deleted(deleted ? .isTrue : .isFalse)) }
        if let oneshot { conditions.append(.oneShot(oneshot ? .isTrue : .isFalse)) }
        return .allOf(conditions)
    }

    public func analyze(_ seriesId: KomgaSeriesId) async throws {
        throw KomgaAPIError.unsupported("Series analysis is not available offline")
    }

    public func refreshMetadata(_ seriesId: KomgaSeriesId) async throws {
        throw KomgaAPIError.unsupported("Metadata refresh is not available offline")
    }

    public func markAsRead(_ seriesId: KomgaSeriesId) async throws {
        try await actions.progressCompleteForSeries.execute(seriesId: seriesId, userId: userId)
    }

    public func markAsUnread(_ seriesId: KomgaSeriesId) async throws {
        try await actions.progressDeleteForSeries.execute(seriesId: seriesId, userId: userId)
    }

    /// Deletes the downloaded copy of the series.
    public func delete(_ seriesId: KomgaSeriesId) async throws {
        try await actions.seriesDelete.execute(seriesId)
    }

    public func update(_ seriesId: KomgaSeriesId, request: KomgaSeriesMetadataUpdateRequest) async throws {
        throw KomgaAPIError.unsupported("Editing series metadata is not available offline")
    }

    /// Selected series thumbnail, else the thumbnail of the book chosen by the library's `seriesCover` rule.
    public func getDefaultThumbnail(_ seriesId: KomgaSeriesId) async throws -> Data? {
        let userId = userId
        return try await store.read { repos in
            if let selected = try repos.seriesThumbnails.findSelectedBySeriesId(seriesId)?.thumbnail {
                return selected
            }
            guard let series = try repos.series.find(seriesId) else { return nil }
            let cover = try repos.libraries.find(series.libraryId)?.seriesCover ?? .first
            let books = repos.books
            let bookId: KomgaBookId? =
                switch cover {
                case .first: try books.findFirstIdInSeries(seriesId)
                case .firstUnreadOrFirst:
                    try books.findFirstUnreadIdInSeries(seriesId, userId: userId)
                        ?? books.findFirstIdInSeries(seriesId)
                case .firstUnreadOrLast:
                    try books.findFirstUnreadIdInSeries(seriesId, userId: userId)
                        ?? books.findLastIdInSeries(seriesId)
                case .last: try books.findLastIdInSeries(seriesId)
                }
            guard let bookId else { return nil }
            return try repos.bookThumbnails.findSelectedByBookId(bookId)?.thumbnail
        }
    }

    public func getThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        guard let data = try await store.read({ try $0.seriesThumbnails.find(thumbnailId)?.thumbnail }) else {
            throw KomgaAPIError.httpStatus(code: 404, body: Data())
        }
        return data
    }

    public func getThumbnails(_ seriesId: KomgaSeriesId) async throws -> [KomgaSeriesThumbnail] {
        let thumbnails = try await store.read { try $0.seriesThumbnails.findAllBySeriesId(seriesId) }
        return try thumbnails.map { thumb in
            try WireValues.decode(
                KomgaSeriesThumbnail.self,
                from: [
                    "id": thumb.id.rawValue, "seriesId": thumb.seriesId.rawValue, "type": thumb.type.rawValue,
                    "selected": thumb.selected, "mediaType": thumb.mediaType, "fileSize": thumb.fileSize,
                    "width": thumb.width, "height": thumb.height,
                ])
        }
    }

    public func uploadThumbnail(_ seriesId: KomgaSeriesId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaSeriesThumbnail
    {
        throw KomgaAPIError.unsupported("Thumbnail upload is not available offline")
    }

    public func selectThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws {
        throw KomgaAPIError.unsupported("Thumbnail selection is not available offline")
    }

    public func deleteThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws {
        throw KomgaAPIError.unsupported("Thumbnail deletion is not available offline")
    }

    public func getAllCollectionsBySeries(_ seriesId: KomgaSeriesId) async throws -> [KomgaCollection] { [] }
}
