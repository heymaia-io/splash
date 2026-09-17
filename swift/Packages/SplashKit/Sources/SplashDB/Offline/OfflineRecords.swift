import Foundation
import GRDB

/// Row types for the most-queried offline tables. They mirror the Exposed table objects in
/// `komelia-infra/database/sqlite/.../db/offline/tables/*.kt` column-for-column (camelCase properties map to the
/// snake_case SQL columns). Mapping to/from the offline domain models happens in the repositories (later phase),
/// so enum-like columns stay `String` here and JSON columns stay raw JSON `String`.
public protocol OfflineRecord: Codable, Sendable, FetchableRecord, PersistableRecord {}

extension OfflineRecord {
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
}

/// `OfflineMediaServerTable` (`OFFLINE_MEDIA_SERVER`).
public struct OfflineMediaServerRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "OFFLINE_MEDIA_SERVER"
    public var id: String
    public var url: String

    public init(id: String, url: String) {
        self.id = id
        self.url = url
    }
}

/// `OfflineLibraryTable` (`LIBRARY`) — a snapshot of the Komga library options.
public struct OfflineLibraryRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "LIBRARY"
    public var id: String
    public var serverId: String
    public var name: String
    public var root: String
    public var importComicInfoBook: Bool
    public var importComicInfoSeries: Bool
    public var importComicInfoCollection: Bool
    public var importComicInfoReadList: Bool
    public var importComicInfoSeriesAppendVolume: Bool
    public var importEpubBook: Bool
    public var importEpubSeries: Bool
    public var importMylarSeries: Bool
    public var importLocalArtwork: Bool
    public var importBarcodeIsbn: Bool
    public var scanForceModifiedTime: Bool
    public var scanOnStartup: Bool
    public var scanInterval: String
    public var scanCbx: Bool
    public var scanPdf: Bool
    public var scanEpub: Bool
    public var repairExtensions: Bool
    public var convertToCbz: Bool
    public var emptyTrashAfterScan: Bool
    public var seriesCover: String
    public var hashFiles: Bool
    public var hashPages: Bool
    public var hashKoreader: Bool
    public var analyzeDimensions: Bool
    public var oneshotsDirectory: String?
    public var unavailable: Bool
}

/// `OfflineUserTable` (`USER`).
public struct OfflineUserRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "USER"
    public var id: String
    public var serverId: String?
    public var email: String
    public var sharedAllLibraries: Bool
    public var ageRestriction: Int?
    public var ageRestrictionAllowOnly: Bool?

    public init(
        id: String, serverId: String?, email: String, sharedAllLibraries: Bool,
        ageRestriction: Int? = nil, ageRestrictionAllowOnly: Bool? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.email = email
        self.sharedAllLibraries = sharedAllLibraries
        self.ageRestriction = ageRestriction
        self.ageRestrictionAllowOnly = ageRestrictionAllowOnly
    }
}

/// `OfflineSeriesTable` (`SERIES`).
public struct OfflineSeriesRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "SERIES"
    public var id: String
    public var libraryId: String
    public var name: String
    public var url: String
    public var booksCount: Int
    public var deleted: Bool
    public var oneshot: Bool
    public var createdDate: Date
    public var lastModifiedDate: Date
    public var fileLastModifiedDate: Date

    public init(
        id: String, libraryId: String, name: String, url: String, booksCount: Int,
        deleted: Bool = false, oneshot: Bool = false,
        createdDate: Date, lastModifiedDate: Date, fileLastModifiedDate: Date
    ) {
        self.id = id
        self.libraryId = libraryId
        self.name = name
        self.url = url
        self.booksCount = booksCount
        self.deleted = deleted
        self.oneshot = oneshot
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.fileLastModifiedDate = fileLastModifiedDate
    }
}

/// `OfflineSeriesMetadataTable` (`SERIES_METADATA`). Collections (genres, tags, …) live in child tables.
public struct OfflineSeriesMetadataRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "SERIES_METADATA"
    public var seriesId: String
    public var status: String
    public var statusLock: Bool
    public var title: String
    public var titleLock: Bool
    public var titleSort: String
    public var titleSortLock: Bool
    public var alternateTitlesLock: Bool
    public var publisher: String
    public var publisherLock: Bool
    public var summary: String
    public var summaryLock: Bool
    public var readingDirection: String?
    public var readingDirectionLock: Bool
    public var ageRating: Int?
    public var ageRatingLock: Bool
    public var language: String
    public var languageLock: Bool
    public var genresLock: Bool
    public var tagsLock: Bool
    public var totalBookCount: Int?
    public var totalBookCountLock: Bool
    public var sharingLabelsLock: Bool
    public var linksLock: Bool
}

/// `OfflineBookTable` (`BOOK`). `fileDownloadPath` is where the downloaded file lives locally.
public struct OfflineBookRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "BOOK"
    public var id: String
    public var seriesId: String
    public var libraryId: String
    public var name: String
    public var url: String
    public var fileSize: Int64
    public var number: Int
    public var fileHash: String
    public var deleted: Bool
    public var oneshot: Bool
    public var createdDate: Date
    public var lastModifiedDate: Date
    public var remoteFileModifiedDate: Date
    public var localFileModifiedDate: Date
    public var remoteUnavailable: Bool
    public var fileDownloadPath: String

    public init(
        id: String, seriesId: String, libraryId: String, name: String, url: String,
        fileSize: Int64, number: Int, fileHash: String, deleted: Bool = false, oneshot: Bool = false,
        createdDate: Date, lastModifiedDate: Date, remoteFileModifiedDate: Date, localFileModifiedDate: Date,
        remoteUnavailable: Bool = false, fileDownloadPath: String
    ) {
        self.id = id
        self.seriesId = seriesId
        self.libraryId = libraryId
        self.name = name
        self.url = url
        self.fileSize = fileSize
        self.number = number
        self.fileHash = fileHash
        self.deleted = deleted
        self.oneshot = oneshot
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.remoteFileModifiedDate = remoteFileModifiedDate
        self.localFileModifiedDate = localFileModifiedDate
        self.remoteUnavailable = remoteUnavailable
        self.fileDownloadPath = fileDownloadPath
    }
}

/// `OfflineBookMetadataTable` (`BOOK_METADATA`). `releaseDate` is an ISO `yyyy-MM-dd` local date.
public struct OfflineBookMetadataRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "BOOK_METADATA"
    public var bookId: String
    public var number: String
    public var numberLock: Bool
    public var numberSort: Float
    public var numberSortLock: Bool
    public var releaseDate: String?
    public var releaseDateLock: Bool
    public var summary: String
    public var summaryLock: Bool
    public var title: String
    public var titleLock: Bool
    public var authorsLock: Bool
    public var tagsLock: Bool
    public var isbn: String
    public var isbnLock: Bool
    public var linksLock: Bool
    public var createdDate: Date
    public var lastModifiedDate: Date
}

/// `OfflineMediaTable` (`MEDIA`). `extension` is the JSON-encoded `MediaExtension`.
public struct OfflineMediaRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "MEDIA"
    public var bookId: String
    public var status: String
    public var mediaType: String?
    public var mediaProfile: String?
    public var pageCount: Int
    public var comment: String?
    public var epubDivinaCompatible: Bool
    public var epubIsKepub: Bool
    public var `extension`: String?

    public init(
        bookId: String, status: String, mediaType: String?, mediaProfile: String?, pageCount: Int,
        comment: String? = nil, epubDivinaCompatible: Bool = false, epubIsKepub: Bool = false,
        extension: String? = nil
    ) {
        self.bookId = bookId
        self.status = status
        self.mediaType = mediaType
        self.mediaProfile = mediaProfile
        self.pageCount = pageCount
        self.comment = comment
        self.epubDivinaCompatible = epubDivinaCompatible
        self.epubIsKepub = epubIsKepub
        self.extension = `extension`
    }
}

/// `OfflineMediaPageTable` (`MEDIA_PAGE`), keyed by (book, page number).
public struct OfflineMediaPageRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "MEDIA_PAGE"
    public var bookId: String
    public var number: Int
    public var fileName: String
    public var mediaType: String
    public var width: Int?
    public var height: Int?
    public var fileSize: Int64?

    public init(
        bookId: String, number: Int, fileName: String, mediaType: String,
        width: Int? = nil, height: Int? = nil, fileSize: Int64? = nil
    ) {
        self.bookId = bookId
        self.number = number
        self.fileName = fileName
        self.mediaType = mediaType
        self.width = width
        self.height = height
        self.fileSize = fileSize
    }
}

/// `OfflineReadProgressTable` (`READ_PROGRESS`). `locator` is the JSON-encoded `R2Locator`.
public struct OfflineReadProgressRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "READ_PROGRESS"
    public var bookId: String
    public var userId: String
    public var page: Int
    public var completed: Bool
    public var readDate: Date?
    public var deviceId: String
    public var deviceName: String
    public var locator: String?
    public var createdDate: Date
    public var lastModifiedDate: Date
}

/// `OfflineThumbnailBookTable` (`THUMBNAIL_BOOK`). `thumbnail` holds the image bytes when stored inline.
public struct OfflineThumbnailBookRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "THUMBNAIL_BOOK"
    public var id: String
    public var bookId: String
    public var thumbnail: Data?
    public var url: String?
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

/// `OfflineThumbnailSeriesTable` (`THUMBNAIL_SERIES`).
public struct OfflineThumbnailSeriesRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "THUMBNAIL_SERIES"
    public var id: String
    public var seriesId: String
    public var thumbnail: Data?
    public var url: String?
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

/// `OfflineTaskTable` (`TASK`) — port of `TaskEntry` as stored. `task` is the JSON-encoded `TaskData`.
public struct OfflineTaskRecord: OfflineRecord, Hashable {
    public static let databaseTableName = "TASK"

    /// `TaskEntry.TaskStatus`.
    public enum Status: String, Codable, Sendable {
        case new = "NEW", running = "RUNNING"
    }

    public var uniqueName: String
    public var priority: Int
    public var status: Status
    public var task: String
    public var createdDate: Date

    public init(uniqueName: String, priority: Int, status: Status = .new, task: String, createdDate: Date = Date()) {
        self.uniqueName = uniqueName
        self.priority = priority
        self.status = status
        self.task = task
        self.createdDate = createdDate
    }
}
