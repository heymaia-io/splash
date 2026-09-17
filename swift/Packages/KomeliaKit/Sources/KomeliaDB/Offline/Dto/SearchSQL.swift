import Foundation
import GRDB
import KomgaAPI

/// Port of `conditions/SearchOperatorUtils.kt`: search operators → SQL fragments (parameterized via GRDB `SQL`
/// interpolation). Deliberate fixes, each matching Komga server semantics:
/// - `BooleanOp.isTrue` / `isFalse` were inverted in Kotlin (`IsFalse -> field.eq(true)`).
/// - `anyOf` folded from `TRUE` with OR (always true); it now ORs its members.
/// - Case-insensitive comparisons lowercase both sides (Kotlin lowercased only the column).
/// - `LIKE` patterns escape `%` / `_`; "is not" on nullable columns keeps NULL rows (SQL three-valued logic).
enum SearchSQL {
    static let alwaysTrue: SQL = "1"
    static let alwaysFalse: SQL = "0"

    static func and(_ parts: [SQL]) -> SQL {
        parts.isEmpty ? alwaysTrue : "(" + parts.joined(separator: " AND ") + ")"
    }

    /// An empty `anyOf` does not restrict anything (Komga ignores it).
    static func or(_ parts: [SQL]) -> SQL {
        parts.isEmpty ? alwaysTrue : "(" + parts.joined(separator: " OR ") + ")"
    }

    static func equality(_ op: EqualityOp<String>, _ column: SQL, nullable: Bool = false, ignoreCase: Bool = false)
        -> SQL
    {
        let field: SQL = ignoreCase ? "LOWER(\(column))" : column
        switch op {
        case .isEqualTo(let value):
            return "\(field) = \(ignoreCase ? value.lowercased() : value)"
        case .isNotEqualTo(let value):
            let comparison: SQL = "\(field) <> \(ignoreCase ? value.lowercased() : value)"
            return nullable ? "(\(column) IS NULL OR \(comparison))" : comparison
        }
    }

    static func equality<T>(_ op: EqualityOp<T>, _ column: SQL, nullable: Bool = false, _ value: (T) -> String)
        -> SQL
    {
        switch op {
        case .isEqualTo(let v): equality(.isEqualTo(value(v)), column, nullable: nullable)
        case .isNotEqualTo(let v): equality(.isNotEqualTo(value(v)), column, nullable: nullable)
        }
    }

    static func string(_ op: StringOp, _ column: SQL) -> SQL {
        let field: SQL = "LOWER(\(column))"
        switch op {
        case .isEqualTo(let v): return "\(field) = \(v.lowercased())"
        case .isNotEqualTo(let v): return "\(field) <> \(v.lowercased())"
        case .contains(let v): return like(field, "%" + escapeLike(v) + "%")
        case .doesNotContain(let v): return "NOT " + like(field, "%" + escapeLike(v) + "%")
        case .beginsWith(let v): return like(field, escapeLike(v) + "%")
        case .doesNotBeginWith(let v): return "NOT " + like(field, escapeLike(v) + "%")
        case .endsWith(let v): return like(field, "%" + escapeLike(v))
        case .doesNotEndWith(let v): return "NOT " + like(field, "%" + escapeLike(v))
        }
    }

    /// Case-insensitive `LIKE '%term%'` (full-text search substitute).
    static func contains(_ column: SQL, _ term: String) -> SQL {
        like("LOWER(\(column))", "%" + escapeLike(term) + "%")
    }

    private static func like(_ field: SQL, _ pattern: String) -> SQL {
        "\(field) LIKE \(pattern.lowercased()) ESCAPE '\\'"
    }

    private static func escapeLike(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    static func boolean(_ op: BooleanOp, _ column: SQL) -> SQL {
        switch op {
        case .isTrue: "\(column) = 1"
        case .isFalse: "\(column) = 0"
        }
    }

    static func numeric(_ op: NumericOp<Float>, _ column: SQL) -> SQL {
        switch op {
        case .isEqualTo(let v): "\(column) = \(Double(v))"
        case .isNotEqualTo(let v): "\(column) <> \(Double(v))"
        case .greaterThan(let v): "\(column) > \(Double(v))"
        case .lessThan(let v): "\(column) < \(Double(v))"
        }
    }

    static func numeric(_ op: NumericNullableOp<Int>, _ column: SQL) -> SQL {
        switch op {
        case .isEqualTo(let v): "\(column) = \(v)"
        case .isNotEqualTo(let v): "(\(column) <> \(v) OR \(column) IS NULL)"
        case .greaterThan(let v): "\(column) > \(v)"
        case .lessThan(let v): "\(column) < \(v)"
        case .isNull: "\(column) IS NULL"
        case .isNotNull: "\(column) IS NOT NULL"
        }
    }

    /// Dates are ISO `yyyy-MM-dd` text, so they compare lexicographically (UTC calendar day, like Kotlin).
    static func date(_ op: DateOp, _ column: SQL, now: Date = Date()) -> SQL {
        switch op {
        case .after(let date): "\(column) > \(isoDay(date))"
        case .before(let date): "\(column) < \(isoDay(date))"
        case .isInTheLast(let duration): "\(column) > \(isoDay(now.addingTimeInterval(-wholeDays(duration))))"
        case .isNotInTheLast(let duration): "\(column) < \(isoDay(now.addingTimeInterval(-wholeDays(duration))))"
        case .isNull: "\(column) IS NULL"
        case .isNotNull: "\(column) IS NOT NULL"
        }
    }

    private static func wholeDays(_ duration: KomgaDuration) -> TimeInterval {
        TimeInterval((duration.seconds / 86_400) * 86_400)
    }

    static func isoDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return KomgaLocalDate(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1).description
    }

    /// `id IN (subquery)` / `NOT IN` for the child-table conditions (tags, genres, authors, …).
    static func membership(_ id: SQL, _ subquery: SQL, negated: Bool) -> SQL {
        negated ? "\(id) NOT IN (\(subquery))" : "\(id) IN (\(subquery))"
    }

    /// `EqualityNullableOp<String>` over a child table: `is` / `isNot` compare case-insensitively,
    /// `isNull` = no row, `isNotNull` = at least one row.
    static func childValue(
        _ op: EqualityNullableOp<String>, id: SQL, select: (String?) -> SQL
    ) -> SQL {
        switch op {
        case .isEqualTo(let v): membership(id, select(v), negated: false)
        case .isNotEqualTo(let v): membership(id, select(v), negated: true)
        case .isNull: membership(id, select(nil), negated: true)
        case .isNotNull: membership(id, select(nil), negated: false)
        }
    }

    /// `AuthorMatch` over an author child table.
    static func author(_ op: EqualityOp<AuthorMatch>, id: SQL, table: String, key: String) -> SQL {
        let (match, negated): (AuthorMatch, Bool) =
            switch op {
            case .isEqualTo(let m): (m, false)
            case .isNotEqualTo(let m): (m, true)
            }
        guard match.name != nil || match.role != nil else { return alwaysTrue }
        var filters: [SQL] = []
        if let name = match.name { filters.append("LOWER(name) = \(name.lowercased())") }
        if let role = match.role { filters.append("LOWER(role) = \(role.lowercased())") }
        let subquery: SQL = "SELECT \(identifier: key) FROM \(identifier: table) WHERE \(and(filters))"
        return membership(id, subquery, negated: negated)
    }

    /// `KomgaSort` → `ORDER BY`, ignoring unknown properties (Kotlin `toSortField`), plus a stable tie-breaker.
    static func orderBy(_ sort: KomgaSort, fields: [String: SQL], tieBreaker: SQL) -> (sql: SQL, sorted: Bool) {
        let terms: [SQL] = sort.orders.compactMap { order in
            guard let field = fields[order.property] else { return nil }
            return field + (order.direction == .asc ? " ASC" : " DESC")
        }
        return ("ORDER BY " + (terms + [tieBreaker]).joined(separator: ", "), !terms.isEmpty)
    }

    /// `LIMIT/OFFSET` + the normalized request used to build the `Page` (size defaults to 20 when paged).
    static func paging(_ request: KomgaPageRequest) -> (sql: SQL, request: KomgaPageRequest) {
        if request.unpaged == true { return ("", request) }
        var normalized = request
        let size = request.size ?? 20
        normalized.size = size
        normalized.pageIndex = request.pageIndex ?? 0
        return ("LIMIT \(size) OFFSET \((request.pageIndex ?? 0) * size)", normalized)
    }

    /// Libraries visible to `userId`: the root user sees everything, others only their server's libraries.
    static func libraryScope(_ column: SQL, userId: KomgaUserId, rootUserId: KomgaUserId) -> SQL {
        guard userId != rootUserId else { return alwaysTrue }
        return """
            \(column) IN (SELECT l.id FROM LIBRARY l JOIN USER u ON u.server_id = l.server_id \
            WHERE u.id = \(userId.rawValue))
            """
    }
}
