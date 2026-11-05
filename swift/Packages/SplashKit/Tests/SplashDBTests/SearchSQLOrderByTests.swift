import GRDB
import Testing
import KomgaAPI
@testable import SplashDB

/// A chained sort ("Pages, then Title") must reach the offline store as `ORDER BY a, b, <id>` in that order,
/// so books of equal length come back alphabetical when browsing offline too.
@Suite struct SearchSQLOrderByTests {
    private static let fields: [String: SQL] = [
        "media.pagesCount": "m.page_count",
        "metadata.title": "bm.title COLLATE NOCASE",
    ]

    /// The `ORDER BY` clause as SQLite receives it. Prepared against minimal tables so it is also proven valid.
    private static func orderBy(_ sort: KomgaSort) throws -> String {
        let queue = try DatabaseQueue()
        return try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE b (id TEXT); CREATE TABLE m (page_count INT); CREATE TABLE bm (title TEXT);
                """)
            let order = SearchSQL.orderBy(sort, fields: fields, tieBreaker: "b.id").sql
            let query: SQL = "SELECT 1 FROM b, m, bm \(order)"
            let sql = try db.makeStatement(literal: query).sql
            let start = try #require(sql.firstRange(of: "ORDER BY")).lowerBound
            return String(sql[start...])
        }
    }

    @Test func chainedOrdersKeepTheirPrecedenceAndEndWithTheTieBreaker() throws {
        let sort = KomgaBooksSort.byPagesCount(.desc).and(KomgaBooksSort.byTitle(.asc))
        #expect(try Self.orderBy(sort) == "ORDER BY m.page_count DESC, bm.title COLLATE NOCASE ASC, b.id")
    }

    @Test func aSingleOrderStillGetsTheTieBreaker() throws {
        #expect(try Self.orderBy(KomgaBooksSort.byPagesCount(.asc)) == "ORDER BY m.page_count ASC, b.id")
    }
}
