import Foundation
import GRDB
import KomeliaOffline
import KomgaAPI

/// Port of `ExposedOfflineReadProgressRepository`. Every mutation re-aggregates `READ_PROGRESS_SERIES`.
/// Fix: Kotlin wrote `last_modified_date = created_date` on save, which broke "modified after" sync queries.
struct GRDBReadProgressRepository: OfflineReadProgressRepository {
    let db: Database

    func save(_ progresses: [OfflineReadProgress]) throws {
        guard !progresses.isEmpty else { return }
        for p in progresses {
            let record = OfflineReadProgressRecord(
                bookId: p.bookId.rawValue, userId: p.userId.rawValue, page: p.page, completed: p.completed,
                readDate: p.readDate, deviceId: p.deviceId, deviceName: p.deviceName,
                locator: try p.locator.map(OfflineJSON.encode), createdDate: p.createdDate,
                lastModifiedDate: p.lastModifiedDate)
            try record.upsert(db)
        }
        for (userId, group) in Dictionary(grouping: progresses, by: \.userId) {
            try aggregateSeriesProgress(bookIds: group.map(\.bookId), userId: userId)
        }
    }

    func find(bookId: KomgaBookId, userId: KomgaUserId) throws -> OfflineReadProgress? {
        try OfflineReadProgressRecord
            .filter(Column("book_id") == bookId.rawValue && Column("user_id") == userId.rawValue)
            .fetchOne(db).map(Self.model)
    }

    func findAllByBookIds(_ bookIds: [KomgaBookId], userId: KomgaUserId) throws -> [OfflineReadProgress] {
        try OfflineReadProgressRecord
            .filter(bookIds.map(\.rawValue).contains(Column("book_id")) && Column("user_id") == userId.rawValue)
            .fetchAll(db).map(Self.model)
    }

    func findAllModifiedAfter(_ date: Date, userId: KomgaUserId, serverId: OfflineMediaServerId) throws
        -> [OfflineReadProgress]
    {
        try byServer(userId: userId, serverId: serverId, extra: "AND rp.last_modified_date > \(date)")
    }

    func findAllByServer(userId: KomgaUserId, serverId: OfflineMediaServerId) throws -> [OfflineReadProgress] {
        try byServer(userId: userId, serverId: serverId, extra: "")
    }

    private func byServer(userId: KomgaUserId, serverId: OfflineMediaServerId, extra: SQL) throws
        -> [OfflineReadProgress]
    {
        try OfflineReadProgressRecord.fetchAll(
            db,
            SQLRequest(literal: """
                SELECT rp.* FROM READ_PROGRESS rp
                JOIN BOOK b ON b.id = rp.book_id
                JOIN LIBRARY l ON l.id = b.library_id
                WHERE l.server_id = \(serverId.rawValue) AND rp.user_id = \(userId.rawValue) \(extra)
                """)
        ).map(Self.model)
    }

    func deleteByUserId(_ userId: KomgaUserId) throws {
        try db.execute(literal: "DELETE FROM READ_PROGRESS WHERE user_id = \(userId.rawValue)")
        try db.execute(literal: "DELETE FROM READ_PROGRESS_SERIES WHERE user_id = \(userId.rawValue)")
    }

    func deleteByBookIds(_ bookIds: [KomgaBookId], userId: KomgaUserId) throws {
        try db.execute(literal: """
            DELETE FROM READ_PROGRESS WHERE book_id IN \(bookIds.map(\.rawValue)) AND user_id = \(userId.rawValue)
            """)
        try aggregateSeriesProgress(bookIds: bookIds, userId: userId)
    }

    func deleteBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws {
        try db.execute(literal: "DELETE FROM READ_PROGRESS_SERIES WHERE series_id IN \(seriesIds.map(\.rawValue))")
    }

    func deleteByBookIds(_ bookIds: [KomgaBookId]) throws {
        try db.execute(literal: "DELETE FROM READ_PROGRESS WHERE book_id IN \(bookIds.map(\.rawValue))")
        try aggregateSeriesProgress(bookIds: bookIds, userId: nil)
    }

    /// `aggregateSeriesProgress`: rebuilds the per-series counters of the series owning `bookIds`.
    private func aggregateSeriesProgress(bookIds: [KomgaBookId], userId: KomgaUserId?) throws {
        let seriesIds = try String.fetchAll(
            db, SQLRequest(literal: "SELECT DISTINCT series_id FROM BOOK WHERE id IN \(bookIds.map(\.rawValue))"))
        guard !seriesIds.isEmpty else { return }
        let userFilter: SQL = userId.map { "AND user_id = \($0.rawValue)" } ?? ""
        let progressUserFilter: SQL = userId.map { "AND rp.user_id = \($0.rawValue)" } ?? ""
        try db.execute(literal: "DELETE FROM READ_PROGRESS_SERIES WHERE series_id IN \(seriesIds) \(userFilter)")
        try db.execute(literal: """
            INSERT INTO READ_PROGRESS_SERIES (series_id, user_id, read_count, in_progress_count, most_recent_read_date)
            SELECT b.series_id, rp.user_id,
                   SUM(CASE WHEN rp.completed = 1 THEN 1 ELSE 0 END),
                   SUM(CASE WHEN rp.completed = 0 THEN 1 ELSE 0 END),
                   MAX(rp.read_date)
            FROM BOOK b JOIN READ_PROGRESS rp ON rp.book_id = b.id
            WHERE b.series_id IN \(seriesIds) \(progressUserFilter)
            GROUP BY b.series_id, rp.user_id
            """)
    }

    private static func model(_ r: OfflineReadProgressRecord) -> OfflineReadProgress {
        OfflineReadProgress(
            bookId: KomgaBookId(r.bookId), userId: KomgaUserId(r.userId), page: r.page, completed: r.completed,
            readDate: r.readDate ?? r.lastModifiedDate, deviceId: r.deviceId, deviceName: r.deviceName,
            locator: OfflineJSON.decode(R2Locator.self, from: r.locator), createdDate: r.createdDate,
            lastModifiedDate: r.lastModifiedDate)
    }
}
