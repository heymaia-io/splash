import Foundation
import KomgaAPI

/// Client-side evaluation of a home section, used only by the private area.
///
/// Komga has no id condition for books, so an individually hidden book can never come back from a
/// query — it has to be resolved by id and folded into the right carousel here. That means answering
/// "would this section's server query have returned this book?" locally.
///
/// The answer is deliberately *optional*. Only the operators the default sections actually use are
/// interpreted; anything else returns `nil`, meaning "cannot decide", and the caller leaves the item
/// out rather than guessing. A wrong guess would put a finished book under "Keep reading".
extension HomeScreenFilter {
    /// `nil` when this section's query cannot be evaluated on the client.
    public func matches(_ book: SplashBook, now: Date = Date()) -> Bool? {
        switch self {
        case .booksCustom(_, _, let condition, let text, _, _):
            guard text == nil else { return nil }  // full-text ranking is the server's, not ours
            guard let condition else { return true }
            return condition.evaluate(book, now: now)
        case .booksOnDeck:
            // "On deck" is a server-computed notion (next unread book of a started series) with no
            // faithful client equivalent. Left unmergeable on purpose.
            return nil
        default:
            return nil
        }
    }

    public func matches(_ series: KomgaSeries, now: Date = Date()) -> Bool? {
        switch self {
        case .seriesRecentlyAdded, .seriesRecentlyUpdated:
            return true  // no predicate, only an ordering
        case .seriesCustom(_, _, let condition, let text, _, _):
            guard text == nil else { return nil }
            guard let condition else { return true }
            return condition.evaluate(series, now: now)
        default:
            return nil
        }
    }

    /// Ordering that mirrors the section's server-side sort, so merged items land where they belong.
    public func sorted(_ books: [SplashBook]) -> [SplashBook] {
        switch sortField {
        case "readProgress.readDate":
            return books.sorted { lhs, rhs in
                let a: Date = lhs.readProgress?.readDate ?? .distantPast
                let b: Date = rhs.readProgress?.readDate ?? .distantPast
                return a > b
            }
        case "metadata.releaseDate":
            return books.sorted { lhs, rhs in
                let a: KomgaLocalDate? = lhs.metadata.releaseDate
                let b: KomgaLocalDate? = rhs.metadata.releaseDate
                guard let a else { return false }
                guard let b else { return true }
                return a > b
            }
        case "createdDate":
            return books.sorted { $0.created > $1.created }
        default:
            return books
        }
    }

    public func sorted(_ series: [KomgaSeries]) -> [KomgaSeries] {
        switch self {
        case .seriesRecentlyAdded:
            return series.sorted { $0.created > $1.created }
        case .seriesRecentlyUpdated:
            return series.sorted { $0.lastModified > $1.lastModified }
        default:
            break
        }
        switch sortField {
        case "created": return series.sorted { $0.created > $1.created }
        case "lastModified": return series.sorted { $0.lastModified > $1.lastModified }
        default: return series
        }
    }

    /// How many items this section shows, so a merged carousel never grows unbounded.
    public var mergeLimit: Int {
        switch self {
        case .seriesRecentlyAdded(_, _, let size), .seriesRecentlyUpdated(_, _, let size),
             .booksOnDeck(_, _, let size):
            size
        case .seriesCustom(_, _, _, _, _, let size), .booksCustom(_, _, _, _, _, let size):
            size ?? 20
        }
    }

    private var sortField: String? {
        switch self {
        case .seriesCustom(_, _, _, _, let sort, _), .booksCustom(_, _, _, _, let sort, _):
            sort?.orders.first?.property
        default:
            nil
        }
    }
}

// MARK: - Condition evaluation

extension BookCondition {
    /// `nil` = not decidable on the client.
    func evaluate(_ book: SplashBook, now: Date) -> Bool? {
        switch self {
        case .allOf(let children):
            return children.reduce(Bool?.some(true)) { acc, child in
                guard let acc, let value = child.evaluate(book, now: now) else { return nil }
                return acc && value
            }
        case .anyOf(let children):
            guard !children.isEmpty else { return false }
            return children.reduce(Bool?.some(false)) { acc, child in
                guard let acc, let value = child.evaluate(book, now: now) else { return nil }
                return acc || value
            }
        case .libraryId(let op): return op.evaluate(book.libraryId)
        case .seriesId(let op): return op.evaluate(book.seriesId)
        case .oneShot(let op): return op.evaluate(book.oneshot)
        case .deleted(let op): return op.evaluate(book.deleted)
        case .readStatus(let op): return op.evaluate(book.readStatus)
        case .releaseDate(let op): return op.evaluate(book.metadata.releaseDate?.startOfDay, now: now)
        default: return nil
        }
    }
}

extension SeriesCondition {
    func evaluate(_ series: KomgaSeries, now: Date) -> Bool? {
        switch self {
        case .allOf(let children):
            return children.reduce(Bool?.some(true)) { acc, child in
                guard let acc, let value = child.evaluate(series, now: now) else { return nil }
                return acc && value
            }
        case .anyOf(let children):
            guard !children.isEmpty else { return false }
            return children.reduce(Bool?.some(false)) { acc, child in
                guard let acc, let value = child.evaluate(series, now: now) else { return nil }
                return acc || value
            }
        case .libraryId(let op): return op.evaluate(series.libraryId)
        case .oneShot(let op): return op.evaluate(series.oneshot)
        case .deleted(let op): return op.evaluate(series.deleted)
        default: return nil
        }
    }
}

extension EqualityOp {
    func evaluate(_ value: T) -> Bool where T: Equatable {
        switch self {
        case .isEqualTo(let other): value == other
        case .isNotEqualTo(let other): value != other
        }
    }
}

extension BooleanOp {
    func evaluate(_ value: Bool) -> Bool {
        switch self {
        case .isTrue: value
        case .isFalse: !value
        }
    }
}

extension DateOp {
    func evaluate(_ value: Date?, now: Date) -> Bool {
        switch self {
        case .isNull: return value == nil
        case .isNotNull: return value != nil
        case .before(let date): return value.map { $0 < date } ?? false
        case .after(let date): return value.map { $0 > date } ?? false
        case .isInTheLast(let duration):
            return value.map { $0 > now.addingTimeInterval(-Double(duration.seconds)) } ?? false
        case .isNotInTheLast(let duration):
            return value.map { $0 <= now.addingTimeInterval(-Double(duration.seconds)) } ?? true
        }
    }
}

extension SplashBook {
    /// The read status Komga would report, derived from local progress.
    public var readStatus: KomgaReadStatus {
        guard let progress = book.readProgress else { return .unread }
        return progress.completed ? .read : .inProgress
    }
}

extension KomgaLocalDate {
    /// Midnight UTC, for comparing a calendar date against the `Date`-based operators.
    var startOfDay: Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: components)
    }
}
