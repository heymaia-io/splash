import Foundation
import GRDB
import SplashOffline
import KomgaAPI

/// Port of `dto/ExposedOfflineBookDtoRepository.kt`: `KomeliaBook` pages rebuilt from the offline tables.
///
/// Fixes vs Kotlin: the total count was grouped by book id (always 1); `media.mediaType` was filled with the
/// status; the previous sibling used `>` with a descending order; on-deck ignored `libraryIds`;
/// full-text search matched only the *series* title (now book title OR series title).
struct GRDBBookDtoRepository: OfflineBookDtoRepository {
    let db: Database

    private static let sortFields: [String: SQL] = [
        "name": "b.name COLLATE NOCASE",
        "series": "sm.title_sort COLLATE NOCASE",
        "created": "b.created_date", "createdDate": "b.created_date",
        "lastModified": "b.last_modified_date", "lastModifiedDate": "b.last_modified_date",
        "fileSize": "b.file_size", "size": "b.file_size",
        "fileHash": "b.file_hash",
        "url": "b.url",
        "number": "b.number",
        "media.status": "m.status",
        "media.comment": "m.comment",
        "media.mediaType": "m.media_type",
        "media.pagesCount": "m.page_count", "metadata.pagesCount": "m.page_count",
        "metadata.title": "bm.title COLLATE NOCASE",
        "metadata.numberSort": "bm.number_sort",
        "metadata.releaseDate": "bm.release_date",
        "readProgress.lastModified": "rp.last_modified_date",
        "readProgress.readDate": "rp.read_date",
    ]

    private func joins(_ userId: KomgaUserId) -> SQL {
        """
        FROM BOOK b
        LEFT JOIN MEDIA m ON m.book_id = b.id
        LEFT JOIN BOOK_METADATA bm ON bm.book_id = b.id
        LEFT JOIN READ_PROGRESS rp ON rp.book_id = b.id AND rp.user_id = \(userId.rawValue)
        LEFT JOIN SERIES_METADATA sm ON sm.series_id = b.series_id
        """
    }

    private func scope(_ userId: KomgaUserId) -> SQL {
        SearchSQL.libraryScope("b.library_id", userId: userId, rootUserId: OfflineUser.root)
    }

    func findAll(userId: KomgaUserId, search: KomgaBookSearch, pageRequest: KomgaPageRequest) throws
        -> Page<SplashBook>
    {
        var filters = [BookSearchHelper.condition(search.condition), scope(userId)]
        if let term = search.fullTextSearch, !term.isEmpty {
            filters.append(SearchSQL.or([SearchSQL.contains("bm.title", term), SearchSQL.contains("sm.title", term)]))
        }
        let whereClause = SearchSQL.and(filters)
        let total = try Int.fetchOne(
            db, SQLRequest(literal: "SELECT COUNT(DISTINCT b.id) \(joins(userId)) WHERE \(whereClause)")) ?? 0
        let (orderBy, _) = SearchSQL.orderBy(pageRequest.sort, fields: Self.sortFields, tieBreaker: "b.id")
        let (limit, normalized) = SearchSQL.paging(pageRequest)
        let books = try fetch(userId: userId, where: whereClause, suffix: "\(orderBy) \(limit)")
        return Page.page(content: books, request: normalized, total: total)
    }

    func find(bookId: KomgaBookId, userId: KomgaUserId) throws -> SplashBook? {
        try fetch(userId: userId, where: "b.id = \(bookId.rawValue)", suffix: "").first
    }

    func findPreviousInSeries(bookId: KomgaBookId, userId: KomgaUserId) throws -> SplashBook? {
        try sibling(bookId: bookId, userId: userId, next: false)
    }

    func findNextInSeries(bookId: KomgaBookId, userId: KomgaUserId) throws -> SplashBook? {
        try sibling(bookId: bookId, userId: userId, next: true)
    }

    private func sibling(bookId: KomgaBookId, userId: KomgaUserId, next: Bool) throws -> SplashBook? {
        guard
            let row = try Row.fetchOne(
                db,
                SQLRequest(literal: """
                    SELECT b.series_id, bm.number_sort FROM BOOK b LEFT JOIN BOOK_METADATA bm ON bm.book_id = b.id
                    WHERE b.id = \(bookId.rawValue)
                    """))
        else { throw OfflineError.notFound("Book \(bookId)") }
        let seriesId: String = row["series_id"]
        let numberSort: Double = row["number_sort"] ?? 0
        let comparison: SQL = next ? "bm.number_sort > \(numberSort)" : "bm.number_sort < \(numberSort)"
        let order: SQL = next ? "ORDER BY bm.number_sort ASC LIMIT 1" : "ORDER BY bm.number_sort DESC LIMIT 1"
        return try fetch(
            userId: userId, where: "b.series_id = \(seriesId) AND \(comparison) AND \(scope(userId))", suffix: order
        ).first
    }

    /// Series with at least one read and one unread book and nothing in progress, most recently read first; for
    /// each, its first unread book.
    func findAllOnDeck(userId: KomgaUserId, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest) throws
        -> Page<SplashBook>
    {
        var filters = [SearchSQL.libraryScope("s.library_id", userId: userId, rootUserId: OfflineUser.root)]
        if let libraryIds, !libraryIds.isEmpty { filters.append("s.library_id IN \(libraryIds.map(\.rawValue))") }
        let seriesIds = try String.fetchAll(
            db,
            SQLRequest(literal: """
                SELECT s.id FROM SERIES s
                LEFT JOIN BOOK b ON b.series_id = s.id
                LEFT JOIN READ_PROGRESS rp ON rp.book_id = b.id AND rp.user_id = \(userId.rawValue)
                WHERE \(SearchSQL.and(filters))
                GROUP BY s.id
                HAVING SUM(CASE WHEN rp.completed IS NULL THEN 1 ELSE 0 END) >= 1
                   AND SUM(CASE WHEN rp.completed = 1 THEN 1 ELSE 0 END) >= 1
                   AND SUM(CASE WHEN rp.completed = 0 THEN 1 ELSE 0 END) = 0
                ORDER BY MAX(rp.last_modified_date) DESC, s.id
                """))
        let (_, normalized) = SearchSQL.paging(pageRequest)
        let pageIds: ArraySlice<String>
        if normalized.unpaged == true {
            pageIds = seriesIds[...]
        } else {
            let size = normalized.size ?? 20
            let start = min(seriesIds.count, (normalized.pageIndex ?? 0) * size)
            pageIds = seriesIds[start..<min(seriesIds.count, start + size)]
        }
        let books = try pageIds.compactMap { seriesId in
            try fetch(
                userId: userId, where: "b.series_id = \(seriesId) AND rp.completed IS NULL",
                suffix: "ORDER BY bm.number_sort ASC LIMIT 1"
            ).first
        }
        return Page.page(content: books, request: normalized, total: seriesIds.count)
    }

    // MARK: Row mapping

    private func fetch(userId: KomgaUserId, where whereClause: SQL, suffix: SQL) throws -> [SplashBook] {
        let counts = try [
            db.columns(in: "BOOK").count, db.columns(in: "BOOK_METADATA").count, db.columns(in: "MEDIA").count,
            db.columns(in: "READ_PROGRESS").count,
        ]
        let adapters = splittingRowAdapters(columnCounts: counts)
        let request = SQLRequest<Row>(
            literal: """
                SELECT b.*, bm.*, m.*, rp.*, sm.title AS series_title \(joins(userId))
                WHERE \(whereClause) \(suffix)
                """,
            adapter: ScopeAdapter([
                "book": adapters[0], "metadata": adapters[1], "media": adapters[2], "progress": adapters[3],
                "extra": adapters[4],
            ]))
        let rows = try Row.fetchAll(db, request)
        let bookIds = rows.compactMap { $0.scopes["book"]?["id"] as String? }
        let children = try BookMetadataChildren.load(db, bookIds: bookIds)
        return try rows.map { try book(from: $0, children: children) }
    }

    private func book(from row: Row, children: BookMetadataChildren) throws -> SplashBook {
        guard let bookRow = row.scopes["book"] else { throw OfflineError.invalidState("Malformed book row") }
        let record = try OfflineBookRecord(row: bookRow)
        let metadata: KomgaBookMetadata
        if let metadataRow = row.scopes["metadata"], metadataRow.containsNonNullValue {
            metadata = children.metadata(for: try OfflineBookMetadataRecord(row: metadataRow))
        } else {
            metadata = KomgaBookMetadata(
                title: record.name, summary: "", number: String(record.number), numberSort: Float(record.number),
                releaseDate: nil, authors: [], tags: [], isbn: "", links: [], created: record.createdDate,
                lastModified: record.lastModifiedDate)
        }
        let media: Media
        if let mediaRow = row.scopes["media"], mediaRow.containsNonNullValue {
            let m = try OfflineMediaRecord(row: mediaRow)
            media = Media(
                status: KomgaMediaStatus(rawValue: m.status) ?? .unknown, mediaType: m.mediaType,
                pagesCount: m.pageCount, comment: m.comment ?? "", epubDivinaCompatible: m.epubDivinaCompatible,
                epubIsKepub: m.epubIsKepub, mediaProfile: m.mediaProfile.flatMap(MediaProfile.init(rawValue:)))
        } else {
            media = Media(
                status: .unknown, mediaType: nil, pagesCount: 0, comment: "", epubDivinaCompatible: false,
                epubIsKepub: false, mediaProfile: nil)
        }
        var readProgress: ReadProgress?
        if let progressRow = row.scopes["progress"], progressRow["user_id"] as String? != nil {
            let p = try OfflineReadProgressRecord(row: progressRow)
            readProgress = ReadProgress(
                page: p.page, completed: p.completed, readDate: p.readDate ?? p.lastModifiedDate,
                deviceId: p.deviceId, deviceName: p.deviceName, created: p.createdDate,
                lastModified: p.lastModifiedDate)
        }
        let book = KomgaBook(
            id: KomgaBookId(record.id), seriesId: KomgaSeriesId(record.seriesId),
            seriesTitle: row.scopes["extra"]?["series_title"] ?? "", libraryId: KomgaLibraryId(record.libraryId),
            name: record.name, url: record.url, number: record.number, created: record.createdDate,
            lastModified: record.lastModifiedDate, fileLastModified: record.remoteFileModifiedDate,
            sizeBytes: record.fileSize, size: OfflineFormat.mebibytes(record.fileSize), media: media,
            metadata: metadata, readProgress: readProgress, deleted: record.deleted, fileHash: record.fileHash,
            oneshot: record.oneshot)
        return SplashBook(
            book: book, downloaded: true, localFileLastModified: record.localFileModifiedDate,
            remoteFileUnavailable: record.remoteUnavailable)
    }
}
