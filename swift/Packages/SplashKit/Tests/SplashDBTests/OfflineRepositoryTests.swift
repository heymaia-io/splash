import Foundation
import GRDB
import SplashOffline
import KomgaAPI
import Testing

@testable import SplashDB

/// Round-trips of the GRDB implementations of the offline repository protocols.
@Suite struct OfflineRepositoryTests {
    private func makeStore() throws -> (SplashDatabase, GRDBOfflineDataStore) {
        let database = try SplashDatabase.inMemory()
        return (database, GRDBOfflineDataStore(database: database))
    }

    private static let server = OfflineMediaServer(id: "server-1", url: "https://komga.example")
    private static let library = KomgaLibrary(
        id: "library-1", name: "Comics", root: "/data", scanInterval: .daily,
        scanDirectoryExclusions: ["#recycle", "@eaDir"], seriesCover: .firstUnreadOrLast, oneshotsDirectory: "_one")

    private static func seedHierarchy(_ repos: any OfflineRepositories) throws {
        try repos.mediaServers.save(server)
        try repos.libraries.save(library.toOfflineLibrary(serverId: server.id))
        try repos.series.save(
            OfflineSeries(
                id: "series-1", libraryId: "library-1", name: "Series", url: "/data/Series", oneshot: false,
                bookCount: 2, deleted: false, created: fixedDate, lastModified: fixedDate, fileLastModified: fixedDate))
    }

    private static func book(_ id: String, path: String = "a/b.cbz") -> OfflineBook {
        OfflineBook(
            id: KomgaBookId(id), seriesId: "series-1", libraryId: "library-1", name: "Book \(id)", number: 1,
            deleted: false, fileHash: "hash", oneshot: false, url: "/data/Series/\(id).cbz", sizeBytes: 42,
            created: fixedDate, lastModified: fixedDate, remoteFileLastModified: fixedDate,
            localFileLastModified: fixedDate.addingTimeInterval(5), remoteUnavailable: false, fileDownloadPath: path)
    }

    @Test func serverLibraryAndUserRoundTrip() async throws {
        let (_, store) = try makeStore()
        let user = OfflineUser(
            id: "user-1", serverId: "server-1", email: "u@example.org", roles: ["ADMIN", "USER"],
            sharedAllLibraries: false, sharedLibrariesIds: ["library-1", "missing-library"],
            labelsAllow: ["kids"], labelsExclude: ["adult"],
            ageRestriction: KomgaAgeRestriction(age: 12, restriction: .allowOnly))
        try await store.write { repos in
            try Self.seedHierarchy(repos)
            try repos.users.save(user)
            try repos.users.save(user)  // re-save replaces the child rows
        }
        #expect(try await store.read { try $0.mediaServers.findByUrl("https://komga.example") } == Self.server)
        #expect(try await store.read { try $0.mediaServers.findByUserId("user-1") } == Self.server)
        #expect(try await store.read { try $0.mediaServers.findByUserId(OfflineUser.root) } == nil)
        #expect(try await store.read { try $0.libraries.get("library-1").library } == Self.library)
        let serverLibraries = try await store.read { try $0.libraries.findAllByMediaServer("server-1") }
        #expect(serverLibraries.map(\.id) == ["library-1"])

        var expected = user
        expected.sharedLibrariesIds = ["library-1"]  // FK: only libraries that exist offline are kept
        #expect(try await store.read { try $0.users.get("user-1") } == expected)
        #expect(try await store.read { try $0.users.findAllByServer("server-1") }.map(\.id) == ["user-1"])
        let root = try await store.read { try $0.users.get(OfflineUser.root) }
        #expect(root.email == "root" && root.serverId == nil)
        try await store.write { repos in
            try repos.users.delete("user-1")
            try repos.series.delete(["series-1"])
            try repos.libraries.delete("library-1")  // also clears LIBRARY_EXCLUSIONS
        }
        #expect(try await store.read { try $0.users.find("user-1") } == nil)
        #expect(try await store.read { try $0.libraries.findAll() }.isEmpty)
    }

    @Test func seriesMetadataChildrenRoundTrip() async throws {
        let (_, store) = try makeStore()
        let metadata = KomgaSeriesMetadata(
            status: .hiatus, statusLock: true, title: "Series", alternateTitles: [.init(label: "jp", title: "シリーズ")],
            titleSort: "Series, The", summary: "S", readingDirection: .webtoon, publisher: "P", ageRating: 16,
            language: "ja", genres: ["Action", "Drama"], tags: ["tag-a"], totalBookCount: 10,
            sharingLabels: ["family"], links: [.init(label: "site", url: "https://example.org")])
        try await store.write { repos in
            try Self.seedHierarchy(repos)
            try repos.seriesMetadata.save(OfflineSeriesMetadata(seriesId: "series-1", metadata: metadata))
            try repos.bookMetadataAggregations.save(
                OfflineBookMetadataAggregation(
                    seriesId: "series-1", releaseDate: KomgaLocalDate(year: 2001, month: 2, day: 3), summary: "agg",
                    summaryNumber: "1", authors: [.init(name: "A", role: "writer")], tags: ["x"],
                    createdDate: fixedDate))
            try repos.seriesThumbnails.save(
                OfflineThumbnailSeries(
                    id: "thumb-1", seriesId: "series-1", type: .sidecar, selected: true, mediaType: "image/jpeg",
                    fileSize: 3, width: 1, height: 1, thumbnail: Data([1, 2, 3])))
        }
        #expect(try await store.read { try $0.seriesMetadata.find("series-1")?.metadata } == metadata)
        let aggregation = try #require(try await store.read { try $0.bookMetadataAggregations.find("series-1") })
        #expect(aggregation.releaseDate == KomgaLocalDate(year: 2001, month: 2, day: 3))
        #expect(aggregation.authors == [.init(name: "A", role: "writer")] && aggregation.tags == ["x"])
        #expect(aggregation.createdDate == fixedDate)
        let thumbnail = try await store.read { try $0.seriesThumbnails.findSelectedBySeriesId("series-1") }
        #expect(thumbnail?.thumbnail == Data([1, 2, 3]))
        try await store.write { repos in
            try repos.seriesThumbnails.deleteBySeriesIds(["series-1"])
            try repos.bookMetadataAggregations.delete(["series-1"])
            try repos.seriesMetadata.delete(["series-1"])
            try repos.series.delete(["series-1"])
        }
        #expect(try await store.read { try $0.series.find("series-1") } == nil)
        #expect(try await store.read { try $0.seriesMetadata.find("series-1") } == nil)
    }

    @Test func bookMetadataMediaAndProgressRoundTrip() async throws {
        let (database, store) = try makeStore()
        let metadata = KomgaBookMetadata(
            title: "T", summary: "S", number: "1.5", numberSort: 1.5,
            releaseDate: KomgaLocalDate(year: 2020, month: 12, day: 31),
            authors: [.init(name: "W", role: "writer"), .init(name: "P", role: "penciller")], tags: ["t1", "t2"],
            isbn: "978", links: [.init(label: "l", url: "u")], titleLock: true, created: fixedDate,
            lastModified: fixedDate)
        let locator = R2Locator(href: "ch1.xhtml", type: "text/html", locations: R2Location(progression: 0.5))
        let manifest = try KomgaJSON.makeDecoder().decode(
            WPPublication.self, from: Data(#"{"metadata":{"title":"Epub"},"links":[]}"#.utf8))
        let media = OfflineMedia(
            bookId: "book-1", status: .ready, mediaType: "application/epub+zip", mediaProfile: .epub, comment: "",
            epubDivinaCompatible: true, pageCount: 2,
            pages: [
                OfflineBookPage(bookId: "book-1", fileName: "a.jpg", mediaType: "image/jpeg", width: 1, height: 2),
                OfflineBookPage(bookId: "book-1", fileName: "b.jpg", mediaType: "image/jpeg", fileSize: 9),
            ],
            extension: .epub(MediaExtensionEpub(isFixedLayout: true, positions: [locator], manifest: manifest)))
        let progress = OfflineReadProgress(
            bookId: "book-1", userId: OfflineUser.root, page: 1, completed: false, readDate: fixedDate,
            deviceId: "d", deviceName: "n", locator: locator, createdDate: fixedDate,
            lastModifiedDate: fixedDate.addingTimeInterval(30))

        try await store.write { repos in
            try Self.seedHierarchy(repos)
            try repos.books.save(Self.book("book-1"))
            try repos.books.save(Self.book("book-2"))
            try repos.bookMetadata.save(OfflineBookMetadata(bookId: "book-1", metadata: metadata))
            try repos.media.save(media)
            try repos.readProgress.save(progress)
        }
        let expectedBook = Self.book("book-1")
        #expect(try await store.read { try $0.books.get("book-1") } == expectedBook)
        #expect(try await store.read { try $0.bookMetadata.get("book-1").metadata } == metadata)
        #expect(try await store.read { try $0.media.get("book-1") } == media)
        #expect(try await store.read { try $0.readProgress.find(bookId: "book-1", userId: OfflineUser.root) } == progress)
        let byServer = try await store.read {
            try $0.readProgress.findAllByServer(userId: OfflineUser.root, serverId: "server-1")
        }
        #expect(byServer == [progress])
        let modifiedAfter10 = try await store.read {
            try $0.readProgress.findAllModifiedAfter(
                fixedDate.addingTimeInterval(10), userId: OfflineUser.root, serverId: "server-1")
        }
        let modifiedAfter60 = try await store.read {
            try $0.readProgress.findAllModifiedAfter(
                fixedDate.addingTimeInterval(60), userId: OfflineUser.root, serverId: "server-1")
        }
        #expect(modifiedAfter10.count == 1 && modifiedAfter60.isEmpty)
        let firstUnread = try await store.read {
            try $0.books.findFirstUnreadIdInSeries("series-1", userId: OfflineUser.root)
        }
        #expect(firstUnread != nil)
        let counts = try await database.offline.read { db -> [Int] in
            let row = try Row.fetchOne(db, sql: "SELECT read_count, in_progress_count FROM READ_PROGRESS_SERIES")
            return row.map { [$0[0], $0[1]] } ?? []
        }
        #expect(counts == [0, 1])
        try await store.write { repos in
            try repos.readProgress.deleteByBookIds(["book-1"])
            try repos.media.delete(["book-1"])
            try repos.bookMetadata.delete(["book-1"])
            try repos.books.delete(["book-1"])
        }
        #expect(try await store.read { try $0.readProgress.findAllByBookIds(["book-1"], userId: OfflineUser.root) }.isEmpty)
        #expect(try await store.read { try $0.books.findAll() }.map(\.id) == ["book-2"])
        let leftovers = try await database.offline.read { db in
            try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM READ_PROGRESS_SERIES) + (SELECT COUNT(*) FROM MEDIA_PAGE)")
        }
        #expect(leftovers == 0)
    }

    @Test func downloadStateAndLogJournal() async throws {
        let (_, store) = try makeStore()
        try await store.write { repos in
            try repos.downloads.save(BookDownload(bookId: "b1", status: .queued, createdDate: fixedDate))
            try repos.downloads.save(
                BookDownload(
                    bookId: "b1", status: .failed, totalBytes: 10, completedBytes: 3, error: "HTTP 500",
                    bookTitle: "Title", seriesId: "s1", createdDate: fixedDate.addingTimeInterval(99),
                    lastModifiedDate: fixedDate))
            try repos.downloads.save(BookDownload(bookId: "b1", status: .downloading))  // keeps title/series
            try repos.logJournal.save(OfflineLogEntry(message: "one", type: .info, timestamp: fixedDate))
            try repos.logJournal.save(.error("two", OfflineError.notFound("x")))
        }
        let download = try #require(try await store.read { try $0.downloads.find("b1") })
        #expect(download.status == .downloading && download.bookTitle == "Title" && download.seriesId == "s1")
        #expect(download.createdDate == fixedDate)  // insert-only column
        let errors = try await store.read { try $0.logJournal.findAll(type: .error, limit: 10, offset: 0) }
        #expect(errors.totalElements == 1 && errors.content.first?.message.contains("OfflineError") == true)
        let second = try await store.read { try $0.logJournal.findAll(type: nil, limit: 1, offset: 1) }
        #expect(second.content.map(\.message) == ["one"])
        try await store.write { repos in
            try repos.downloads.delete(["b1"])
            try repos.logJournal.deleteAll()
        }
        #expect(try await store.read { try $0.downloads.findAll() }.isEmpty)
    }

    @Test func tasksRepositoryRoundTripsTaskData() async throws {
        let database = try SplashDatabase.inMemory()
        let tasks = GRDBOfflineTasksRepository(database.offline)
        try await tasks.save([
            TaskEntry(task: .downloadBook("b1")),
            TaskEntry(task: .deleteBookFiles("srv/lib/series/b.cbz"), priority: TaskEntry.highPriority),
        ])
        // A row written by a newer/older app version that this build cannot decode is dropped, not stuck.
        try await database.offline.write { db in
            try OfflineTaskRecord(uniqueName: "ScanLibrary_x", priority: 9, task: #"{"type":"ScanLibrary"}"#).insert(db)
        }
        #expect(try await tasks.takeNew()?.task == .deleteBookFiles("srv/lib/series/b.cbz"))
        #expect(try await tasks.deletePending(uniqueName: "DownloadBook_b1"))
        #expect(try await tasks.takeNew() == nil)
        #expect(try await tasks.resetAllRunning() == 1)
        #expect(try await tasks.findAll().map(\.task) == [.deleteBookFiles("srv/lib/series/b.cbz")])
    }

    @Test func settingsRepositoryWrapsSettingsState() async throws {
        let database = try SplashDatabase.inMemory()
        let directory = URL(filePath: "/tmp/komelia-downloads", directoryHint: .isDirectory)
        let settings = try await OfflineSettingsStateRepository.load(
            database: database, defaultDownloadDirectory: directory)
        #expect(settings.userId == OfflineUser.root && !settings.isOfflineModeEnabled)
        #expect(settings.downloadDirectory.path() == directory.path())

        var changes = settings.offlineModeChanges().makeAsyncIterator()
        #expect(await changes.next() == false)
        try await settings.putOfflineMode(true)
        #expect(await changes.next() == true)

        try await settings.putDataSyncDate(fixedDate)
        try await settings.putReadProgressSyncDate(fixedDate)
        let reloaded = try await OfflineSettingsStateRepository.load(
            database: database, defaultDownloadDirectory: URL(filePath: "/ignored"))
        #expect(reloaded.isOfflineModeEnabled && reloaded.dataSyncDate == fixedDate)
        #expect(reloaded.readProgressSyncDate == fixedDate)
        #expect(reloaded.downloadDirectory.path() == directory.path())
    }
}
