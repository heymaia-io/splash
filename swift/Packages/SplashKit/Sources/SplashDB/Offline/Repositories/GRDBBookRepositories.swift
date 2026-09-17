import Foundation
import GRDB
import SplashOffline
import KomgaAPI

/// Port of `ExposedOfflineBookRepository`.
struct GRDBBookRepository: OfflineBookRepository {
    let db: Database

    func save(_ book: OfflineBook) throws {
        try OfflineBookRecord(
            id: book.id.rawValue, seriesId: book.seriesId.rawValue, libraryId: book.libraryId.rawValue,
            name: book.name, url: book.url, fileSize: book.sizeBytes, number: book.number, fileHash: book.fileHash,
            deleted: book.deleted, oneshot: book.oneshot, createdDate: book.created,
            lastModifiedDate: book.lastModified, remoteFileModifiedDate: book.remoteFileLastModified,
            localFileModifiedDate: book.localFileLastModified, remoteUnavailable: book.remoteUnavailable,
            fileDownloadPath: book.fileDownloadPath
        ).upsert(db)
    }

    func find(_ id: KomgaBookId) throws -> OfflineBook? {
        try OfflineBookRecord.fetchOne(db, key: id.rawValue).map(Self.model)
    }

    func findIn(_ ids: [KomgaBookId]) throws -> [OfflineBook] {
        try OfflineBookRecord.fetchAll(db, keys: ids.map(\.rawValue)).map(Self.model)
    }

    func findAll() throws -> [OfflineBook] {
        try OfflineBookRecord.fetchAll(db).map(Self.model)
    }

    func findFirstIdInSeries(_ seriesId: KomgaSeriesId) throws -> KomgaBookId? {
        try firstId(seriesId, order: "ASC", unreadFor: nil)
    }

    func findLastIdInSeries(_ seriesId: KomgaSeriesId) throws -> KomgaBookId? {
        try firstId(seriesId, order: "DESC", unreadFor: nil)
    }

    func findFirstUnreadIdInSeries(_ seriesId: KomgaSeriesId, userId: KomgaUserId) throws -> KomgaBookId? {
        try firstId(seriesId, order: "ASC", unreadFor: userId)
    }

    private func firstId(_ seriesId: KomgaSeriesId, order: String, unreadFor userId: KomgaUserId?) throws
        -> KomgaBookId?
    {
        var sql: SQL = """
            SELECT b.id FROM BOOK b
            LEFT JOIN BOOK_METADATA bm ON bm.book_id = b.id
            LEFT JOIN READ_PROGRESS rp ON rp.book_id = b.id AND rp.user_id = \(userId?.rawValue)
            WHERE b.series_id = \(seriesId.rawValue)
            """
        if userId != nil { sql += " AND (rp.completed IS NULL OR rp.completed = 0)" }
        sql += " ORDER BY bm.number_sort \(sql: order), b.id \(sql: order) LIMIT 1"
        return try String.fetchOne(db, SQLRequest(literal: sql)).map(KomgaBookId.init)
    }

    func findAllBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws -> [OfflineBook] {
        try OfflineBookRecord.filter(seriesIds.map(\.rawValue).contains(Column("series_id"))).fetchAll(db)
            .map(Self.model)
    }

    func findAllIdsBySeriesId(_ seriesId: KomgaSeriesId) throws -> [KomgaBookId] {
        try String.fetchAll(db, SQLRequest(literal: "SELECT id FROM BOOK WHERE series_id = \(seriesId.rawValue)"))
            .map(KomgaBookId.init)
    }

    func findAllIdsByLibraryId(_ libraryId: KomgaLibraryId) throws -> [KomgaBookId] {
        try String.fetchAll(db, SQLRequest(literal: "SELECT id FROM BOOK WHERE library_id = \(libraryId.rawValue)"))
            .map(KomgaBookId.init)
    }

    func findAllNotDeleted(_ seriesId: KomgaSeriesId) throws -> [OfflineBook] {
        try OfflineBookRecord
            .filter(Column("series_id") == seriesId.rawValue && Column("remote_unavailable") == false)
            .fetchAll(db).map(Self.model)
    }

    func delete(_ ids: [KomgaBookId]) throws {
        _ = try OfflineBookRecord.deleteAll(db, keys: ids.map(\.rawValue))
    }

    static func model(_ r: OfflineBookRecord) -> OfflineBook {
        OfflineBook(
            id: KomgaBookId(r.id), seriesId: KomgaSeriesId(r.seriesId), libraryId: KomgaLibraryId(r.libraryId),
            name: r.name, number: r.number, deleted: r.deleted, fileHash: r.fileHash, oneshot: r.oneshot, url: r.url,
            sizeBytes: r.fileSize, created: r.createdDate, lastModified: r.lastModifiedDate,
            remoteFileLastModified: r.remoteFileModifiedDate, localFileLastModified: r.localFileModifiedDate,
            remoteUnavailable: r.remoteUnavailable, fileDownloadPath: r.fileDownloadPath)
    }
}

/// Port of `ExposedOfflineBookMetadataRepository` (authors, tags and links in child tables).
struct GRDBBookMetadataRepository: OfflineBookMetadataRepository {
    let db: Database

    func save(_ offline: OfflineBookMetadata) throws {
        let m = offline.metadata
        let id = offline.bookId.rawValue
        try OfflineBookMetadataRecord(
            bookId: id, number: m.number, numberLock: m.numberLock, numberSort: m.numberSort,
            numberSortLock: m.numberSortLock, releaseDate: m.releaseDate?.description,
            releaseDateLock: m.releaseDateLock, summary: m.summary, summaryLock: m.summaryLock, title: m.title,
            titleLock: m.titleLock, authorsLock: m.authorsLock, tagsLock: m.tagsLock, isbn: m.isbn,
            isbnLock: m.isbnLock, linksLock: m.linksLock, createdDate: m.created, lastModifiedDate: m.lastModified
        ).upsert(db)
        try deleteChildren([id])
        for author in m.authors {
            try db.execute(literal: """
                INSERT OR IGNORE INTO BOOK_METADATA_AUTHOR (book_id, name, role) VALUES (\(id), \(author.name), \(author.role))
                """)
        }
        for tag in Set(m.tags) {
            try db.execute(literal: "INSERT INTO BOOK_METADATA_TAG (book_id, tag) VALUES (\(id), \(tag))")
        }
        for link in m.links {
            try db.execute(literal: """
                INSERT OR IGNORE INTO BOOK_METADATA_LINK (book_id, label, url) VALUES (\(id), \(link.label), \(link.url))
                """)
        }
    }

    func findAllByIds(_ bookIds: [KomgaBookId]) throws -> [OfflineBookMetadata] {
        let records = try OfflineBookMetadataRecord.fetchAll(db, keys: bookIds.map(\.rawValue))
        let children = try BookMetadataChildren.load(db, bookIds: records.map(\.bookId))
        return records.map { OfflineBookMetadata(bookId: KomgaBookId($0.bookId), metadata: children.metadata(for: $0)) }
    }

    func delete(_ bookIds: [KomgaBookId]) throws {
        let ids = bookIds.map(\.rawValue)
        try deleteChildren(ids)
        _ = try OfflineBookMetadataRecord.deleteAll(db, keys: ids)
    }

    private func deleteChildren(_ ids: [String]) throws {
        for table in ["BOOK_METADATA_AUTHOR", "BOOK_METADATA_TAG", "BOOK_METADATA_LINK"] {
            try db.execute(literal: "DELETE FROM \(identifier: table) WHERE book_id IN \(ids)")
        }
    }
}

/// Batch loader of the book metadata child tables (shared with the DTO repository).
struct BookMetadataChildren {
    var authors: [String: [(String, String)]]
    var tags: [String: [String]]
    var links: [String: [(String, String)]]

    static func load(_ db: Database, bookIds ids: [String]) throws -> BookMetadataChildren {
        BookMetadataChildren(
            authors: try GroupedRows.pairs(
                db, "SELECT book_id, name, role FROM BOOK_METADATA_AUTHOR WHERE book_id IN \(ids) ORDER BY rowid"),
            tags: try GroupedRows.strings(
                db, "SELECT book_id, tag FROM BOOK_METADATA_TAG WHERE book_id IN \(ids) ORDER BY tag"),
            links: try GroupedRows.pairs(
                db, "SELECT book_id, label, url FROM BOOK_METADATA_LINK WHERE book_id IN \(ids) ORDER BY rowid"))
    }

    func metadata(for r: OfflineBookMetadataRecord) -> KomgaBookMetadata {
        KomgaBookMetadata(
            title: r.title, summary: r.summary, number: r.number, numberSort: r.numberSort,
            releaseDate: r.releaseDate.flatMap(KomgaLocalDate.init),
            authors: (authors[r.bookId] ?? []).map { KomgaAuthor(name: $0.0, role: $0.1) },
            tags: tags[r.bookId] ?? [], isbn: r.isbn,
            links: (links[r.bookId] ?? []).map { KomgaWebLink(label: $0.0, url: $0.1) },
            titleLock: r.titleLock, summaryLock: r.summaryLock, numberLock: r.numberLock,
            numberSortLock: r.numberSortLock, releaseDateLock: r.releaseDateLock, authorsLock: r.authorsLock,
            tagsLock: r.tagsLock, isbnLock: r.isbnLock, linksLock: r.linksLock, created: r.createdDate,
            lastModified: r.lastModifiedDate)
    }
}

/// Port of `ExposedOfflineThumbnailBookRepository`.
struct GRDBThumbnailBookRepository: OfflineThumbnailBookRepository {
    let db: Database

    func save(_ t: OfflineThumbnailBook) throws {
        try OfflineThumbnailBookRecord(
            id: t.id.rawValue, bookId: t.bookId.rawValue, thumbnail: t.thumbnail, url: t.url, type: t.type.rawValue,
            selected: t.selected, mediaType: t.mediaType, fileSize: t.fileSize, width: t.width, height: t.height
        ).upsert(db)
    }

    func find(_ id: KomgaThumbnailId) throws -> OfflineThumbnailBook? {
        try OfflineThumbnailBookRecord.fetchOne(db, key: id.rawValue).map(Self.model)
    }

    func findSelectedByBookId(_ bookId: KomgaBookId) throws -> OfflineThumbnailBook? {
        try OfflineThumbnailBookRecord
            .filter(Column("book_id") == bookId.rawValue && Column("selected") == true)
            .fetchOne(db).map(Self.model)
    }

    func findAllByBookId(_ bookId: KomgaBookId) throws -> [OfflineThumbnailBook] {
        try OfflineThumbnailBookRecord.filter(Column("book_id") == bookId.rawValue).fetchAll(db).map(Self.model)
    }

    func deleteByBookIds(_ bookIds: [KomgaBookId]) throws {
        _ = try OfflineThumbnailBookRecord.filter(bookIds.map(\.rawValue).contains(Column("book_id"))).deleteAll(db)
    }

    private static func model(_ r: OfflineThumbnailBookRecord) -> OfflineThumbnailBook {
        OfflineThumbnailBook(
            id: KomgaThumbnailId(r.id), bookId: KomgaBookId(r.bookId), type: .init(rawValue: r.type) ?? .generated,
            selected: r.selected, mediaType: r.mediaType, fileSize: r.fileSize, width: r.width, height: r.height,
            url: r.url, thumbnail: r.thumbnail)
    }
}

/// Port of `ExposedMediaRepository` (pages are stored 0-based in `MEDIA_PAGE`, `extension` as JSON).
struct GRDBMediaRepository: OfflineMediaRepository {
    let db: Database

    func save(_ media: OfflineMedia) throws {
        let id = media.bookId.rawValue
        try OfflineMediaRecord(
            bookId: id, status: media.status.rawValue, mediaType: media.mediaType,
            mediaProfile: media.mediaProfile?.rawValue, pageCount: media.pageCount, comment: media.comment,
            epubDivinaCompatible: media.epubDivinaCompatible, epubIsKepub: media.epubIsKepub,
            extension: try media.extension.map(OfflineJSON.encode)
        ).upsert(db)
        try db.execute(literal: "DELETE FROM MEDIA_PAGE WHERE book_id = \(id)")
        for (index, page) in media.pages.enumerated() {
            try OfflineMediaPageRecord(
                bookId: id, number: index, fileName: page.fileName, mediaType: page.mediaType, width: page.width,
                height: page.height, fileSize: page.fileSize
            ).insert(db)
        }
    }

    func findAll(_ ids: [KomgaBookId]) throws -> [OfflineMedia] {
        let keys = ids.map(\.rawValue)
        let records = try OfflineMediaRecord.fetchAll(db, keys: keys)
        var pages: [String: [OfflineBookPage]] = [:]
        for page in try OfflineMediaPageRecord.filter(keys.contains(Column("book_id")))
            .order(Column("book_id"), Column("number")).fetchAll(db)
        {
            pages[page.bookId, default: []].append(
                OfflineBookPage(
                    bookId: KomgaBookId(page.bookId), fileName: page.fileName, mediaType: page.mediaType,
                    width: page.width, height: page.height, fileSize: page.fileSize))
        }
        return records.map { r in
            OfflineMedia(
                bookId: KomgaBookId(r.bookId), status: KomgaMediaStatus(rawValue: r.status) ?? .unknown,
                mediaType: r.mediaType, mediaProfile: r.mediaProfile.flatMap(MediaProfile.init(rawValue:)),
                comment: r.comment ?? "", epubDivinaCompatible: r.epubDivinaCompatible, epubIsKepub: r.epubIsKepub,
                pageCount: r.pageCount, pages: pages[r.bookId] ?? [],
                extension: OfflineJSON.decode(MediaExtension.self, from: r.extension))
        }
    }

    func delete(_ bookIds: [KomgaBookId]) throws {
        let ids = bookIds.map(\.rawValue)
        try db.execute(literal: "DELETE FROM MEDIA_PAGE WHERE book_id IN \(ids)")
        _ = try OfflineMediaRecord.deleteAll(db, keys: ids)
    }
}

/// Port of `ExposedLogJournalRepository`.
struct GRDBLogJournalRepository: LogJournalRepository {
    let db: Database

    func save(_ entry: OfflineLogEntry) throws {
        try db.execute(literal: """
            INSERT INTO LOG_JOURNAL (id, message, type, timestamp)
            VALUES (\(entry.id.uuidString.lowercased()), \(entry.message), \(entry.type.rawValue), \(entry.timestamp))
            """)
    }

    func findAll(type: OfflineLogEntry.EntryType?, limit: Int, offset: Int) throws -> Page<OfflineLogEntry> {
        let filter: SQL = type.map { "WHERE type = \($0.rawValue)" } ?? ""
        let total = try Int.fetchOne(db, SQLRequest(literal: "SELECT COUNT(*) FROM LOG_JOURNAL \(filter)")) ?? 0
        let rows = try Row.fetchAll(
            db,
            SQLRequest(literal: """
                SELECT * FROM LOG_JOURNAL \(filter) ORDER BY timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """))
        let entries = rows.map { row in
            OfflineLogEntry(
                id: UUID(uuidString: row["id"]) ?? UUID(), message: row["message"],
                type: OfflineLogEntry.EntryType(rawValue: row["type"]) ?? .info, timestamp: row["timestamp"])
        }
        let pageIndex = limit > 0 ? offset / limit : 0
        return Page.page(
            content: entries, request: KomgaPageRequest(pageIndex: pageIndex, size: limit, sort: .unsorted),
            total: total)
    }

    func deleteAll() throws {
        try db.execute(sql: "DELETE FROM LOG_JOURNAL")
    }
}

/// [NUEVO] `BOOK_DOWNLOAD` repository.
struct GRDBBookDownloadRepository: BookDownloadRepository {
    let db: Database

    func save(_ d: BookDownload) throws {
        try db.execute(literal: """
            INSERT INTO BOOK_DOWNLOAD (book_id, status, total_bytes, completed_bytes, error, book_title, series_id,
                                       created_date, last_modified_date)
            VALUES (\(d.bookId.rawValue), \(d.status.rawValue), \(d.totalBytes), \(d.completedBytes), \(d.error),
                    \(d.bookTitle), \(d.seriesId?.rawValue), \(d.createdDate), \(d.lastModifiedDate))
            ON CONFLICT (book_id) DO UPDATE SET
                status = excluded.status, total_bytes = excluded.total_bytes,
                completed_bytes = excluded.completed_bytes, error = excluded.error,
                book_title = COALESCE(excluded.book_title, book_title),
                series_id = COALESCE(excluded.series_id, series_id),
                last_modified_date = excluded.last_modified_date
            """)
    }

    func find(_ bookId: KomgaBookId) throws -> BookDownload? {
        try Row.fetchOne(db, SQLRequest(literal: "SELECT * FROM BOOK_DOWNLOAD WHERE book_id = \(bookId.rawValue)"))
            .map(Self.model)
    }

    func findAll() throws -> [BookDownload] {
        try Row.fetchAll(db, sql: "SELECT * FROM BOOK_DOWNLOAD ORDER BY created_date DESC, book_id").map(Self.model)
    }

    func delete(_ bookIds: [KomgaBookId]) throws {
        try db.execute(literal: "DELETE FROM BOOK_DOWNLOAD WHERE book_id IN \(bookIds.map(\.rawValue))")
    }

    private static func model(_ row: Row) -> BookDownload {
        BookDownload(
            bookId: KomgaBookId(row["book_id"] as String),
            status: BookDownload.Status(rawValue: row["status"]) ?? .failed,
            totalBytes: row["total_bytes"], completedBytes: row["completed_bytes"], error: row["error"],
            bookTitle: row["book_title"], seriesId: (row["series_id"] as String?).map(KomgaSeriesId.init),
            createdDate: row["created_date"], lastModifiedDate: row["last_modified_date"])
    }
}
