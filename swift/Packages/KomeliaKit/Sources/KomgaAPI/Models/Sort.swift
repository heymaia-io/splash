import Foundation

/// Port of the sealed `KomgaSort` (common/KomgaSort.kt). The Kotlin subclasses only differ by
/// which property names their factories use, so Swift keeps one value type plus namespaced factories.
public struct KomgaSort: Hashable, Sendable {
    public enum Direction: String, Codable, Hashable, Sendable, CaseIterable {
        case asc
        case desc
    }

    public struct Order: Codable, Hashable, Sendable {
        public var property: String
        public var direction: Direction

        public init(property: String, direction: Direction) {
            self.property = property
            self.direction = direction
        }
    }

    public var orders: [Order]

    public init(orders: [Order]) { self.orders = orders }

    public static let unsorted = KomgaSort(orders: [])

    /// `and(sort)` — appends the other sort's orders.
    public func and(_ other: KomgaSort) -> KomgaSort { KomgaSort(orders: orders + other.orders) }

    fileprivate static func by(_ property: String, _ direction: Direction) -> KomgaSort {
        KomgaSort(orders: [Order(property: property, direction: direction)])
    }
}

/// `KomgaSort.KomgaSeriesSort` factories.
public enum KomgaSeriesSort {
    public static func byTitle(_ d: KomgaSort.Direction) -> KomgaSort { .by("metadata.titleSort", d) }
    public static func byCreatedDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("created", d) }
    public static func byLastModifiedDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("lastModified", d) }
    public static func byReleaseDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("booksMetadata.releaseDate", d) }
    public static func byFolderName(_ d: KomgaSort.Direction) -> KomgaSort { .by("name", d) }
    public static func byBooksCount(_ d: KomgaSort.Direction) -> KomgaSort { .by("booksCount", d) }
}

/// `KomgaSort.KomgaBooksSort` factories.
public enum KomgaBooksSort {
    public static func byCreatedDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("createdDate", d) }
    public static func byFileName(_ d: KomgaSort.Direction) -> KomgaSort { .by("name", d) }
    public static func byFileSize(_ d: KomgaSort.Direction) -> KomgaSort { .by("fileSize", d) }
    public static func byLastModifiedDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("lastModified", d) }
    public static func byNumber(_ d: KomgaSort.Direction) -> KomgaSort { .by("metadata.numberSort", d) }
    public static func byReadDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("readProgress.readDate", d) }
    public static func byReleaseDate(_ d: KomgaSort.Direction) -> KomgaSort { .by("metadata.releaseDate", d) }
    public static func bySeriesTitle(_ d: KomgaSort.Direction) -> KomgaSort { .by("series", d) }
    public static func byTitle(_ d: KomgaSort.Direction) -> KomgaSort { .by("metadata.title", d) }
    public static func byPagesCount(_ d: KomgaSort.Direction) -> KomgaSort { .by("metadata.pagesCount", d) }
}

/// `KomgaSort.KomgaUserSort` factories.
public enum KomgaUserSort {
    public static func byDateTime(_ d: KomgaSort.Direction) -> KomgaSort { .by("dateTime", d) }
}
