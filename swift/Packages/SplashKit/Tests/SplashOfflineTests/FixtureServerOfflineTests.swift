import Foundation
import SplashDB
import KomgaAPI
import KomgaRemote
import Testing

@testable import SplashOffline

/// The dockerized Komga fixture (fixtures/komga/setup.sh). Only the synthetic "Fixture Hero" series is downloaded.
enum OfflineFixtureServer {
    static let url = URL(string: ProcessInfo.processInfo.environment["KOMGA_FIXTURE_URL"] ?? "http://localhost:25601")!
    static let email = "admin@fixture.local"
    static let password = "fixture-password"

    static let isAvailable: Bool = {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var ok = false
        var request = URLRequest(url: url.appending(path: "api/v1/claim"))
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return ok
    }()

    static func loggedInApi() async throws -> RemoteKomgaApi {
        let cookies = KomgaCookieStore(serverURL: { url }, persistence: nil)
        let api = RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { url }, cookieStore: cookies))
        _ = try await api.userApi.getMe(username: email, password: password, rememberMe: true)
        return api
    }
}

@Suite("Offline end-to-end against the Komga fixture", .enabled(if: OfflineFixtureServer.isAvailable), .serialized,
       .timeLimit(.minutes(3)))
struct FixtureServerOfflineTests {
    @Test func downloadReadSyncAndDeleteFixtureHero() async throws {
        let remote = try await OfflineFixtureServer.loggedInApi()
        let me = try await remote.userApi.getMe()
        let comics = try #require(try await remote.libraryApi.getLibraries().first { $0.name == "Comics" })
        let hero = try #require(
            try await remote.seriesApi.getSeriesList(
                condition: .allOfSeries(.libraryId(.isEqualTo(comics.id)), .title(.isEqualTo("Fixture Hero")))
            ).content.first)
        let remoteBooks = try await remote.bookApi.getBookList(
            condition: .seriesId(.isEqualTo(hero.id)), pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byNumber(.asc))
        ).content
        #expect(remoteBooks.count == 3)

        // Offline module over an in-memory DB and a temporary download root, default (non-background) session.
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SplashOfflineE2E-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try SplashDatabase.inMemory()
        let settings = try await OfflineSettingsStateRepository.load(database: database, defaultDownloadDirectory: root)
        let module = OfflineModule(
            store: GRDBOfflineDataStore(database: database),
            tasksRepository: GRDBOfflineTasksRepository(database.offline),
            settings: settings,
            remote: { OfflineRemoteContext(api: remote, serverURL: OfflineFixtureServer.url) },
            bookFileRequest: { remote.remoteBookApi.bookFileRequest($0) },
            downloadConfiguration: DownloadManagerConfiguration(
                makeSessionConfiguration: { DownloadManagerConfiguration.withoutCookieHandling(.ephemeral) }))
        defer { module.downloadManager.invalidate() }
        let events = EventRecorder(module.downloads.events())
        await module.start()

        // 1. Download the series: one DownloadSeries task fans out to three DownloadBook tasks.
        try await module.downloads.downloadSeries(hero.id)
        await module.taskProcessor.waitUntilIdle()

        let downloads = try await module.downloads.downloads()
        #expect(downloads.count == 3)
        #expect(downloads.allSatisfy { $0.status == .complete && $0.error == nil })
        #expect(await events.waitFor { $0.filter { if case .bookDownloadCompleted = $0 { true } else { false } }.count == 3 })

        for book in remoteBooks {
            let expected = root.appending(path: "localhost_25601/Comics/Fixture Hero/\(book.name).cbz")
            #expect(FileManager.default.fileExists(atPath: expected.path(percentEncoded: false)), "\(expected.path())")
            #expect(try await module.downloads.localFileURL(for: book.id)?.standardizedFileURL == expected.standardizedFileURL)
            #expect(try FileHasher.xxh3_128Hex(of: expected) == book.fileHash)
        }
        #expect(try await module.downloads.downloadedBytes() == remoteBooks.reduce(0) { $0 + $1.sizeBytes })

        // 2. The offline API serves the downloaded series for the logged-in user.
        try await settings.putUserId(me.id)
        let offline = module.api
        #expect(try await offline.libraryApi.getLibraries().map(\.name) == ["Comics"])
        let offlineSeries = try await offline.seriesApi.getOneSeries(hero.id)
        #expect(offlineSeries.metadata.title == "Fixture Hero")
        let offlineBooks = try await offline.bookApi.getBookList(
            condition: .seriesId(.isEqualTo(hero.id)), pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byNumber(.asc))
        ).content
        #expect(offlineBooks.map(\.id) == remoteBooks.map(\.id))
        #expect(offlineBooks.allSatisfy { $0.downloaded && !$0.isLocalFileOutdated })
        let first = try #require(offlineBooks.first)
        #expect(try await offline.bookApi.getBookPages(first.id).count == 12)
        let page = try await offline.bookApi.getPage(first.id, page: 1)
        #expect(page.starts(with: [0xFF, 0xD8]))  // JPEG straight from the CBZ
        #expect(page == (try await remote.bookApi.getPage(first.id, page: 1)))
        #expect(try await offline.bookApi.getDefaultThumbnail(first.id) != nil)
        #expect(try await offline.seriesApi.getDefaultThumbnail(hero.id) != nil)

        // RemoteKomgaApi merges the offline state into its books.
        let cookies = KomgaCookieStore(serverURL: { OfflineFixtureServer.url }, persistence: nil)
        let merged = RemoteKomgaApi(
            http: KomgaHTTPClient(baseURL: { OfflineFixtureServer.url }, cookieStore: cookies),
            offlineBooks: module.bookStates)
        _ = try await merged.userApi.getMe(
            username: OfflineFixtureServer.email, password: OfflineFixtureServer.password, rememberMe: false)
        #expect(try await merged.bookApi.getOne(first.id).downloaded)

        // 3. Offline progress is pushed on sync (last-write-wins), then removed from the server again.
        let second = offlineBooks[1]
        let originalProgress = try await remote.bookApi.getOne(second.id).readProgress
        try await offline.bookApi.markReadProgress(second.id, request: KomgaBookReadProgressUpdateRequest(page: 3))
        let result = await module.syncManager.sync(user: me, api: remote, force: true)
        #expect(result == SyncManager.Result(progressPushed: true, dataSynced: true))
        let pushed = try await remote.bookApi.getOne(second.id).readProgress
        #expect(pushed?.page == 3 && pushed?.completed == false)
        #expect(settings.dataSyncDate != nil && settings.readProgressSyncDate != nil)
        if let originalProgress {
            try await remote.bookApi.markReadProgress(
                second.id,
                request: originalProgress.completed
                    ? KomgaBookReadProgressUpdateRequest(completed: true)
                    : KomgaBookReadProgressUpdateRequest(page: originalProgress.page))
        } else {
            try await remote.bookApi.deleteReadProgress(second.id)
        }

        // 4. Deleting the series removes rows, files and the emptied folders.
        try await module.downloads.deleteSeries(hero.id)
        await module.taskProcessor.waitUntilIdle()
        await #expect(throws: OfflineError.self) { try await offline.seriesApi.getOneSeries(hero.id) }
        #expect(try await offline.bookApi.getBookList(condition: nil).content.isEmpty)
        #expect(try await module.downloads.downloads().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "localhost_25601").path(percentEncoded: false)))
        #expect(try await module.downloads.downloadedBytes() == 0)
        await module.taskProcessor.stop()
    }

    @Test func failedDownloadIsPersistedAndCanBeCancelled() async throws {
        let remote = try await OfflineFixtureServer.loggedInApi()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SplashOfflineE2E-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try SplashDatabase.inMemory()
        let settings = try await OfflineSettingsStateRepository.load(database: database, defaultDownloadDirectory: root)
        let module = OfflineModule(
            store: GRDBOfflineDataStore(database: database),
            tasksRepository: GRDBOfflineTasksRepository(database.offline), settings: settings,
            remote: { OfflineRemoteContext(api: remote, serverURL: OfflineFixtureServer.url) },
            bookFileRequest: { remote.remoteBookApi.bookFileRequest($0) },
            downloadConfiguration: DownloadManagerConfiguration(
                makeSessionConfiguration: { DownloadManagerConfiguration.withoutCookieHandling(.ephemeral) }))
        defer { module.downloadManager.invalidate() }
        await module.start()

        // Unknown book: the metadata request 404s → FAILED with the error, nothing on disk.
        try await module.downloads.downloadBook("DOESNOTEXIST")
        await module.taskProcessor.waitUntilIdle()
        let failed = try #require(try await module.downloads.downloads().first)
        #expect(failed.status == .failed && failed.error == "HTTP 404")
        #expect(try await module.api.bookApi.getBookList(condition: nil).content.isEmpty)

        // Cancelling a download that is not running removes its row.
        try await module.downloads.cancel("DOESNOTEXIST")
        await module.taskProcessor.waitUntilIdle()
        #expect(try await module.downloads.downloads().isEmpty)
        await module.taskProcessor.stop()
    }
}
