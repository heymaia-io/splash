import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.book.model.OfflineBook`.
///
/// `fileDownloadPath` is the *stored* location of the downloaded file. [NUEVO] New downloads store it relative to
/// the download root (iOS moves the app container on every update, so absolute paths go stale); absolute paths
/// are still accepted. Resolve it with `OfflineFileLocator`.
public struct OfflineBook: Hashable, Sendable, Identifiable {
    public var id: KomgaBookId
    public var seriesId: KomgaSeriesId
    public var libraryId: KomgaLibraryId
    public var name: String
    public var number: Int
    public var deleted: Bool
    public var fileHash: String
    public var oneshot: Bool
    public var url: String
    public var sizeBytes: Int64
    public var created: Date
    public var lastModified: Date
    public var remoteFileLastModified: Date
    public var localFileLastModified: Date
    public var remoteUnavailable: Bool
    public var fileDownloadPath: String

    public init(
        id: KomgaBookId, seriesId: KomgaSeriesId, libraryId: KomgaLibraryId, name: String, number: Int,
        deleted: Bool, fileHash: String, oneshot: Bool, url: String, sizeBytes: Int64, created: Date,
        lastModified: Date, remoteFileLastModified: Date, localFileLastModified: Date, remoteUnavailable: Bool,
        fileDownloadPath: String
    ) {
        self.id = id
        self.seriesId = seriesId
        self.libraryId = libraryId
        self.name = name
        self.number = number
        self.deleted = deleted
        self.fileHash = fileHash
        self.oneshot = oneshot
        self.url = url
        self.sizeBytes = sizeBytes
        self.created = created
        self.lastModified = lastModified
        self.remoteFileLastModified = remoteFileLastModified
        self.localFileLastModified = localFileLastModified
        self.remoteUnavailable = remoteUnavailable
        self.fileDownloadPath = fileDownloadPath
    }

    /// `size` in Kotlin (`"%.2f"` MiB).
    public var size: String { OfflineFormat.mebibytes(sizeBytes) }

    public func markRemoteUnavailable() -> OfflineBook {
        var copy = self
        copy.remoteUnavailable = true
        return copy
    }
}

/// Port of `OfflineBookMetadata` (composes the wire type instead of copying its 20 fields).
public struct OfflineBookMetadata: Hashable, Sendable {
    public var bookId: KomgaBookId
    public var metadata: KomgaBookMetadata

    public init(bookId: KomgaBookId, metadata: KomgaBookMetadata) {
        self.bookId = bookId
        self.metadata = metadata
    }
}

/// Port of `OfflineThumbnailBook`.
public struct OfflineThumbnailBook: Hashable, Sendable, Identifiable {
    public enum ThumbnailType: String, Hashable, Sendable {
        case generated = "GENERATED"
        case sidecar = "SIDECAR"
        case userUploaded = "USER_UPLOADED"
    }

    public var id: KomgaThumbnailId
    public var bookId: KomgaBookId
    public var type: ThumbnailType
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
    public var url: String?
    public var thumbnail: Data?

    public init(
        id: KomgaThumbnailId, bookId: KomgaBookId, type: ThumbnailType, selected: Bool, mediaType: String,
        fileSize: Int64, width: Int, height: Int, url: String? = nil, thumbnail: Data?
    ) {
        self.id = id
        self.bookId = bookId
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

/// Port of `snd.komelia.offline.media.model.OfflineBookPage` (the page number is its list position).
public struct OfflineBookPage: Hashable, Sendable {
    public var bookId: KomgaBookId
    public var fileName: String
    public var mediaType: String
    public var width: Int?
    public var height: Int?
    public var fileSize: Int64?

    public init(
        bookId: KomgaBookId, fileName: String, mediaType: String, width: Int? = nil, height: Int? = nil,
        fileSize: Int64? = nil
    ) {
        self.bookId = bookId
        self.fileName = fileName
        self.mediaType = mediaType
        self.width = width
        self.height = height
        self.fileSize = fileSize
    }
}

/// Port of `snd.komelia.offline.media.model.OfflineMedia`.
public struct OfflineMedia: Hashable, Sendable {
    public var bookId: KomgaBookId
    public var status: KomgaMediaStatus
    public var mediaType: String?
    public var mediaProfile: MediaProfile?
    public var comment: String
    public var epubDivinaCompatible: Bool
    public var epubIsKepub: Bool
    public var pageCount: Int
    public var pages: [OfflineBookPage]
    public var `extension`: MediaExtension?

    public init(
        bookId: KomgaBookId, status: KomgaMediaStatus, mediaType: String?, mediaProfile: MediaProfile?,
        comment: String = "", epubDivinaCompatible: Bool = false, epubIsKepub: Bool = false, pageCount: Int,
        pages: [OfflineBookPage], extension: MediaExtension? = nil
    ) {
        self.bookId = bookId
        self.status = status
        self.mediaType = mediaType
        self.mediaProfile = mediaProfile
        self.comment = comment
        self.epubDivinaCompatible = epubDivinaCompatible
        self.epubIsKepub = epubIsKepub
        self.pageCount = pageCount
        self.pages = pages
        self.extension = `extension`
    }

    public var epubExtension: MediaExtensionEpub? {
        if case .epub(let epub) = self.extension { return epub }
        return nil
    }
}

/// Port of the sealed `MediaExtension`. JSON keeps the kotlinx class discriminator (`"type": "MediaExtensionEpub"`).
public enum MediaExtension: Codable, Hashable, Sendable {
    case epub(MediaExtensionEpub)

    private enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        guard type == MediaExtensionEpub.typeName else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown extension \(type)")
        }
        self = .epub(try MediaExtensionEpub(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .epub(let epub):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(MediaExtensionEpub.typeName, forKey: .type)
            try epub.encode(to: encoder)
        }
    }
}

/// Port of `MediaExtensionEpub` (EPUB reading itself lands in v1.1; the data is stored so it is not lost).
public struct MediaExtensionEpub: Codable, Hashable, Sendable {
    static let typeName = "MediaExtensionEpub"

    public var toc: [EpubTocEntry]
    public var landmarks: [EpubTocEntry]
    public var pageList: [EpubTocEntry]
    public var isFixedLayout: Bool
    public var positions: [R2Locator]
    public var manifest: WPPublication

    public init(
        toc: [EpubTocEntry] = [], landmarks: [EpubTocEntry] = [], pageList: [EpubTocEntry] = [],
        isFixedLayout: Bool = false, positions: [R2Locator] = [], manifest: WPPublication
    ) {
        self.toc = toc
        self.landmarks = landmarks
        self.pageList = pageList
        self.isFixedLayout = isFixedLayout
        self.positions = positions
        self.manifest = manifest
    }
}

/// Port of `EpubTocEntry`.
public struct EpubTocEntry: Codable, Hashable, Sendable {
    public var title: String
    public var href: String?
    public var children: [EpubTocEntry]

    public init(title: String, href: String?, children: [EpubTocEntry] = []) {
        self.title = title
        self.href = href
        self.children = children
    }
}

extension KomgaBook {
    /// `BookKomgaImportAction.toOfflineBook(downloadPath, localFileModifiedDate)`
    public func toOfflineBook(fileDownloadPath: String, localFileModifiedDate: Date) -> OfflineBook {
        OfflineBook(
            id: id, seriesId: seriesId, libraryId: libraryId, name: name, number: number, deleted: deleted,
            fileHash: fileHash, oneshot: oneshot, url: url, sizeBytes: sizeBytes, created: created,
            lastModified: lastModified, remoteFileLastModified: fileLastModified,
            localFileLastModified: localFileModifiedDate, remoteUnavailable: false,
            fileDownloadPath: fileDownloadPath)
    }
}

extension KomgaBookThumbnail {
    /// `KomgaBookThumbnail.toOfflineThumbnailBook(bytes)`
    public func toOfflineThumbnailBook(bytes: Data) -> OfflineThumbnailBook {
        OfflineThumbnailBook(
            id: id, bookId: bookId, type: .init(rawValue: type) ?? .generated, selected: selected,
            mediaType: mediaType, fileSize: fileSize, width: width, height: height, url: nil, thumbnail: bytes)
    }
}

extension KomgaBookPage {
    /// `KomgaBookPage.toOfflineBookPage(bookId)`
    public func toOfflineBookPage(bookId: KomgaBookId) -> OfflineBookPage {
        OfflineBookPage(
            bookId: bookId, fileName: fileName, mediaType: mediaType, width: width, height: height,
            fileSize: sizeBytes)
    }
}

/// Shared number formatting (`formatDecimal(2)` in the Kotlin DTO mappers).
public enum OfflineFormat {
    public static func mebibytes(_ bytes: Int64) -> String {
        String(format: "%.2fMiB", Double(bytes) / 1024 / 1024)
    }
}
