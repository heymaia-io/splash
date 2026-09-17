import Foundation
import KomgaAPI

/// The remote reads the import actions need (Interface Segregation: Kotlin injected the whole
/// `KomgaBookClient`/`KomgaSeriesClient`). Tests provide a stub; the app uses `RemoteImportSource`.
public protocol OfflineImportSource: Sendable {
    func bookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage]
    /// The selected thumbnail and its bytes (`getThumbnails().firstOrNull { selected }` + `getThumbnail`).
    func selectedBookThumbnail(_ bookId: KomgaBookId) async throws -> OfflineThumbnailBook?
    func selectedSeriesThumbnail(_ seriesId: KomgaSeriesId) async throws -> OfflineThumbnailSeries?
    func readiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions
    func webPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication
    func readiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression?
}

/// Adapter from any `KomgaApi` (normally `RemoteKomgaApi`) to `OfflineImportSource`.
public struct RemoteImportSource: OfflineImportSource {
    private let api: any KomgaApi

    public init(api: any KomgaApi) { self.api = api }

    public func bookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] {
        try await api.bookApi.getBookPages(bookId)
    }

    public func selectedBookThumbnail(_ bookId: KomgaBookId) async throws -> OfflineThumbnailBook? {
        guard let thumb = try await api.bookApi.getThumbnails(bookId).first(where: \.selected) else { return nil }
        let bytes = try await api.bookApi.getThumbnail(thumb.bookId, thumbnailId: thumb.id)
        return thumb.toOfflineThumbnailBook(bytes: bytes)
    }

    public func selectedSeriesThumbnail(_ seriesId: KomgaSeriesId) async throws -> OfflineThumbnailSeries? {
        guard let thumb = try await api.seriesApi.getThumbnails(seriesId).first(where: \.selected) else { return nil }
        let bytes = try await api.seriesApi.getThumbnail(thumb.seriesId, thumbnailId: thumb.id)
        return thumb.toOfflineThumbnailSeries(bytes: bytes)
    }

    public func readiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions {
        try await api.bookApi.getReadiumPositions(bookId)
    }

    public func webPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication {
        try await api.bookApi.getWebPubManifest(bookId)
    }

    public func readiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? {
        try await api.bookApi.getReadiumProgression(bookId)
    }
}
