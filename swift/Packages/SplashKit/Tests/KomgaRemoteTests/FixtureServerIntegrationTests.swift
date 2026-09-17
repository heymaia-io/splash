import Foundation
import Testing
@testable import KomgaAPI
@testable import KomgaRemote

/// Contract tests against the dockerized Komga fixture (fixtures/komga/setup.sh).
/// Skipped automatically when the server is not running.
enum FixtureServer {
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

    /// Authenticated through the real login flow (Basic + remember-me cookie), like LoginViewModel.
    static func loggedInApi() async throws -> (RemoteKomgaApi, KomgaCookieStore) {
        let cookies = KomgaCookieStore(serverURL: { url }, persistence: nil)
        let http = KomgaHTTPClient(baseURL: { url }, cookieStore: cookies)
        let api = RemoteKomgaApi(http: http)
        _ = try await api.userApi.getMe(username: email, password: password, rememberMe: true)
        return (api, cookies)
    }
}

@Suite("Komga fixture contract", .enabled(if: FixtureServer.isAvailable), .serialized)
struct FixtureServerIntegrationTests {
    @Test func loginPersistsSessionThroughCookies() async throws {
        let (api, cookies) = try await FixtureServer.loggedInApi()
        #expect(cookies.hasRememberMe)
        let me = try await api.userApi.getMe()  // no Authorization header: cookie only
        #expect(me.email == FixtureServer.email)
    }

    @Test func unauthenticatedIs401() async throws {
        let api = RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { FixtureServer.url }))
        await #expect(throws: KomgaAPIError.self) {
            do { _ = try await api.userApi.getMe() } catch {
                #expect(error.isKomgaUnauthorized)
                throw error
            }
        }
    }

    @Test func browseCriticalPath() async throws {
        let (api, _) = try await FixtureServer.loggedInApi()

        let libraries = try await api.libraryApi.getLibraries()
        // Extra personal libraries may be mounted (fixtures/komga/.env), so only assert the synthetic ones.
        #expect(Set(["Comics", "Manga", "Webtoon"]).isSubset(of: Set(libraries.map(\.name))))
        let comics = try #require(libraries.first { $0.name == "Comics" })
        #expect(try await api.libraryApi.getLibrary(comics.id).id == comics.id)

        let series = try await api.seriesApi.getSeriesList(
            condition: .allOfSeries(.libraryId(.isEqualTo(comics.id))),
            pageRequest: KomgaPageRequest(pageIndex: 0, size: 10, sort: KomgaSeriesSort.byTitle(.asc)))
        #expect(series.content.map(\.metadata.title) == ["Fixture Hero", "Second Series", "Standalone Story #1"])

        let hero = try #require(series.content.first)
        let books = try await api.bookApi.getBookList(
            condition: .allOfBooks(.seriesId(.isEqualTo(hero.id)), .deleted(.isFalse)),
            pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byNumber(.asc)))
        #expect(books.content.map(\.metadata.number) == ["1", "2", "3"])
        #expect(books.content.allSatisfy { !$0.downloaded })

        let first = try #require(books.content.first)
        #expect(try await api.bookApi.getOne(first.id).id == first.id)
        #expect(try await api.bookApi.getBookSiblingPrevious(first.id) == nil)
        #expect(try await api.bookApi.getBookSiblingNext(first.id)?.id == books.content[1].id)

        let pages = try await api.bookApi.getBookPages(first.id)
        #expect(pages.count == 12)
        let pageData = try await api.bookApi.getPage(first.id, page: 1)
        #expect(pageData.starts(with: [0xFF, 0xD8]))  // JPEG
        #expect(!(try await api.bookApi.getPageThumbnail(first.id, page: 1)).isEmpty)
        #expect(try await api.bookApi.getDefaultThumbnail(first.id) != nil)
        #expect(try await api.seriesApi.getDefaultThumbnail(hero.id) != nil)
        #expect(try await api.bookApi.getDefaultThumbnail("DOESNOTEXIST") == nil)

        #expect(try await api.bookApi.getLatestBooks().totalElements >= 12)
        _ = try await api.bookApi.getBooksOnDeck(libraryIds: [comics.id])
        #expect(try await api.seriesApi.getNewSeries(libraryIds: [comics.id]).totalElements == 3)
        _ = try await api.seriesApi.getUpdatedSeries()  // content depends on server-side edits
        #expect(try await api.seriesApi.getAllCollectionsBySeries(hero.id).count == 1)
    }

    @Test func collectionsReadListsReferential() async throws {
        let (api, _) = try await FixtureServer.loggedInApi()

        let collection = try #require(try await api.collectionsApi.getAll().content.first)
        let collectionSeries = try await api.collectionsApi.getSeriesForCollection(collection.id)
        #expect(collectionSeries.totalElements == 2)
        #expect(try await api.collectionsApi.getOne(collection.id).name == "Fixture Collection")

        let readList = try #require(try await api.readListApi.getAll().content.first)
        let readListBooks = try await api.readListApi.getBooksForReadList(readList.id)
        #expect(readListBooks.content.map(\.id) == readList.bookIds)
        let next = try await api.readListApi.getBookSiblingNext(readList.id, bookId: readList.bookIds[0])
        #expect(next?.id == readList.bookIds[1])
        #expect(try await api.readListApi.getBookSiblingPrevious(readList.id, bookId: readList.bookIds[0]) == nil)

        #expect(try await api.referentialApi.getGenres().contains("shonen"))  // Komga lowercases genres
        #expect(try await api.referentialApi.getTags().contains("fixture"))
        #expect(try await api.referentialApi.getAuthors().content.contains { $0.name == "Fixture Writer" })
        #expect(try await api.referentialApi.getAuthorsNames(search: "Fix").contains("Fixture Artist"))
        #expect(!(try await api.referentialApi.getSeriesReleaseDates(libraryIds: [], collectionId: nil)).isEmpty)
        _ = try await api.referentialApi.getAuthorsRoles()
        _ = try await api.referentialApi.getBookTags(seriesId: nil, readListId: readList.id, libraryIds: [])

        let settings = try await api.settingsApi.getSettings()
        #expect(settings.rememberMeDurationDays > 0)
        #expect(try await api.userApi.getAllUsers().count >= 1)
        let activity = try await api.userApi.getMeAuthenticationActivity(pageRequest: nil, unpaged: false)
        #expect(activity.totalElements > 0)
    }

    @Test func readProgressRoundTripAndSSE() async throws {
        let (api, _) = try await FixtureServer.loggedInApi()
        // Page-based progress is DIVINA-only (Komga answers 400 for EPUB books).
        let book = try #require(try await api.bookApi.getBookList(
            condition: .allOfBooks(.title(.isEqualTo("Fixture Hero #1")))).content.first)

        let session = try await api.createSSESession()
        defer { session.cancel() }
        try await Task.sleep(for: .seconds(1))  // let the stream connect

        try await api.bookApi.markReadProgress(book.id, request: .init(page: 2))
        #expect(try await api.bookApi.getOne(book.id).readProgress?.page == 2)

        let received = await withTaskGroup(of: KomgaEvent?.self) { group in
            group.addTask {
                for await event in session.incoming {
                    if case .readProgressChanged(let payload) = event, payload.bookId == book.id { return event }
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        #expect(received != nil, "expected a ReadProgressChanged SSE event")

        try await api.bookApi.deleteReadProgress(book.id)
        #expect(try await api.bookApi.getOne(book.id).readProgress == nil)
    }

    @Test func metadataPatchSemantics() async throws {
        let (api, _) = try await FixtureServer.loggedInApi()
        let series = try #require(try await api.seriesApi.getSeriesList(
            condition: .title(.isEqualTo("Second Series"))).content.first)

        var patch = KomgaSeriesMetadataUpdateRequest()
        patch.summary = .some("patched by test")
        try await api.seriesApi.update(series.id, request: patch)
        let patched = try await api.seriesApi.getOneSeries(series.id)
        #expect(patched.metadata.summary == "patched by test")
        #expect(patched.metadata.title == series.metadata.title)  // unset fields untouched

        var restore = KomgaSeriesMetadataUpdateRequest()
        restore.summary = .some(series.metadata.summary)
        restore.summaryLock = .some(false)
        try await api.seriesApi.update(series.id, request: restore)
    }

    @Test func bookFileDownloadRequest() async throws {
        let (api, _) = try await FixtureServer.loggedInApi()
        let book = try #require(try await api.bookApi.getBookList(
            condition: .allOfBooks(.title(.isEqualTo("Fixture Hero #1")))).content.first)
        let (data, response) = try await URLSession.shared.data(for: api.remoteBookApi.bookFileRequest(book.id))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(Int64(data.count) == book.sizeBytes)
        #expect(data.starts(with: [0x50, 0x4B]))  // "PK" zip
    }
}
