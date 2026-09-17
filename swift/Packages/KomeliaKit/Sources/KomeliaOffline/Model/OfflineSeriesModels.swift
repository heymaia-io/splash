import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.series.model.OfflineSeries`.
public struct OfflineSeries: Hashable, Sendable, Identifiable {
    public var id: KomgaSeriesId
    public var libraryId: KomgaLibraryId
    public var name: String
    public var url: String
    public var oneshot: Bool
    public var bookCount: Int
    public var deleted: Bool
    public var created: Date
    public var lastModified: Date
    public var fileLastModified: Date

    public init(
        id: KomgaSeriesId, libraryId: KomgaLibraryId, name: String, url: String, oneshot: Bool, bookCount: Int,
        deleted: Bool, created: Date, lastModified: Date, fileLastModified: Date
    ) {
        self.id = id
        self.libraryId = libraryId
        self.name = name
        self.url = url
        self.oneshot = oneshot
        self.bookCount = bookCount
        self.deleted = deleted
        self.created = created
        self.lastModified = lastModified
        self.fileLastModified = fileLastModified
    }
}

/// Port of `OfflineSeriesMetadata`. The Kotlin class copies every `KomgaSeriesMetadata` field one by one;
/// Swift composes the wire type (same data, no drift when Komga adds a field).
public struct OfflineSeriesMetadata: Hashable, Sendable {
    public var seriesId: KomgaSeriesId
    public var metadata: KomgaSeriesMetadata

    public init(seriesId: KomgaSeriesId, metadata: KomgaSeriesMetadata) {
        self.seriesId = seriesId
        self.metadata = metadata
    }
}

/// Port of `snd.komelia.offline.series.model.OfflineBookMetadataAggregation`.
public struct OfflineBookMetadataAggregation: Hashable, Sendable {
    public var seriesId: KomgaSeriesId
    public var releaseDate: KomgaLocalDate?
    public var summary: String
    public var summaryNumber: String
    public var authors: [KomgaAuthor]
    public var tags: Set<String>
    public var createdDate: Date
    public var lastModifiedDate: Date

    public init(
        seriesId: KomgaSeriesId, releaseDate: KomgaLocalDate? = nil, summary: String = "",
        summaryNumber: String = "", authors: [KomgaAuthor] = [], tags: Set<String> = [],
        createdDate: Date = Date(), lastModifiedDate: Date? = nil
    ) {
        self.seriesId = seriesId
        self.releaseDate = releaseDate
        self.summary = summary
        self.summaryNumber = summaryNumber
        self.authors = authors
        self.tags = tags
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate ?? createdDate
    }
}

/// Port of `OfflineThumbnailSeries` (thumbnail bytes stored inline).
public struct OfflineThumbnailSeries: Hashable, Sendable, Identifiable {
    public enum ThumbnailType: String, Hashable, Sendable {
        case sidecar = "SIDECAR"
        case userUploaded = "USER_UPLOADED"
    }

    public var id: KomgaThumbnailId
    public var seriesId: KomgaSeriesId
    public var type: ThumbnailType
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
    public var url: String?
    public var thumbnail: Data?

    public init(
        id: KomgaThumbnailId, seriesId: KomgaSeriesId, type: ThumbnailType, selected: Bool, mediaType: String,
        fileSize: Int64, width: Int, height: Int, url: String? = nil, thumbnail: Data?
    ) {
        self.id = id
        self.seriesId = seriesId
        self.type = type
        self.selected = selected
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.url = url
        self.thumbnail = thumbnail
    }
}

extension KomgaSeries {
    /// `SeriesKomgaImportAction.toOfflineSeries()`
    public func toOfflineSeries() -> OfflineSeries {
        OfflineSeries(
            id: id, libraryId: libraryId, name: name, url: url, oneshot: oneshot, bookCount: booksCount,
            deleted: deleted, created: created, lastModified: lastModified, fileLastModified: fileLastModified)
    }
}

extension KomgaSeriesThumbnail {
    /// `KomgaSeriesThumbnail.toOfflineThumbnailSeries(bytes)`. Kotlin uses `Type.valueOf` (crashes on
    /// `GENERATED`); unknown types fall back to `SIDECAR` here.
    public func toOfflineThumbnailSeries(bytes: Data) -> OfflineThumbnailSeries {
        OfflineThumbnailSeries(
            id: id, seriesId: seriesId, type: .init(rawValue: type) ?? .sidecar, selected: selected,
            mediaType: mediaType, fileSize: fileSize, width: width, height: height, url: nil, thumbnail: bytes)
    }
}
