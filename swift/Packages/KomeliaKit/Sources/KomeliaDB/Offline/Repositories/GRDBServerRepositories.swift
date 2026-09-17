import Foundation
import GRDB
import KomeliaOffline
import KomgaAPI

/// Port of `ExposedOfflineMediaServerRepository`.
struct GRDBMediaServerRepository: OfflineMediaServerRepository {
    let db: Database

    func save(_ server: OfflineMediaServer) throws {
        try OfflineMediaServerRecord(id: server.id.rawValue, url: server.url).upsert(db)
    }

    func find(_ id: OfflineMediaServerId) throws -> OfflineMediaServer? {
        try OfflineMediaServerRecord.fetchOne(db, key: id.rawValue).map(Self.model)
    }

    func findAll() throws -> [OfflineMediaServer] {
        try OfflineMediaServerRecord.fetchAll(db).map(Self.model)
    }

    func findByUrl(_ url: String) throws -> OfflineMediaServer? {
        try OfflineMediaServerRecord.filter(Column("url") == url).fetchOne(db).map(Self.model)
    }

    func findByUserId(_ userId: KomgaUserId) throws -> OfflineMediaServer? {
        try OfflineMediaServerRecord.fetchOne(
            db,
            SQLRequest(literal: """
                SELECT s.* FROM OFFLINE_MEDIA_SERVER s JOIN USER u ON u.server_id = s.id
                WHERE u.id = \(userId.rawValue)
                """)
        ).map(Self.model)
    }

    func delete(_ id: OfflineMediaServerId) throws {
        _ = try OfflineMediaServerRecord.deleteOne(db, key: id.rawValue)
    }

    private static func model(_ record: OfflineMediaServerRecord) -> OfflineMediaServer {
        OfflineMediaServer(id: OfflineMediaServerId(record.id), url: record.url)
    }
}

/// Port of `ExposedOfflineUserRepository` (roles, shared libraries and labels in child tables).
struct GRDBUserRepository: OfflineUserRepository {
    let db: Database

    func save(_ user: OfflineUser) throws {
        let id = user.id.rawValue
        try OfflineUserRecord(
            id: id, serverId: user.serverId?.rawValue, email: user.email,
            sharedAllLibraries: user.sharedAllLibraries, ageRestriction: user.ageRestriction?.age,
            ageRestrictionAllowOnly: user.ageRestriction?.restriction == .allowOnly
        ).upsert(db)
        try deleteChildren(id)
        for role in user.roles {
            try db.execute(literal: "INSERT INTO USER_ROLE (user_id, role) VALUES (\(id), \(role))")
        }
        // USER_LIBRARY_SHARING has a FK to LIBRARY: only libraries that exist offline can be recorded (Kotlin would
        // fail the whole import for a restricted user).
        for libraryId in user.sharedLibrariesIds {
            try db.execute(literal: """
                INSERT INTO USER_LIBRARY_SHARING (user_id, library_id)
                SELECT \(id), id FROM LIBRARY WHERE id = \(libraryId.rawValue)
                """)
        }
        for (labels, allow) in [(user.labelsAllow, true), (user.labelsExclude, false)] {
            for label in labels {
                try db.execute(literal: """
                    INSERT OR IGNORE INTO USER_SHARING (user_id, label, allow) VALUES (\(id), \(label), \(allow))
                    """)
            }
        }
    }

    func find(_ id: KomgaUserId) throws -> OfflineUser? {
        try models(OfflineUserRecord.fetchAll(db, keys: [id.rawValue])).first
    }

    func findAll() throws -> [OfflineUser] {
        try models(OfflineUserRecord.fetchAll(db))
    }

    func findAllByServer(_ serverId: OfflineMediaServerId) throws -> [OfflineUser] {
        try models(OfflineUserRecord.filter(Column("server_id") == serverId.rawValue).fetchAll(db))
    }

    func delete(_ id: KomgaUserId) throws {
        try deleteChildren(id.rawValue)
        _ = try OfflineUserRecord.deleteOne(db, key: id.rawValue)
    }

    private func deleteChildren(_ id: String) throws {
        try db.execute(literal: "DELETE FROM USER_ROLE WHERE user_id = \(id)")
        try db.execute(literal: "DELETE FROM USER_LIBRARY_SHARING WHERE user_id = \(id)")
        try db.execute(literal: "DELETE FROM USER_SHARING WHERE user_id = \(id)")
    }

    private func models(_ records: [OfflineUserRecord]) throws -> [OfflineUser] {
        guard !records.isEmpty else { return [] }
        let ids = records.map(\.id)
        let roles = try GroupedRows.strings(db, "SELECT user_id, role FROM USER_ROLE WHERE user_id IN \(ids)")
        let libraries = try GroupedRows.strings(
            db, "SELECT user_id, library_id FROM USER_LIBRARY_SHARING WHERE user_id IN \(ids)")
        var allowed: [String: Set<String>] = [:]
        var excluded: [String: Set<String>] = [:]
        for row in try Row.fetchAll(
            db, SQLRequest(literal: "SELECT user_id, label, allow FROM USER_SHARING WHERE user_id IN \(ids)"))
        {
            let userId: String = row["user_id"]
            if row["allow"] as Bool { allowed[userId, default: []].insert(row["label"]) } else {
                excluded[userId, default: []].insert(row["label"])
            }
        }
        return records.map { record in
            let restriction: KomgaAgeRestriction? =
                if let age = record.ageRestriction, let allowOnly = record.ageRestrictionAllowOnly {
                    KomgaAgeRestriction(age: age, restriction: allowOnly ? .allowOnly : .exclude)
                } else { nil }
            return OfflineUser(
                id: KomgaUserId(record.id),
                // The seeded root row has no server; guard against inconsistent rows instead of trapping.
                serverId: record.id == OfflineUser.root.rawValue ? nil : record.serverId.map(OfflineMediaServerId.init),
                email: record.email,
                roles: Set(roles[record.id] ?? []),
                sharedAllLibraries: record.sharedAllLibraries,
                sharedLibrariesIds: Set((libraries[record.id] ?? []).map(KomgaLibraryId.init)),
                labelsAllow: allowed[record.id] ?? [],
                labelsExclude: excluded[record.id] ?? [],
                ageRestriction: restriction)
        }
    }
}

/// Port of `ExposedOfflineLibraryRepository` (+ `LIBRARY_EXCLUSIONS`).
struct GRDBLibraryRepository: OfflineLibraryRepository {
    let db: Database

    func save(_ offline: OfflineLibrary) throws {
        let l = offline.library
        try OfflineLibraryRecord(
            id: l.id.rawValue, serverId: offline.mediaServerId.rawValue, name: l.name, root: l.root,
            importComicInfoBook: l.importComicInfoBook, importComicInfoSeries: l.importComicInfoSeries,
            importComicInfoCollection: l.importComicInfoCollection,
            importComicInfoReadList: l.importComicInfoReadList,
            importComicInfoSeriesAppendVolume: l.importComicInfoSeriesAppendVolume, importEpubBook: l.importEpubBook,
            importEpubSeries: l.importEpubSeries, importMylarSeries: l.importMylarSeries,
            importLocalArtwork: l.importLocalArtwork, importBarcodeIsbn: l.importBarcodeIsbn,
            scanForceModifiedTime: l.scanForceModifiedTime, scanOnStartup: l.scanOnStartup,
            scanInterval: l.scanInterval.rawValue, scanCbx: l.scanCbx, scanPdf: l.scanPdf, scanEpub: l.scanEpub,
            repairExtensions: l.repairExtensions, convertToCbz: l.convertToCbz,
            emptyTrashAfterScan: l.emptyTrashAfterScan, seriesCover: l.seriesCover.rawValue, hashFiles: l.hashFiles,
            hashPages: l.hashPages, hashKoreader: l.hashKoreader, analyzeDimensions: l.analyzeDimensions,
            oneshotsDirectory: l.oneshotsDirectory, unavailable: l.unavailable
        ).upsert(db)
        try db.execute(literal: "DELETE FROM LIBRARY_EXCLUSIONS WHERE library_id = \(l.id.rawValue)")
        for exclusion in Set(l.scanDirectoryExclusions) {
            try db.execute(literal: """
                INSERT INTO LIBRARY_EXCLUSIONS (library_id, exclusion) VALUES (\(l.id.rawValue), \(exclusion))
                """)
        }
    }

    func find(_ id: KomgaLibraryId) throws -> OfflineLibrary? {
        try models(OfflineLibraryRecord.fetchAll(db, keys: [id.rawValue])).first
    }

    func findAll() throws -> [OfflineLibrary] {
        try models(OfflineLibraryRecord.order(Column("name")).fetchAll(db))
    }

    func findAllByMediaServer(_ serverId: OfflineMediaServerId) throws -> [OfflineLibrary] {
        try models(OfflineLibraryRecord.filter(Column("server_id") == serverId.rawValue).order(Column("name")).fetchAll(db))
    }

    func delete(_ id: KomgaLibraryId) throws {
        try db.execute(literal: "DELETE FROM LIBRARY_EXCLUSIONS WHERE library_id = \(id.rawValue)")
        try db.execute(literal: "DELETE FROM USER_LIBRARY_SHARING WHERE library_id = \(id.rawValue)")
        _ = try OfflineLibraryRecord.deleteOne(db, key: id.rawValue)
    }

    private func models(_ records: [OfflineLibraryRecord]) throws -> [OfflineLibrary] {
        guard !records.isEmpty else { return [] }
        let exclusions = try GroupedRows.strings(
            db, "SELECT library_id, exclusion FROM LIBRARY_EXCLUSIONS WHERE library_id IN \(records.map(\.id))")
        return records.map { r in
            OfflineLibrary(
                mediaServerId: OfflineMediaServerId(r.serverId),
                library: KomgaLibrary(
                    id: KomgaLibraryId(r.id), name: r.name, root: r.root,
                    importComicInfoBook: r.importComicInfoBook, importComicInfoSeries: r.importComicInfoSeries,
                    importComicInfoCollection: r.importComicInfoCollection,
                    importComicInfoReadList: r.importComicInfoReadList,
                    importComicInfoSeriesAppendVolume: r.importComicInfoSeriesAppendVolume,
                    importEpubBook: r.importEpubBook, importEpubSeries: r.importEpubSeries,
                    importMylarSeries: r.importMylarSeries, importLocalArtwork: r.importLocalArtwork,
                    importBarcodeIsbn: r.importBarcodeIsbn, scanForceModifiedTime: r.scanForceModifiedTime,
                    scanInterval: ScanInterval(rawValue: r.scanInterval) ?? .every6h, scanOnStartup: r.scanOnStartup,
                    scanCbx: r.scanCbx, scanPdf: r.scanPdf, scanEpub: r.scanEpub,
                    scanDirectoryExclusions: (exclusions[r.id] ?? []).sorted(),
                    repairExtensions: r.repairExtensions, convertToCbz: r.convertToCbz,
                    emptyTrashAfterScan: r.emptyTrashAfterScan,
                    seriesCover: SeriesCover(rawValue: r.seriesCover) ?? .first, hashFiles: r.hashFiles,
                    hashPages: r.hashPages, hashKoreader: r.hashKoreader, analyzeDimensions: r.analyzeDimensions,
                    oneshotsDirectory: r.oneshotsDirectory, unavailable: r.unavailable))
        }
    }
}

/// Child-table loading helpers (the `selectX(ids).groupBy { … }` pattern of the Exposed repositories).
enum GroupedRows {
    /// Rows of (key, value) strings grouped by key, in query order.
    static func strings(_ db: Database, _ sql: SQL) throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for row in try Row.fetchAll(db, SQLRequest(literal: sql)) {
            result[row[0], default: []].append(row[1])
        }
        return result
    }

    /// Rows of (key, a, b) grouped by key.
    static func pairs(_ db: Database, _ sql: SQL) throws -> [String: [(String, String)]] {
        var result: [String: [(String, String)]] = [:]
        for row in try Row.fetchAll(db, SQLRequest(literal: sql)) {
            result[row[0], default: []].append((row[1], row[2]))
        }
        return result
    }
}
