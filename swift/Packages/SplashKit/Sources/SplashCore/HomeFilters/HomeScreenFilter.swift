import Foundation
import KomgaAPI

/// Port of `snd.komelia.homefilters.HomeScreenFilter` (sealed hierarchy → enum).
/// Persisted as JSON; the full filter *editor* is out of scope for v1 (plan Phase 6), only defaults +
/// reordering are used, but custom filters decode/encode so the editor can be added later additively.
public enum HomeScreenFilter: Codable, Hashable, Sendable, Identifiable {
    case seriesRecentlyAdded(order: Int, label: String, pageSize: Int)
    case seriesRecentlyUpdated(order: Int, label: String, pageSize: Int)
    case seriesCustom(order: Int, label: String, condition: SeriesCondition?, textSearch: String?, sort: KomgaSort?, pageSize: Int?)
    case booksOnDeck(order: Int, label: String, pageSize: Int)
    case booksCustom(order: Int, label: String, condition: BookCondition?, textSearch: String?, sort: KomgaSort?, pageSize: Int?)

    public var id: Int { order }

    public var order: Int {
        switch self {
        case .seriesRecentlyAdded(let o, _, _), .seriesRecentlyUpdated(let o, _, _), .booksOnDeck(let o, _, _): o
        case .seriesCustom(let o, _, _, _, _, _), .booksCustom(let o, _, _, _, _, _): o
        }
    }

    public var label: String {
        switch self {
        case .seriesRecentlyAdded(_, let l, _), .seriesRecentlyUpdated(_, let l, _), .booksOnDeck(_, let l, _): l
        case .seriesCustom(_, let l, _, _, _, _), .booksCustom(_, let l, _, _, _, _): l
        }
    }

    public var isBookFilter: Bool {
        switch self {
        case .booksOnDeck, .booksCustom: true
        default: false
        }
    }

    /// `getDefaultFilters()` from home/edit/DefaultFilters.kt (same order, conditions and sorts).
    public static var defaults: [HomeScreenFilter] {
        [
            .booksCustom(
                order: 1, label: String(localized: "Keep reading"),
                condition: .allOfBooks(.readStatus(.isEqualTo(.inProgress))), textSearch: nil,
                sort: KomgaBooksSort.byReadDate(.desc), pageSize: nil),
            .booksOnDeck(order: 2, label: String(localized: "On deck"), pageSize: 20),
            .booksCustom(
                order: 3, label: String(localized: "Recently released books"),
                condition: .allOfBooks(.releaseDate(.isInTheLast(.days(30)))), textSearch: nil,
                sort: KomgaBooksSort.byReleaseDate(.desc), pageSize: nil),
            .booksCustom(
                order: 4, label: String(localized: "Recently added books"),
                condition: .allOfBooks(), textSearch: nil,
                sort: KomgaBooksSort.byCreatedDate(.desc), pageSize: 20),
            .seriesRecentlyAdded(order: 5, label: String(localized: "Recently added series"), pageSize: 20),
            .seriesRecentlyUpdated(order: 6, label: String(localized: "Recently updated series"), pageSize: 20),
            .booksCustom(
                order: 7, label: String(localized: "Recently read books"),
                condition: .allOfBooks(.readStatus(.isEqualTo(.read))), textSearch: nil,
                sort: KomgaBooksSort.byReadDate(.desc), pageSize: nil),
        ]
    }

    /// `KomgaPageRequest(sort, size)` of a custom filter.
    public var pageRequest: KomgaPageRequest? {
        switch self {
        case .seriesCustom(_, _, _, _, let sort, let size), .booksCustom(_, _, _, _, let sort, let size):
            KomgaPageRequest(size: size, sort: sort ?? .unsorted)
        default:
            nil
        }
    }
}

extension KomgaSort: Codable {
    public init(from decoder: Decoder) throws {
        self.init(orders: try [Order](from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        try orders.encode(to: encoder)
    }
}

/// `HomeScreenFilterRepository` — whole-list state, like `HomeScreenFilterRepositoryWrapper`.
public typealias HomeScreenFilterRepository = SettingsState<[HomeScreenFilter]>
