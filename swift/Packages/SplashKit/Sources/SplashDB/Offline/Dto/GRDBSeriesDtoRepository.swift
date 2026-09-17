import Foundation
import GRDB
import SplashOffline
import KomgaAPI

/// Port of `dto/ExposedSeriesDtoRepository.kt`: `KomgaSeries` rebuilt from the offline tables.
/// [NUEVO] Series listings are scoped to the user's server libraries, like the book listings already were.
struct GRDBSeriesDtoRepository: OfflineSeriesDtoRepository {
    let db: Database

    private static let sortFields: [String: SQL] = [
        "metadata.titleSort": "sm.title_sort COLLATE NOCASE",
        "metadata.title": "sm.title COLLATE NOCASE",
        "createdDate": "s.created_date", "created": "s.created_date",
        "lastModifiedDate": "s.last_modified_date", "lastModified": "s.last_modified_date",
        "booksMetadata.releaseDate": "ba.release_date",
        "readDate": "rps.most_recent_read_date",
        "name": "s.name COLLATE NOCASE",
        "booksCount": "s.books_count",
        "random": "RANDOM()",
    ]

    private func joins(_ userId: KomgaUserId) -> SQL {
        """
        FROM SERIES s
        LEFT JOIN SERIES_METADATA sm ON sm.series_id = s.id
        LEFT JOIN BOOK_METADATA_AGGREGATION ba ON ba.series_id = s.id
        LEFT JOIN READ_PROGRESS_SERIES rps ON rps.series_id = s.id AND rps.user_id = \(userId.rawValue)
        """
    }

    func find(seriesId: KomgaSeriesId, userId: KomgaUserId) throws -> KomgaSeries? {
        try fetch(userId: userId, where: "s.id = \(seriesId.rawValue)", suffix: "").first
    }

    func findAll(search: KomgaSeriesSearch, userId: KomgaUserId, pageRequest: KomgaPageRequest) throws
        -> Page<KomgaSeries>
    {
        try findAll(search: search, extra: nil, userId: userId, pageRequest: pageRequest)
    }

    func findAllRecentlyUpdated(search: KomgaSeriesSearch, userId: KomgaUserId, pageRequest: KomgaPageRequest)
        throws -> Page<KomgaSeries>
    {
        var request = pageRequest
        request.sort = KomgaSeriesSort.byLastModifiedDate(.desc)
        return try findAll(
            search: search, extra: "s.created_date <> s.last_modified_date", userId: userId, pageRequest: request)
    }

    private func findAll(search: KomgaSeriesSearch, extra: SQL?, userId: KomgaUserId, pageRequest: KomgaPageRequest)
        throws -> Page<KomgaSeries>
    {
        var filters = [
            SeriesSearchHelper.condition(search.condition),
            SearchSQL.libraryScope("s.library_id", userId: userId, rootUserId: OfflineUser.root),
        ]
        if let extra { filters.append(extra) }
        if let term = search.fullTextSearch, !term.isEmpty { filters.append(SearchSQL.contains("sm.title", term)) }
        let whereClause = SearchSQL.and(filters)
        let total = try Int.fetchOne(
            db, SQLRequest(literal: "SELECT COUNT(DISTINCT s.id) \(joins(userId)) WHERE \(whereClause)")) ?? 0
        let (orderBy, _) = SearchSQL.orderBy(pageRequest.sort, fields: Self.sortFields, tieBreaker: "s.id")
        let (limit, normalized) = SearchSQL.paging(pageRequest)
        let series = try fetch(userId: userId, where: whereClause, suffix: "\(orderBy) \(limit)")
        return Page.page(content: series, request: normalized, total: total)
    }

    // MARK: Row mapping

    private func fetch(userId: KomgaUserId, where whereClause: SQL, suffix: SQL) throws -> [KomgaSeries] {
        let counts = try [
            db.columns(in: "SERIES").count, db.columns(in: "SERIES_METADATA").count,
            db.columns(in: "BOOK_METADATA_AGGREGATION").count,
        ]
        let adapters = splittingRowAdapters(columnCounts: counts)
        let request = SQLRequest<Row>(
            literal: """
                SELECT s.*, sm.*, ba.*, rps.read_count, rps.in_progress_count \(joins(userId))
                WHERE \(whereClause) \(suffix)
                """,
            adapter: ScopeAdapter([
                "series": adapters[0], "metadata": adapters[1], "aggregation": adapters[2], "progress": adapters[3],
            ]))
        let rows = try Row.fetchAll(db, request)
        let ids = rows.compactMap { $0.scopes["series"]?["id"] as String? }
        let children = try SeriesMetadataChildren.load(db, seriesIds: ids)
        let bookTags = try GroupedRows.strings(
            db, "SELECT series_id, tag FROM BOOK_METADATA_AGGREGATION_TAG WHERE series_id IN \(ids) ORDER BY tag")
        let bookAuthors = try GroupedRows.pairs(
            db, "SELECT series_id, name, role FROM BOOK_METADATA_AGGREGATION_AUTHOR WHERE series_id IN \(ids)")
        return try rows.map { row in
            try series(from: row, children: children, bookTags: bookTags, bookAuthors: bookAuthors)
        }
    }

    private func series(
        from row: Row, children: SeriesMetadataChildren, bookTags: [String: [String]],
        bookAuthors: [String: [(String, String)]]
    ) throws -> KomgaSeries {
        guard let seriesRow = row.scopes["series"] else { throw OfflineError.invalidState("Malformed series row") }
        let record = try OfflineSeriesRecord(row: seriesRow)
        let metadata: KomgaSeriesMetadata
        if let metadataRow = row.scopes["metadata"], metadataRow.containsNonNullValue {
            metadata = children.metadata(for: try OfflineSeriesMetadataRecord(row: metadataRow))
        } else {
            metadata = KomgaSeriesMetadata(status: .ongoing, title: record.name, titleSort: record.name)
        }

        let aggregation = row.scopes["aggregation"]
        let hasAggregation = aggregation?.containsNonNullValue ?? false
        let booksMetadata = KomgaSeriesBookMetadata(
            authors: (bookAuthors[record.id] ?? []).map { KomgaAuthor(name: $0.0, role: $0.1) },
            tags: bookTags[record.id] ?? [],
            releaseDate: hasAggregation ? (aggregation?["release_date"] as String?).flatMap(KomgaLocalDate.init) : nil,
            summary: hasAggregation ? aggregation?["summary"] ?? "" : "",
            summaryNumber: hasAggregation ? aggregation?["summary_number"] ?? "" : "",
            created: hasAggregation ? aggregation?["created_date"] ?? record.createdDate : record.createdDate,
            lastModified: hasAggregation
                ? aggregation?["last_modified_date"] ?? record.lastModifiedDate : record.lastModifiedDate)

        let progress = row.scopes["progress"]
        let readCount: Int = progress?["read_count"] ?? 0
        let inProgressCount: Int = progress?["in_progress_count"] ?? 0
        return KomgaSeries(
            id: KomgaSeriesId(record.id), libraryId: KomgaLibraryId(record.libraryId), name: record.name,
            url: record.url, booksCount: record.booksCount, booksReadCount: readCount,
            booksUnreadCount: max(0, record.booksCount - readCount - inProgressCount),
            booksInProgressCount: inProgressCount, metadata: metadata, deleted: record.deleted,
            oneshot: record.oneshot, booksMetadata: booksMetadata, created: record.createdDate,
            lastModified: record.lastModifiedDate, fileLastModified: record.fileLastModifiedDate)
    }
}

/// Port of `dto/ExposedOfflineReferentialRepository.kt` (only the dimensions that exist offline).
struct GRDBReferentialRepository: OfflineReferentialRepository {
    let db: Database

    private func librariesFilter(_ column: SQL, _ libraryIds: [KomgaLibraryId]) -> SQL {
        libraryIds.isEmpty ? SearchSQL.alwaysTrue : "\(column) IN \(libraryIds.map(\.rawValue))"
    }

    func authors(
        search: String?, role: String?, libraryIds: [KomgaLibraryId], seriesId: KomgaSeriesId?,
        pageRequest: KomgaPageRequest
    ) throws -> Page<KomgaAuthor> {
        var filters = [librariesFilter("b.library_id", libraryIds)]
        if let search, !search.isEmpty { filters.append(SearchSQL.contains("a.name", search)) }
        if let role { filters.append("a.role = \(role)") }
        if let seriesId { filters.append("b.series_id = \(seriesId.rawValue)") }
        let base: SQL = """
            SELECT DISTINCT a.name, a.role FROM BOOK_METADATA_AUTHOR a JOIN BOOK b ON b.id = a.book_id
            WHERE \(SearchSQL.and(filters))
            """
        let total = try Int.fetchOne(db, SQLRequest(literal: "SELECT COUNT(*) FROM (\(base))")) ?? 0
        let (limit, normalized) = SearchSQL.paging(pageRequest)
        let authors = try Row.fetchAll(
            db, SQLRequest(literal: "\(base) ORDER BY a.name COLLATE NOCASE, a.role \(limit)")
        ).map { KomgaAuthor(name: $0["name"], role: $0["role"]) }
        return Page.page(content: authors, request: normalized, total: total)
    }

    func authorNames(search: String) throws -> [String] {
        let filter: SQL = search.isEmpty ? SearchSQL.alwaysTrue : SearchSQL.contains("name", search)
        return try strings("SELECT DISTINCT name FROM BOOK_METADATA_AUTHOR WHERE \(filter) ORDER BY name COLLATE NOCASE")
    }

    func authorRoles() throws -> [String] {
        try strings("SELECT DISTINCT role FROM BOOK_METADATA_AUTHOR ORDER BY role")
    }

    func genres(libraryIds: [KomgaLibraryId]) throws -> [String] {
        try strings("""
            SELECT DISTINCT g.genre FROM SERIES_METADATA_GENRE g JOIN SERIES s ON s.id = g.series_id
            WHERE \(librariesFilter("s.library_id", libraryIds)) ORDER BY g.genre COLLATE NOCASE
            """)
    }

    func sharingLabels(libraryIds: [KomgaLibraryId]) throws -> [String] {
        try strings("""
            SELECT DISTINCT l.label FROM SERIES_METADATA_SHARING l JOIN SERIES s ON s.id = l.series_id
            WHERE \(librariesFilter("s.library_id", libraryIds)) ORDER BY l.label COLLATE NOCASE
            """)
    }

    func seriesAndBookTags(libraryIds: [KomgaLibraryId]) throws -> [String] {
        try strings("""
            SELECT tag FROM (
                SELECT t.tag AS tag FROM SERIES_METADATA_TAG t JOIN SERIES s ON s.id = t.series_id
                WHERE \(librariesFilter("s.library_id", libraryIds))
                UNION
                SELECT t.tag AS tag FROM BOOK_METADATA_TAG t JOIN BOOK b ON b.id = t.book_id
                WHERE \(librariesFilter("b.library_id", libraryIds))
            ) ORDER BY tag COLLATE NOCASE
            """)
    }

    func seriesTags(libraryId: KomgaLibraryId?) throws -> [String] {
        try strings("""
            SELECT DISTINCT t.tag FROM SERIES_METADATA_TAG t JOIN SERIES s ON s.id = t.series_id
            WHERE \(librariesFilter("s.library_id", libraryId.map { [$0] } ?? [])) ORDER BY t.tag COLLATE NOCASE
            """)
    }

    func bookTags(seriesId: KomgaSeriesId?, libraryIds: [KomgaLibraryId]) throws -> [String] {
        let seriesFilter: SQL = seriesId.map { "b.series_id = \($0.rawValue)" } ?? SearchSQL.alwaysTrue
        return try strings("""
            SELECT DISTINCT t.tag FROM BOOK_METADATA_TAG t JOIN BOOK b ON b.id = t.book_id
            WHERE \(seriesFilter) AND \(librariesFilter("b.library_id", libraryIds)) ORDER BY t.tag COLLATE NOCASE
            """)
    }

    func languages(libraryIds: [KomgaLibraryId]) throws -> [String] {
        try metadataValues("sm.language", libraryIds)
    }

    func publishers(libraryIds: [KomgaLibraryId]) throws -> [String] {
        try metadataValues("sm.publisher", libraryIds)
    }

    func ageRatings(libraryIds: [KomgaLibraryId]) throws -> [Int?] {
        try Row.fetchAll(
            db,
            SQLRequest(literal: """
                SELECT DISTINCT sm.age_rating FROM SERIES_METADATA sm JOIN SERIES s ON s.id = sm.series_id
                WHERE \(librariesFilter("s.library_id", libraryIds)) ORDER BY sm.age_rating
                """)
        ).map { $0[0] as Int? }
    }

    func seriesReleaseDates(libraryIds: [KomgaLibraryId]) throws -> [KomgaLocalDate] {
        try strings("""
            SELECT DISTINCT ba.release_date FROM BOOK_METADATA_AGGREGATION ba JOIN SERIES s ON s.id = ba.series_id
            WHERE ba.release_date IS NOT NULL AND \(librariesFilter("s.library_id", libraryIds))
            ORDER BY ba.release_date DESC
            """).compactMap(KomgaLocalDate.init)
    }

    private func metadataValues(_ column: SQL, _ libraryIds: [KomgaLibraryId]) throws -> [String] {
        try strings("""
            SELECT DISTINCT \(column) FROM SERIES_METADATA sm JOIN SERIES s ON s.id = sm.series_id
            WHERE \(column) <> '' AND \(librariesFilter("s.library_id", libraryIds)) ORDER BY \(column) COLLATE NOCASE
            """)
    }

    private func strings(_ sql: SQL) throws -> [String] {
        try String.fetchAll(db, SQLRequest(literal: sql))
    }
}
