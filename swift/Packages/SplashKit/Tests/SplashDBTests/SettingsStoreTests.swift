import Foundation
import SplashCore
import Testing
@testable import SplashDB

@Suite struct SettingsStoreTests {
    @Test func appSettingsRoundTrip() async throws {
        let store = GRDBAppSettingsStore(try SplashDatabase.inMemory().app)
        #expect(try await store.load() == nil)

        try await store.save(AppSettings())
        #expect(try await store.load() == AppSettings())

        var changed = AppSettings()
        changed.username = "reader@example.org"
        changed.serverUrl = "https://komga.example"
        changed.cardWidth = 240
        changed.seriesPageLoadSize = 50
        changed.bookPageLoadSize = 100
        changed.bookListLayout = .list
        changed.appTheme = .light
        changed.lastLibraryId = "lib-1"
        try await store.save(changed)  // upsert: still one row
        #expect(try await store.load() == changed)
    }

    /// `last_library_id` arrived in the v3 migration, so every row written before it reads back as NULL —
    /// which must mean "All Libraries", not a decoding failure.
    @Test func lastLibraryIsOptional() async throws {
        let database = try SplashDatabase.inMemory()
        let store = GRDBAppSettingsStore(database.app)
        var settings = AppSettings()
        settings.lastLibraryId = "lib-1"
        try await store.save(settings)
        #expect(try await store.load()?.lastLibraryId == "lib-1")

        try await database.app.write { db in
            try db.execute(sql: "UPDATE AppSettings SET last_library_id = NULL")
        }
        #expect(try await store.load()?.lastLibraryId == nil)
    }

    @Test func imageReaderSettingsRoundTrip() async throws {
        let database = try SplashDatabase.inMemory()
        let store = GRDBImageReaderSettingsStore(database.app)
        #expect(try await store.load() == nil)

        try await store.save(ImageReaderSettings())
        #expect(try await store.load() == ImageReaderSettings())

        var changed = ImageReaderSettings()
        changed.readerType = .continuous
        changed.stretchToFit = false
        changed.pagedScaleType = .fitWidth
        changed.pagedReadingDirection = .rightToLeft
        changed.pagedPageLayout = .doublePagesNoCover
        changed.continuousReadingDirection = .rightToLeft
        changed.continuousPadding = 0.25
        changed.continuousPageSpacing = 8
        changed.cropBorders = true
        changed.flashOnPageChange = true
        changed.flashDuration = 250
        changed.flashEveryNPages = 3
        changed.flashWith = .whiteAndBlack
        changed.downsamplingKernel = .mitchell
        changed.linearLightDownsampling = true
        changed.upsamplingMode = .bilinear
        changed.loadThumbnailPreviews = false
        changed.volumeKeysNavigation = true
        try await store.save(changed)
        #expect(try await store.load() == changed)

        let bookIds = try await database.app.read { db in
            try String.fetchAll(db, sql: "SELECT book_id FROM ImageReaderSettings")
        }
        #expect(bookIds == ["DEFAULT"])
    }

    @Test func unknownEnumNameIsAnError() async throws {
        let database = try SplashDatabase.inMemory()
        let store = GRDBAppSettingsStore(database.app)
        try await store.save(AppSettings())
        try await database.app.write { db in try db.execute(sql: "UPDATE AppSettings SET app_theme = 'SEPIA'") }
        await #expect(throws: UnknownEnumValue.self) { try await store.load() }
    }

    @Test func worksWithSettingsState() async throws {
        let store = GRDBAppSettingsStore(try SplashDatabase.inMemory().app)
        let state = try await SettingsState.load(from: store, default: AppSettings())
        try await state.set(\.cardWidth, 300)
        #expect(try await store.load()?.cardWidth == 300)
    }

    @Test func offlineSettingsRoundTrip() async throws {
        let database = try SplashDatabase.inMemory()
        let store = GRDBOfflineSettingsStore(database.offline)
        #expect(try await store.load() == nil)

        let defaults = OfflineSettings(downloadDirectory: "/downloads")
        #expect(defaults.userId == "0")
        try await store.save(defaults)
        #expect(try await store.load() == defaults)

        try await database.offline.write { db in
            try OfflineMediaServerRecord(id: "server-1", url: "https://komga.example").insert(db)
            try OfflineUserRecord(id: "user-1", serverId: "server-1", email: "a@b.c", sharedAllLibraries: true)
                .insert(db)
        }
        let changed = OfflineSettings(
            isOfflineModeEnabled: true, downloadDirectory: "/elsewhere", userId: "user-1", serverId: "server-1",
            readProgressSyncDate: fixedDate, dataSyncDate: fixedDate.addingTimeInterval(0.5))
        try await store.save(changed)
        #expect(try await store.load() == changed)
    }

    @Test func offlineSettingsNullUserFallsBackToRoot() async throws {
        let database = try SplashDatabase.inMemory()
        try await database.offline.write { db in
            try db.execute(sql: """
                INSERT INTO SETTINGS (version, is_offline_mode_enabled, user_id, download_directory)
                VALUES (1, 0, NULL, '/d')
                """)
        }
        #expect(try await GRDBOfflineSettingsStore(database.offline).load()?.userId == OfflineSettings.rootUserId)
    }

    struct Filter: Codable, Hashable, Sendable {
        var order: Int
        var label: String
    }

    @Test func homeScreenFiltersRoundTrip() async throws {
        let database = try SplashDatabase.inMemory()
        let store = GRDBHomeScreenFilterStore<Filter>(database.app)
        #expect(try await store.load() == nil)

        let filters = [Filter(order: 0, label: "Keep reading"), Filter(order: 1, label: "On deck")]
        try await store.save(filters)
        #expect(try await store.load() == filters)
        try await store.save([filters[1]])
        #expect(try await store.load() == [filters[1]])

        // Undecodable JSON reads as "no filters" (Kotlin swallows SerializationException).
        try await database.app.write { db in try db.execute(sql: "UPDATE HomeScreenFilters SET filters = '{oops'") }
        #expect(try await store.load() == nil)
    }
}
