import Foundation

// Port of snd.komga.client.search.KomgaSearchCondition (+ the builder DSL in ConditionBuilder.kt).
// Wire format is a single-key object per condition: `{"libraryId": {"operator": "is", "value": "..."}}`,
// groups are `{"allOf": [...]}` / `{"anyOf": [...]}` — the same JSON the Komga web UI sends.
// Kotlin's default polymorphic serializer also adds a `"type"` discriminator; Komga ignores it, so it is omitted.

public struct AuthorMatch: SearchValue {
    public var name: String?
    public var role: String?
    public init(name: String? = nil, role: String? = nil) {
        self.name = name
        self.role = role
    }
}

public struct PosterMatch: SearchValue {
    public enum PosterType: String, SearchValue {
        case generated = "GENERATED"
        case sidecar = "SIDECAR"
        case userUploaded = "USER_UPLOADED"
    }

    public var type: PosterType?
    public var selected: Bool?
    public init(type: PosterType? = nil, selected: Bool? = nil) {
        self.type = type
        self.selected = selected
    }
}

public indirect enum BookCondition: SearchValue {
    case anyOf([BookCondition])
    case allOf([BookCondition])
    case libraryId(EqualityOp<KomgaLibraryId>)
    case readListId(EqualityOp<KomgaReadListId>)
    case seriesId(EqualityOp<KomgaSeriesId>)
    case deleted(BooleanOp)
    case oneShot(BooleanOp)
    case title(StringOp)
    case releaseDate(DateOp)
    case numberSort(NumericOp<Float>)
    case tag(EqualityNullableOp<String>)
    case readStatus(EqualityOp<KomgaReadStatus>)
    case mediaStatus(EqualityOp<KomgaMediaStatus>)
    case mediaProfile(EqualityOp<MediaProfile>)
    case author(EqualityOp<AuthorMatch>)
    case poster(EqualityOp<PosterMatch>)

    private enum Key: String, CodingKey, CaseIterable {
        case anyOf, allOf, libraryId, readListId, seriesId, deleted, oneShot, title, releaseDate, numberSort,
             tag, readStatus, mediaStatus, mediaProfile, author, poster
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        guard let key = c.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Empty BookCondition"))
        }
        switch key {
        case .anyOf: self = .anyOf(try c.decode([BookCondition].self, forKey: key))
        case .allOf: self = .allOf(try c.decode([BookCondition].self, forKey: key))
        case .libraryId: self = .libraryId(try c.decode(EqualityOp.self, forKey: key))
        case .readListId: self = .readListId(try c.decode(EqualityOp.self, forKey: key))
        case .seriesId: self = .seriesId(try c.decode(EqualityOp.self, forKey: key))
        case .deleted: self = .deleted(try c.decode(BooleanOp.self, forKey: key))
        case .oneShot: self = .oneShot(try c.decode(BooleanOp.self, forKey: key))
        case .title: self = .title(try c.decode(StringOp.self, forKey: key))
        case .releaseDate: self = .releaseDate(try c.decode(DateOp.self, forKey: key))
        case .numberSort: self = .numberSort(try c.decode(NumericOp.self, forKey: key))
        case .tag: self = .tag(try c.decode(EqualityNullableOp.self, forKey: key))
        case .readStatus: self = .readStatus(try c.decode(EqualityOp.self, forKey: key))
        case .mediaStatus: self = .mediaStatus(try c.decode(EqualityOp.self, forKey: key))
        case .mediaProfile: self = .mediaProfile(try c.decode(EqualityOp.self, forKey: key))
        case .author: self = .author(try c.decode(EqualityOp.self, forKey: key))
        case .poster: self = .poster(try c.decode(EqualityOp.self, forKey: key))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch self {
        case .anyOf(let v): try c.encode(v, forKey: .anyOf)
        case .allOf(let v): try c.encode(v, forKey: .allOf)
        case .libraryId(let v): try c.encode(v, forKey: .libraryId)
        case .readListId(let v): try c.encode(v, forKey: .readListId)
        case .seriesId(let v): try c.encode(v, forKey: .seriesId)
        case .deleted(let v): try c.encode(v, forKey: .deleted)
        case .oneShot(let v): try c.encode(v, forKey: .oneShot)
        case .title(let v): try c.encode(v, forKey: .title)
        case .releaseDate(let v): try c.encode(v, forKey: .releaseDate)
        case .numberSort(let v): try c.encode(v, forKey: .numberSort)
        case .tag(let v): try c.encode(v, forKey: .tag)
        case .readStatus(let v): try c.encode(v, forKey: .readStatus)
        case .mediaStatus(let v): try c.encode(v, forKey: .mediaStatus)
        case .mediaProfile(let v): try c.encode(v, forKey: .mediaProfile)
        case .author(let v): try c.encode(v, forKey: .author)
        case .poster(let v): try c.encode(v, forKey: .poster)
        }
    }
}

public indirect enum SeriesCondition: SearchValue {
    case anyOf([SeriesCondition])
    case allOf([SeriesCondition])
    case libraryId(EqualityOp<KomgaLibraryId>)
    case collectionId(EqualityOp<KomgaCollectionId>)
    case deleted(BooleanOp)
    case complete(BooleanOp)
    case oneShot(BooleanOp)
    case title(StringOp)
    case titleSort(StringOp)
    case releaseDate(DateOp)
    case tag(EqualityNullableOp<String>)
    case sharingLabel(EqualityNullableOp<String>)
    case publisher(EqualityOp<String>)
    case language(EqualityOp<String>)
    case genre(EqualityNullableOp<String>)
    case ageRating(NumericNullableOp<Int>)
    case readStatus(EqualityOp<KomgaReadStatus>)
    case seriesStatus(EqualityOp<KomgaSeriesStatus>)
    case author(EqualityOp<AuthorMatch>)

    private enum Key: String, CodingKey {
        case anyOf, allOf, libraryId, collectionId, deleted, complete, oneShot, title, titleSort, releaseDate, tag,
             sharingLabel, publisher, language, genre, ageRating, readStatus, seriesStatus, author
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        guard let key = c.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Empty SeriesCondition"))
        }
        switch key {
        case .anyOf: self = .anyOf(try c.decode([SeriesCondition].self, forKey: key))
        case .allOf: self = .allOf(try c.decode([SeriesCondition].self, forKey: key))
        case .libraryId: self = .libraryId(try c.decode(EqualityOp.self, forKey: key))
        case .collectionId: self = .collectionId(try c.decode(EqualityOp.self, forKey: key))
        case .deleted: self = .deleted(try c.decode(BooleanOp.self, forKey: key))
        case .complete: self = .complete(try c.decode(BooleanOp.self, forKey: key))
        case .oneShot: self = .oneShot(try c.decode(BooleanOp.self, forKey: key))
        case .title: self = .title(try c.decode(StringOp.self, forKey: key))
        case .titleSort: self = .titleSort(try c.decode(StringOp.self, forKey: key))
        case .releaseDate: self = .releaseDate(try c.decode(DateOp.self, forKey: key))
        case .tag: self = .tag(try c.decode(EqualityNullableOp.self, forKey: key))
        case .sharingLabel: self = .sharingLabel(try c.decode(EqualityNullableOp.self, forKey: key))
        case .publisher: self = .publisher(try c.decode(EqualityOp.self, forKey: key))
        case .language: self = .language(try c.decode(EqualityOp.self, forKey: key))
        case .genre: self = .genre(try c.decode(EqualityNullableOp.self, forKey: key))
        case .ageRating: self = .ageRating(try c.decode(NumericNullableOp.self, forKey: key))
        case .readStatus: self = .readStatus(try c.decode(EqualityOp.self, forKey: key))
        case .seriesStatus: self = .seriesStatus(try c.decode(EqualityOp.self, forKey: key))
        case .author: self = .author(try c.decode(EqualityOp.self, forKey: key))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch self {
        case .anyOf(let v): try c.encode(v, forKey: .anyOf)
        case .allOf(let v): try c.encode(v, forKey: .allOf)
        case .libraryId(let v): try c.encode(v, forKey: .libraryId)
        case .collectionId(let v): try c.encode(v, forKey: .collectionId)
        case .deleted(let v): try c.encode(v, forKey: .deleted)
        case .complete(let v): try c.encode(v, forKey: .complete)
        case .oneShot(let v): try c.encode(v, forKey: .oneShot)
        case .title(let v): try c.encode(v, forKey: .title)
        case .titleSort(let v): try c.encode(v, forKey: .titleSort)
        case .releaseDate(let v): try c.encode(v, forKey: .releaseDate)
        case .tag(let v): try c.encode(v, forKey: .tag)
        case .sharingLabel(let v): try c.encode(v, forKey: .sharingLabel)
        case .publisher(let v): try c.encode(v, forKey: .publisher)
        case .language(let v): try c.encode(v, forKey: .language)
        case .genre(let v): try c.encode(v, forKey: .genre)
        case .ageRating(let v): try c.encode(v, forKey: .ageRating)
        case .readStatus(let v): try c.encode(v, forKey: .readStatus)
        case .seriesStatus(let v): try c.encode(v, forKey: .seriesStatus)
        case .author(let v): try c.encode(v, forKey: .author)
        }
    }
}

// MARK: - Builder helpers (ConditionBuilder.kt `allOfBooks { ... }` / `anyOfSeries { ... }`)
// The Kotlin DSL always wraps the collected conditions in an AllOf/AnyOf group; so do these.

extension BookCondition {
    public static func allOfBooks(_ conditions: BookCondition...) -> BookCondition { .allOf(conditions) }
    public static func anyOfBooks(_ conditions: BookCondition...) -> BookCondition { .anyOf(conditions) }
}

extension SeriesCondition {
    public static func allOfSeries(_ conditions: SeriesCondition...) -> SeriesCondition { .allOf(conditions) }
    public static func anyOfSeries(_ conditions: SeriesCondition...) -> SeriesCondition { .anyOf(conditions) }
}
