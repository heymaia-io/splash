import Foundation
import Testing
@testable import SplashCore
@testable import SplashUI
@testable import KomgaAPI

/// [NUEVO] The library's navigation aids: the `ALL # A–Z` bar, the shuffle sort, the tag/genre browse facet,
/// and the remembered library selection. All four turn into query conditions or a destination, so they are
/// testable without a server.
@MainActor
@Suite struct LibraryBrowsingTests {
    private static func json<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try KomgaJSON.makeEncoder().encode(value), as: UTF8.self)
    }

    // MARK: A–Z bar

    @Test func allMeansNoRestriction() {
        #expect(SeriesLetterFilter.all.seriesCondition == nil)
    }

    @Test func aLetterMatchesTheSortTitlePrefix() throws {
        let condition = try #require(SeriesLetterFilter.letter("B").seriesCondition)
        #expect(condition == .titleSort(.beginsWith("b")))
        #expect(try Self.json(condition) == #"{"titleSort":{"operator":"beginsWith","value":"b"}}"#)
    }

    /// `#` is "starts with none of A–Z" — numbers, symbols, non-Latin scripts — so it must exclude every
    /// letter at once, not match some "other" bucket the server does not have.
    @Test func hashExcludesEveryLetter() throws {
        let condition = try #require(SeriesLetterFilter.nonAlphabetic.seriesCondition)
        guard case .allOf(let parts) = condition else {
            Issue.record("expected an allOf group, got \(condition)")
            return
        }
        #expect(parts.count == 26)
        #expect(parts.first == .titleSort(.doesNotBeginWith("a")))
        #expect(parts.last == .titleSort(.doesNotBeginWith("z")))
    }

    @Test func theBarOffersAllHashAndTwentySixLetters() {
        let cases = SeriesLetterFilter.allCases
        #expect(cases.count == 28)
        #expect(cases.first == .all)
        #expect(cases.dropFirst().first == .nonAlphabetic)
        #expect(cases.map(\.id).first(where: { $0 == "#" }) != nil)
        // Ids are what `ForEach` keys on, so duplicates would silently drop chips.
        #expect(Set(cases.map(\.id)).count == cases.count)
    }

    // MARK: Shuffle

    /// Komga maps `random` to `DSL.rand()` and re-rolls it per request, which is why the screen presents a
    /// shuffled listing as a single page.
    @Test func randomSortSendsOneRandomOrder() {
        let request = KomgaPageRequest(pageIndex: 0, size: 20, sort: SeriesSortOption.random.komgaSort)
        #expect(request.queryItems.map { "\($0.name)=\($0.value ?? "")" } == [
            "size=20", "page=0", "unpaged=false", "sort=random,asc",
        ])
    }

    @Test func everySortOptionIsOfferedIncludingRandom() {
        #expect(SeriesSortOption.allCases.contains(.random))
        // Each option must map to exactly one order, or the server sorts by something unexpected.
        for option in SeriesSortOption.allCases {
            #expect(option.komgaSort.orders.count == 1)
        }
    }

    // MARK: Browse facets

    @Test func tagFacetAppliesToSeriesAndBooks() {
        let facet = BrowseFacet.tag("horror")
        #expect(facet.value == "horror")
        #expect(facet.seriesCondition == .tag(.isEqualTo("horror")))
        #expect(facet.bookCondition == .tag(.isEqualTo("horror")))
    }

    /// Komga has no book-level genre, so a genre facet must not produce a book query — it would silently
    /// match nothing or, worse, everything.
    @Test func genreFacetIsSeriesOnly() {
        let facet = BrowseFacet.genre("Horror")
        #expect(facet.seriesCondition == .genre(.isEqualTo("Horror")))
        #expect(facet.bookCondition == nil)
    }

    @Test func facetDestinationsAreDistinct() {
        #expect(Destination.facet(.tag("x")) == .facet(.tag("x")))
        #expect(Destination.facet(.tag("x")) != .facet(.genre("x")))
        #expect(Destination.facet(.tag("x")) != .facet(.tag("y")))
    }

    // MARK: Remembered library

    private func settings(lastLibraryId: String?) async throws -> CommonSettingsRepository {
        var value = AppSettings()
        value.lastLibraryId = lastLibraryId
        return try await SettingsState.load(from: InMemorySettingsStore(value), default: AppSettings())
    }

    private func authState(_ ids: [KomgaLibraryId]) -> KomgaAuthenticationState {
        let state = KomgaAuthenticationState()
        state.updateLibraries(ids.map { KomgaLibrary(id: $0, name: $0.rawValue, root: "/data/\($0.rawValue)") })
        return state
    }

    @Test func libraryTabReopensOnTheRememberedLibrary() async throws {
        let model = MainScreenViewModel(
            authState: authState(["L1", "L2"]), settings: try await settings(lastLibraryId: "L2"))
        #expect(model.rememberedLibrary == KomgaLibraryId("L2"))
        #expect(model.root(for: .library) == .library("L2"))
        // Other tabs are unaffected.
        #expect(model.root(for: .home) == .home)
        #expect(model.root(for: .downloads) == .downloads)
    }

    @Test func nothingRememberedMeansAllLibraries() async throws {
        let model = MainScreenViewModel(
            authState: authState(["L1"]), settings: try await settings(lastLibraryId: nil))
        #expect(model.rememberedLibrary == nil)
        #expect(model.root(for: .library) == .library(nil))
    }

    /// A library that is no longer on this server (or was never on it) must not be restored, or the tab
    /// opens on a library the user cannot see and the screen shows nothing.
    @Test func staleLibraryFallsBackToAllLibraries() async throws {
        let model = MainScreenViewModel(
            authState: authState(["L1"]), settings: try await settings(lastLibraryId: "GONE"))
        #expect(model.rememberedLibrary == nil)
    }

    /// The whole point of the private area: a hidden library must not come back through the tab bar while
    /// the app is locked, and must come back once it is revealed.
    @Test func hiddenLibraryIsNotRestoredWhileLocked() async throws {
        var hidden = HiddenContent()
        hidden.libraries = ["L2"]
        let settings = try await settings(lastLibraryId: "L2")
        let state = authState(["L1", "L2"])

        let locked = MainScreenViewModel(
            authState: state, settings: settings, hiddenFilter: { HiddenContentFilter(hidden: hidden) })
        #expect(locked.rememberedLibrary == nil)
        #expect(locked.root(for: .library) == .library(nil))

        let unlocked = MainScreenViewModel(authState: state, settings: settings, hiddenFilter: { .disabled })
        #expect(unlocked.rememberedLibrary == KomgaLibraryId("L2"))
    }

    /// The model reads the store rather than caching, so a write from anywhere (including its own
    /// fire-and-forget `rememberLibrary`) is picked up on the next read.
    @Test func rememberedLibraryFollowsTheStore() async throws {
        let settings = try await settings(lastLibraryId: nil)
        let model = MainScreenViewModel(authState: authState(["L1"]), settings: settings)
        #expect(model.rememberedLibrary == nil)
        try await settings.set(\.lastLibraryId, KomgaLibraryId("L1").rawValue)
        #expect(model.rememberedLibrary == KomgaLibraryId("L1"))
        try await settings.set(\.lastLibraryId, nil)
        #expect(model.rememberedLibrary == nil)
    }
}
