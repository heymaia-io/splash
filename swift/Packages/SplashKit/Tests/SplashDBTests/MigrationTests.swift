import GRDB
import Testing
@testable import SplashDB

@Suite struct MigrationTests {
    private func userTables(_ db: Database) throws -> Set<String> {
        Set(try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
            """))
    }

    @Test func appDatabaseHasExpectedTables() async throws {
        let database = try SplashDatabase.inMemory()
        let tables = try await database.app.read(userTables)
        #expect(tables == ["AppSettings", "ImageReaderSettings", "EpubReaderSettings", "HomeScreenFilters", "Privacy"])
        #expect(tables == AppMigrations.tableNames)
    }

    @Test func offlineDatabaseHasEveryKotlinTable() async throws {
        let database = try SplashDatabase.inMemory()
        let tables = try await database.offline.read(userTables)
        // The 33 CREATE TABLE statements of V1__offline_mode.sql + the iOS-only download state table.
        #expect(OfflineMigrations.tableNames.count == 33)
        #expect(tables == OfflineMigrations.tableNames.union(OfflineMigrations.iosTableNames))

        let indexes = try await database.offline.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL"))
        }
        #expect(indexes == [
            "offline_media_server__url_idx", "tasks__status_idx", "tasks__start_time_idx", "log_journal__level_idx",
            "book_download__status_idx",
        ])
    }

    @Test func offlineDatabaseSeedsRootUserAndCascadesMediaPages() async throws {
        let database = try SplashDatabase.inMemory()
        try await database.offline.read { db in
            let root = try OfflineUserRecord.fetchOne(db, key: OfflineSettings.rootUserId)
            #expect(root == OfflineUserRecord(
                id: "0", serverId: nil, email: "root", sharedAllLibraries: true,
                ageRestriction: nil, ageRestrictionAllowOnly: false))

            let fks = try db.foreignKeys(on: "MEDIA_PAGE")
            #expect(fks.map(\.destinationTable) == ["BOOK"])
            let onDelete = try String.fetchOne(db, sql: "SELECT on_delete FROM pragma_foreign_key_list('MEDIA_PAGE')")
            #expect(onDelete == "CASCADE")
        }
    }

    @Test func migratingTwiceIsANoOp() async throws {
        let temp = try TemporaryDatabase()
        defer { temp.cleanup() }
        _ = try SplashDatabase(directory: temp.directory)
        let applied = try await temp.database.offline.read { db in try AppMigrations.migrator.appliedMigrations(db) }
        #expect(applied.isEmpty)  // offline DB never receives app migrations
        let offlineApplied = try await temp.database.offline.read { db in
            try OfflineMigrations.migrator.appliedMigrations(db)
        }
        #expect(offlineApplied == ["v1_offline_mode", "v2_book_download"])

        let appApplied = try await temp.database.app.read { db in try AppMigrations.migrator.appliedMigrations(db) }
        #expect(appApplied == ["v1_initial", "v2_privacy"])
    }
}
