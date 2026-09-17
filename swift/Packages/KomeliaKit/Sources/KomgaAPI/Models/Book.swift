import Foundation

// Port of snd.komga.client.book.KomgaBooks.kt / KomgaBookPage.kt / request types.

public struct KomgaBook: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaBookId
    public var seriesId: KomgaSeriesId
    public var seriesTitle: String
    public var libraryId: KomgaLibraryId
    public var name: String
    public var url: String
    public var number: Int
    public var created: Date
    public var lastModified: Date
    public var fileLastModified: Date
    public var sizeBytes: Int64
    public var size: String
    public var media: Media
    public var metadata: KomgaBookMetadata
    public var readProgress: ReadProgress?
    public var deleted: Bool
    public var fileHash: String
    public var oneshot: Bool

    public init(
        id: KomgaBookId, seriesId: KomgaSeriesId, seriesTitle: String, libraryId: KomgaLibraryId, name: String,
        url: String, number: Int, created: Date, lastModified: Date, fileLastModified: Date, sizeBytes: Int64,
        size: String, media: Media, metadata: KomgaBookMetadata, readProgress: ReadProgress?, deleted: Bool,
        fileHash: String, oneshot: Bool
    ) {
        self.id = id
        self.seriesId = seriesId
        self.seriesTitle = seriesTitle
        self.libraryId = libraryId
        self.name = name
        self.url = url
        self.number = number
        self.created = created
        self.lastModified = lastModified
        self.fileLastModified = fileLastModified
        self.sizeBytes = sizeBytes
        self.size = size
        self.media = media
        self.metadata = metadata
        self.readProgress = readProgress
        self.deleted = deleted
        self.fileHash = fileHash
        self.oneshot = oneshot
    }
}

public struct KomgaBookMetadata: Codable, Hashable, Sendable {
    public var title: String
    public var summary: String
    public var number: String
    public var numberSort: Float
    public var releaseDate: KomgaLocalDate?
    public var authors: [KomgaAuthor]
    public var tags: [String]
    public var isbn: String
    public var links: [KomgaWebLink]

    public var titleLock: Bool
    public var summaryLock: Bool
    public var numberLock: Bool
    public var numberSortLock: Bool
    public var releaseDateLock: Bool
    public var authorsLock: Bool
    public var tagsLock: Bool
    public var isbnLock: Bool
    public var linksLock: Bool

    public var created: Date
    public var lastModified: Date

    public init(
        title: String, summary: String, number: String, numberSort: Float, releaseDate: KomgaLocalDate?,
        authors: [KomgaAuthor], tags: [String], isbn: String, links: [KomgaWebLink], titleLock: Bool = false,
        summaryLock: Bool = false, numberLock: Bool = false, numberSortLock: Bool = false,
        releaseDateLock: Bool = false, authorsLock: Bool = false, tagsLock: Bool = false, isbnLock: Bool = false,
        linksLock: Bool = false, created: Date, lastModified: Date
    ) {
        self.title = title
        self.summary = summary
        self.number = number
        self.numberSort = numberSort
        self.releaseDate = releaseDate
        self.authors = authors
        self.tags = tags
        self.isbn = isbn
        self.links = links
        self.titleLock = titleLock
        self.summaryLock = summaryLock
        self.numberLock = numberLock
        self.numberSortLock = numberSortLock
        self.releaseDateLock = releaseDateLock
        self.authorsLock = authorsLock
        self.tagsLock = tagsLock
        self.isbnLock = isbnLock
        self.linksLock = linksLock
        self.created = created
        self.lastModified = lastModified
    }
}

public struct KomgaBookThumbnail: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaThumbnailId
    public var bookId: KomgaBookId
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

public struct Media: Codable, Hashable, Sendable {
    public var status: KomgaMediaStatus
    public var mediaType: String?
    public var pagesCount: Int
    public var comment: String
    public var epubDivinaCompatible: Bool
    public var epubIsKepub: Bool
    @LenientEnum public var mediaProfile: MediaProfile?

    public init(
        status: KomgaMediaStatus, mediaType: String?, pagesCount: Int, comment: String,
        epubDivinaCompatible: Bool, epubIsKepub: Bool, mediaProfile: MediaProfile?
    ) {
        self.status = status
        self.mediaType = mediaType
        self.pagesCount = pagesCount
        self.comment = comment
        self.epubDivinaCompatible = epubDivinaCompatible
        self.epubIsKepub = epubIsKepub
        self.mediaProfile = mediaProfile
    }
}

public enum MediaProfile: String, Codable, Hashable, Sendable, CaseIterable {
    case divina = "DIVINA"
    case pdf = "PDF"
    case epub = "EPUB"
}

public struct ReadProgress: Codable, Hashable, Sendable {
    public var page: Int
    public var completed: Bool
    public var readDate: Date
    public var deviceId: String
    public var deviceName: String
    public var created: Date
    public var lastModified: Date

    public init(
        page: Int, completed: Bool, readDate: Date, deviceId: String, deviceName: String, created: Date,
        lastModified: Date
    ) {
        self.page = page
        self.completed = completed
        self.readDate = readDate
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.created = created
        self.lastModified = lastModified
    }
}

public enum KomgaMediaStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case ready = "READY"
    case unknown = "UNKNOWN"
    case error = "ERROR"
    case unsupported = "UNSUPPORTED"
    case outdated = "OUTDATED"
}

public enum KomgaReadStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case unread = "UNREAD"
    case inProgress = "IN_PROGRESS"
    case read = "READ"
}

public enum CopyMode: String, Codable, Hashable, Sendable {
    case move = "MOVE"
    case copy = "COPY"
    case hardlink = "HARDLINK"
}

public struct KomgaBookPage: Codable, Hashable, Sendable {
    public var number: Int
    public var fileName: String
    public var mediaType: String
    public var width: Int?
    public var height: Int?
    public var sizeBytes: Int64?
    public var size: String

    public init(
        number: Int, fileName: String, mediaType: String, width: Int?, height: Int?, sizeBytes: Int64?, size: String
    ) {
        self.number = number
        self.fileName = fileName
        self.mediaType = mediaType
        self.width = width
        self.height = height
        self.sizeBytes = sizeBytes
        self.size = size
    }
}

public struct KomgaBookReadProgressUpdateRequest: Codable, Hashable, Sendable {
    public var page: Int?
    public var completed: Bool?

    public init(page: Int? = nil, completed: Bool? = nil) {
        self.page = page
        self.completed = completed
    }
}

public struct KomgaBookMetadataUpdateRequest: Encodable, Sendable {
    public var title: PatchValue<String> = .unset
    public var titleLock: PatchValue<Bool> = .unset
    public var summary: PatchValue<String> = .unset
    public var summaryLock: PatchValue<Bool> = .unset
    public var number: PatchValue<String> = .unset
    public var numberLock: PatchValue<Bool> = .unset
    public var numberSort: PatchValue<Float> = .unset
    public var numberSortLock: PatchValue<Bool> = .unset
    public var releaseDate: PatchValue<KomgaLocalDate> = .unset
    public var releaseDateLock: PatchValue<Bool> = .unset
    public var authors: PatchValue<[KomgaAuthor]> = .unset
    public var authorsLock: PatchValue<Bool> = .unset
    public var tags: PatchValue<[String]> = .unset
    public var tagsLock: PatchValue<Bool> = .unset
    public var isbn: PatchValue<String> = .unset
    public var isbnLock: PatchValue<Bool> = .unset
    public var links: PatchValue<[KomgaWebLink]> = .unset
    public var linksLock: PatchValue<Bool> = .unset

    public init() {}
}

/// `KomgaBookSearch` — body of `POST /api/v1/books/list`.
public struct KomgaBookSearch: Codable, Hashable, Sendable {
    public var condition: BookCondition?
    public var fullTextSearch: String?

    public init(condition: BookCondition? = nil, fullTextSearch: String? = nil) {
        self.condition = condition
        self.fullTextSearch = fullTextSearch
    }
}

/// Book with Komelia's offline bookkeeping — port of `snd.komelia.komga.api.model.KomeliaBook`.
/// Kotlin copies every `KomgaBook` field; Swift composes and forwards via dynamic member lookup
/// (structs cannot inherit), so `komeliaBook.name` still works.
@dynamicMemberLookup
public struct KomeliaBook: Codable, Hashable, Sendable, Identifiable {
    public var book: KomgaBook
    public var downloaded: Bool
    public var localFileLastModified: Date?
    public var remoteFileUnavailable: Bool

    public init(
        book: KomgaBook, downloaded: Bool = false, localFileLastModified: Date? = nil,
        remoteFileUnavailable: Bool = false
    ) {
        self.book = book
        self.downloaded = downloaded
        self.localFileLastModified = localFileLastModified
        self.remoteFileUnavailable = remoteFileUnavailable
    }

    public var id: KomgaBookId { book.id }

    public subscript<T>(dynamicMember keyPath: KeyPath<KomgaBook, T>) -> T {
        book[keyPath: keyPath]
    }

    /// Compared at epoch-second precision, exactly like the Kotlin property.
    public var isLocalFileOutdated: Bool {
        guard let localFileLastModified else { return false }
        return Int64(localFileLastModified.timeIntervalSince1970.rounded(.down))
            != Int64(book.fileLastModified.timeIntervalSince1970.rounded(.down))
    }
}
