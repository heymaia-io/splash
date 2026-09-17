import Foundation

// Port of snd.komga.client.series.* and common value types.

public struct KomgaAuthor: Codable, Hashable, Sendable {
    public var name: String
    public var role: String

    public init(name: String, role: String) {
        self.name = name
        self.role = role
    }

    /// Well-known roles (`writerRole`, `pencillerRole`, ... in KomgaAuthor.kt).
    public enum Role {
        public static let writer = "writer"
        public static let penciller = "penciller"
        public static let inker = "inker"
        public static let colorist = "colorist"
        public static let letterer = "letterer"
        public static let cover = "cover"
        public static let editor = "editor"
        public static let translator = "translator"
    }
}

public struct KomgaWebLink: Codable, Hashable, Sendable {
    public var label: String
    public var url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public enum KomgaReadingDirection: String, Codable, Hashable, Sendable, CaseIterable {
    case leftToRight = "LEFT_TO_RIGHT"
    case rightToLeft = "RIGHT_TO_LEFT"
    case vertical = "VERTICAL"
    case webtoon = "WEBTOON"
}

public struct KomgaSeries: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaSeriesId
    public var libraryId: KomgaLibraryId
    public var name: String
    public var url: String
    public var booksCount: Int
    public var booksReadCount: Int
    public var booksUnreadCount: Int
    public var booksInProgressCount: Int
    public var metadata: KomgaSeriesMetadata
    public var deleted: Bool
    public var oneshot: Bool
    public var booksMetadata: KomgaSeriesBookMetadata
    public var created: Date
    public var lastModified: Date
    public var fileLastModified: Date

    public init(
        id: KomgaSeriesId, libraryId: KomgaLibraryId, name: String, url: String, booksCount: Int,
        booksReadCount: Int, booksUnreadCount: Int, booksInProgressCount: Int, metadata: KomgaSeriesMetadata,
        deleted: Bool, oneshot: Bool, booksMetadata: KomgaSeriesBookMetadata, created: Date, lastModified: Date,
        fileLastModified: Date
    ) {
        self.id = id
        self.libraryId = libraryId
        self.name = name
        self.url = url
        self.booksCount = booksCount
        self.booksReadCount = booksReadCount
        self.booksUnreadCount = booksUnreadCount
        self.booksInProgressCount = booksInProgressCount
        self.metadata = metadata
        self.deleted = deleted
        self.oneshot = oneshot
        self.booksMetadata = booksMetadata
        self.created = created
        self.lastModified = lastModified
        self.fileLastModified = fileLastModified
    }
}

public struct KomgaSeriesMetadata: Codable, Hashable, Sendable {
    public var status: KomgaSeriesStatus
    public var statusLock: Bool
    public var title: String
    public var alternateTitles: [KomgaAlternativeTitle]
    public var alternateTitlesLock: Bool
    public var titleLock: Bool
    public var titleSort: String
    public var titleSortLock: Bool
    public var summary: String
    public var summaryLock: Bool
    /// Blank string / null / unknown -> nil (KomgaReadingDirectionSerializer).
    @LenientEnum public var readingDirection: KomgaReadingDirection?
    public var readingDirectionLock: Bool
    public var publisher: String
    public var publisherLock: Bool
    public var ageRating: Int?
    public var ageRatingLock: Bool
    public var language: String
    public var languageLock: Bool
    public var genres: [String]
    public var genresLock: Bool
    public var tags: [String]
    public var tagsLock: Bool
    public var totalBookCount: Int?
    public var totalBookCountLock: Bool
    public var sharingLabels: [String]
    public var sharingLabelsLock: Bool
    public var links: [KomgaWebLink]
    public var linksLock: Bool

    public init(
        status: KomgaSeriesStatus, statusLock: Bool = false, title: String,
        alternateTitles: [KomgaAlternativeTitle] = [], alternateTitlesLock: Bool = false, titleLock: Bool = false,
        titleSort: String, titleSortLock: Bool = false, summary: String = "", summaryLock: Bool = false,
        readingDirection: KomgaReadingDirection? = nil, readingDirectionLock: Bool = false, publisher: String = "",
        publisherLock: Bool = false, ageRating: Int? = nil, ageRatingLock: Bool = false, language: String = "",
        languageLock: Bool = false, genres: [String] = [], genresLock: Bool = false, tags: [String] = [],
        tagsLock: Bool = false, totalBookCount: Int? = nil, totalBookCountLock: Bool = false,
        sharingLabels: [String] = [], sharingLabelsLock: Bool = false, links: [KomgaWebLink] = [],
        linksLock: Bool = false
    ) {
        self.status = status
        self.statusLock = statusLock
        self.title = title
        self.alternateTitles = alternateTitles
        self.alternateTitlesLock = alternateTitlesLock
        self.titleLock = titleLock
        self.titleSort = titleSort
        self.titleSortLock = titleSortLock
        self.summary = summary
        self.summaryLock = summaryLock
        self.readingDirection = readingDirection
        self.readingDirectionLock = readingDirectionLock
        self.publisher = publisher
        self.publisherLock = publisherLock
        self.ageRating = ageRating
        self.ageRatingLock = ageRatingLock
        self.language = language
        self.languageLock = languageLock
        self.genres = genres
        self.genresLock = genresLock
        self.tags = tags
        self.tagsLock = tagsLock
        self.totalBookCount = totalBookCount
        self.totalBookCountLock = totalBookCountLock
        self.sharingLabels = sharingLabels
        self.sharingLabelsLock = sharingLabelsLock
        self.links = links
        self.linksLock = linksLock
    }
}

public struct KomgaSeriesBookMetadata: Codable, Hashable, Sendable {
    public var authors: [KomgaAuthor]
    public var tags: [String]
    public var releaseDate: KomgaLocalDate?
    public var summary: String
    public var summaryNumber: String
    public var created: Date
    public var lastModified: Date

    public init(
        authors: [KomgaAuthor], tags: [String], releaseDate: KomgaLocalDate?, summary: String,
        summaryNumber: String, created: Date, lastModified: Date
    ) {
        self.authors = authors
        self.tags = tags
        self.releaseDate = releaseDate
        self.summary = summary
        self.summaryNumber = summaryNumber
        self.created = created
        self.lastModified = lastModified
    }
}

public struct KomgaAlternativeTitle: Codable, Hashable, Sendable {
    public var label: String
    public var title: String

    public init(label: String, title: String) {
        self.label = label
        self.title = title
    }
}

public struct KomgaSeriesThumbnail: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaThumbnailId
    public var seriesId: KomgaSeriesId
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

public enum KomgaSeriesStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case ended = "ENDED"
    case ongoing = "ONGOING"
    case abandoned = "ABANDONED"
    case hiatus = "HIATUS"
}

/// `KomgaSeriesSearch` — body of `POST /api/v1/series/list`.
public struct KomgaSeriesSearch: Codable, Hashable, Sendable {
    public var condition: SeriesCondition?
    public var fullTextSearch: String?

    public init(condition: SeriesCondition? = nil, fullTextSearch: String? = nil) {
        self.condition = condition
        self.fullTextSearch = fullTextSearch
    }
}

public struct KomgaSeriesMetadataUpdateRequest: Encodable, Sendable {
    public var status: PatchValue<KomgaSeriesStatus> = .unset
    public var statusLock: PatchValue<Bool> = .unset
    public var title: PatchValue<String> = .unset
    public var titleLock: PatchValue<Bool> = .unset
    public var titleSort: PatchValue<String> = .unset
    public var titleSortLock: PatchValue<Bool> = .unset
    public var summary: PatchValue<String> = .unset
    public var summaryLock: PatchValue<Bool> = .unset
    public var publisher: PatchValue<String> = .unset
    public var publisherLock: PatchValue<Bool> = .unset
    public var readingDirection: PatchValue<KomgaReadingDirection> = .unset
    public var readingDirectionLock: PatchValue<Bool> = .unset
    public var ageRating: PatchValue<Int> = .unset
    public var ageRatingLock: PatchValue<Bool> = .unset
    public var language: PatchValue<String> = .unset
    public var languageLock: PatchValue<Bool> = .unset
    public var genres: PatchValue<[String]> = .unset
    public var genresLock: PatchValue<Bool> = .unset
    public var tags: PatchValue<[String]> = .unset
    public var tagsLock: PatchValue<Bool> = .unset
    public var totalBookCount: PatchValue<Int> = .unset
    public var totalBookCountLock: PatchValue<Bool> = .unset
    public var sharingLabels: PatchValue<[String]> = .unset
    public var sharingLabelsLock: PatchValue<Bool> = .unset
    public var links: PatchValue<[KomgaWebLink]> = .unset
    public var linksLock: PatchValue<Bool> = .unset
    public var alternateTitles: PatchValue<[KomgaAlternativeTitle]> = .unset
    public var alternateTitlesLock: PatchValue<Bool> = .unset

    public init() {}
}
