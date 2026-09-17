import Foundation

// Port of snd.komga.client.collection.* and snd.komga.client.readlist.*

public struct KomgaCollection: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaCollectionId
    public var name: String
    public var ordered: Bool
    public var seriesIds: [KomgaSeriesId]
    public var createdDate: Date
    public var lastModifiedDate: Date
    public var filtered: Bool

    public init(
        id: KomgaCollectionId, name: String, ordered: Bool, seriesIds: [KomgaSeriesId], createdDate: Date,
        lastModifiedDate: Date, filtered: Bool
    ) {
        self.id = id
        self.name = name
        self.ordered = ordered
        self.seriesIds = seriesIds
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.filtered = filtered
    }
}

public struct KomgaCollectionThumbnail: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaThumbnailId
    public var collectionId: KomgaCollectionId
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

public struct KomgaCollectionCreateRequest: Codable, Hashable, Sendable {
    public var name: String
    public var ordered: Bool
    public var seriesIds: [KomgaSeriesId]

    public init(name: String, ordered: Bool, seriesIds: [KomgaSeriesId]) {
        self.name = name
        self.ordered = ordered
        self.seriesIds = seriesIds
    }
}

public struct KomgaCollectionUpdateRequest: Encodable, Sendable {
    public var name: PatchValue<String> = .unset
    public var ordered: PatchValue<Bool> = .unset
    public var seriesIds: PatchValue<[KomgaSeriesId]> = .unset

    public init(
        name: PatchValue<String> = .unset, ordered: PatchValue<Bool> = .unset,
        seriesIds: PatchValue<[KomgaSeriesId]> = .unset
    ) {
        self.name = name
        self.ordered = ordered
        self.seriesIds = seriesIds
    }
}

/// Query-string filter for `GET /api/v1/collections/{id}/series`.
public struct KomgaCollectionQuery: Hashable, Sendable {
    public var libraryIds: [KomgaLibraryId]?
    public var status: [KomgaSeriesStatus]?
    public var readStatus: [KomgaReadStatus]?
    public var publishers: [String]?
    public var languages: [String]?
    public var genres: [String]?
    public var tags: [String]?
    public var ageRatings: [String]?
    public var releaseYears: [String]?
    public var authors: [KomgaAuthor]?
    public var deleted: Bool?
    public var complete: Bool?

    public init() {}
}

public struct KomgaReadList: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaReadListId
    public var name: String
    public var summary: String
    public var ordered: Bool
    public var bookIds: [KomgaBookId]
    public var createdDate: Date
    public var lastModifiedDate: Date
    public var filtered: Bool

    public init(
        id: KomgaReadListId, name: String, summary: String, ordered: Bool, bookIds: [KomgaBookId],
        createdDate: Date, lastModifiedDate: Date, filtered: Bool
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.ordered = ordered
        self.bookIds = bookIds
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.filtered = filtered
    }
}

public struct KomgaReadListThumbnail: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaThumbnailId
    public var readListId: KomgaReadListId
    public var type: String
    public var selected: Bool
    public var mediaType: String
    public var fileSize: Int64
    public var width: Int
    public var height: Int
}

public struct KomgaReadListCreateRequest: Codable, Hashable, Sendable {
    public var name: String
    public var summary: String
    public var ordered: Bool
    public var bookIds: [KomgaBookId]

    public init(name: String, summary: String, ordered: Bool, bookIds: [KomgaBookId]) {
        self.name = name
        self.summary = summary
        self.ordered = ordered
        self.bookIds = bookIds
    }
}

public struct KomgaReadListUpdateRequest: Encodable, Sendable {
    public var name: PatchValue<String> = .unset
    public var summary: PatchValue<String> = .unset
    public var ordered: PatchValue<Bool> = .unset
    public var bookIds: PatchValue<[KomgaBookId]> = .unset

    public init(
        name: PatchValue<String> = .unset, summary: PatchValue<String> = .unset,
        ordered: PatchValue<Bool> = .unset, bookIds: PatchValue<[KomgaBookId]> = .unset
    ) {
        self.name = name
        self.summary = summary
        self.ordered = ordered
        self.bookIds = bookIds
    }
}

/// Query-string filter for `GET /api/v1/readlists/{id}/books`.
public struct KomgaReadListQuery: Hashable, Sendable {
    public var libraryIds: [KomgaLibraryId]?
    public var readStatus: [KomgaReadStatus]?
    public var tags: [String]?
    public var mediaStatus: [KomgaMediaStatus]?
    public var deleted: Bool?
    public var authors: [KomgaAuthor]?

    public init() {}
}
