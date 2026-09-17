import Foundation
import KomgaAPI

/// Port of the Coil request types handled by `KomeliaFetcherFactory` (9 cases, verbatim).
/// Dispatch is by request *type*, not URL: the loader asks the current `KomgaApi` for bytes, so the same
/// UI works unchanged when the API is the offline implementation serving local BLOBs (Phase 10).
public enum ThumbnailRequest: Hashable, Sendable {
    case bookDefault(KomgaBookId)
    case book(KomgaBookId, KomgaThumbnailId)
    case bookPage(KomgaBookId, page: Int)
    case seriesDefault(KomgaSeriesId)
    case series(KomgaSeriesId, KomgaThumbnailId)
    case collectionDefault(KomgaCollectionId)
    case collection(KomgaCollectionId, KomgaThumbnailId)
    case readListDefault(KomgaReadListId)
    case readList(KomgaReadListId, KomgaThumbnailId)

    /// `KomgaXxxFetcher.fetchBytes()` — strategy selected by case.
    func fetchBytes(from api: any KomgaApi) async throws -> Data? {
        switch self {
        case .bookDefault(let id): try await api.bookApi.getDefaultThumbnail(id)
        case .book(let id, let thumbnail): try await api.bookApi.getThumbnail(id, thumbnailId: thumbnail)
        case .bookPage(let id, let page): try await api.bookApi.getPageThumbnail(id, page: page)
        case .seriesDefault(let id): try await api.seriesApi.getDefaultThumbnail(id)
        case .series(let id, let thumbnail): try await api.seriesApi.getThumbnail(id, thumbnailId: thumbnail)
        case .collectionDefault(let id): try await api.collectionsApi.getDefaultThumbnail(id)
        case .collection(let id, let thumbnail): try await api.collectionsApi.getThumbnail(id, thumbnailId: thumbnail)
        case .readListDefault(let id): try await api.readListApi.getDefaultThumbnail(id)
        case .readList(let id, let thumbnail): try await api.readListApi.getThumbnail(id, thumbnailId: thumbnail)
        }
    }

    /// Stable cache key (also used as the disk file name after hashing).
    public var cacheKey: String {
        switch self {
        case .bookDefault(let id): "book/\(id)"
        case .book(let id, let t): "book/\(id)/\(t)"
        case .bookPage(let id, let page): "book/\(id)/page/\(page)"
        case .seriesDefault(let id): "series/\(id)"
        case .series(let id, let t): "series/\(id)/\(t)"
        case .collectionDefault(let id): "collection/\(id)"
        case .collection(let id, let t): "collection/\(id)/\(t)"
        case .readListDefault(let id): "readlist/\(id)"
        case .readList(let id, let t): "readlist/\(id)/\(t)"
        }
    }

    /// Prefix shared by every request about the same entity (SSE thumbnail events invalidate by prefix).
    public static func prefix(book id: KomgaBookId) -> String { "book/\(id)" }
    public static func prefix(series id: KomgaSeriesId) -> String { "series/\(id)" }
    public static func prefix(collection id: KomgaCollectionId) -> String { "collection/\(id)" }
    public static func prefix(readList id: KomgaReadListId) -> String { "readlist/\(id)" }
}
