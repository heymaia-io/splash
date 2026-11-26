import Foundation
import KomgaAPI
import SplashCore
import Testing
@testable import SplashUI

/// [NUEVO] The sort picked on one screen instance must be the one the next instance opens with.
@Suite struct RememberedSortTests {
    private let fallback = SortChain<BooksSortOption>(primary: .pagesDesc, secondary: .titleAsc)

    @Test func savedChainRestores() {
        let chain = SortChain<BooksSortOption>(primary: .titleDesc, secondary: .pagesAsc)
        #expect(SortChain(saved: chain.saved, default: fallback) == chain)
    }

    @Test func aChoiceWithoutSecondaryDoesNotInheritTheDefaultOne() {
        let chain = SortChain<BooksSortOption>(primary: .numberAsc)
        #expect(SortChain(saved: chain.saved, default: fallback) == chain)
    }

    @Test func nothingSavedOrAnUnknownNameMeansTheDefault() {
        #expect(SortChain(saved: nil, default: fallback) == fallback)
        #expect(SortChain(saved: SavedSort(primary: "retired"), default: fallback) == fallback)
    }

    @Test func anUnusableSecondaryIsDropped() {
        let unknown = SortChain(saved: SavedSort(primary: "numberAsc", secondary: "retired"), default: fallback)
        #expect(unknown == SortChain(primary: .numberAsc))
        let sameField = SortChain(saved: SavedSort(primary: "titleAsc", secondary: "titleDesc"), default: fallback)
        #expect(sameField == SortChain(primary: .titleAsc))
    }

    @MainActor @Test func aSeriesScreenOpensOnAndReturnsToTheRememberedSort() async throws {
        let settings = try await SettingsState.load(
            from: InMemorySettingsStore<AppSettings>(), default: AppSettings())
        func model() -> SeriesViewModel {
            SeriesViewModel(
                seriesId: KomgaSeriesId("s1"), api: StubKomgaApi(bookApi: RecordingBookApi()),
                authState: KomgaAuthenticationState(), settings: settings, events: KomgaEventBroadcaster())
        }
        let older = model()
        #expect(older.sort == SeriesViewModel.defaultSort)

        let chosen = SortChain<BooksSortOption>(primary: .titleAsc)
        try await settings.set(\.bookSort, chosen.saved)

        #expect(model().sort == chosen)
        older.restoreRememberedSort()
        #expect(older.sort == chosen)
    }

    @Test func rememberWritesTheChain() async throws {
        let settings = try await SettingsState.load(
            from: InMemorySettingsStore<AppSettings>(), default: AppSettings())
        let chain = SortChain<BooksSortOption>(primary: .titleAsc)
        var changes = settings.values(\.bookSort).makeAsyncIterator()
        #expect(await changes.next() == .some(nil))
        settings.remember(chain, in: \.bookSort)
        #expect(await changes.next() == chain.saved)
    }
}
