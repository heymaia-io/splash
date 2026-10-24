import Foundation
import KomgaAPI
import Synchronization
import Testing
@testable import SplashCore
@testable import SplashUI

/// Deleting or renaming a whole series: the same server-side delete as for a book, plus a rename that must
/// stick (locked) and never write an empty title.
@MainActor
@Suite struct SeriesAdminTests {
    @MainActor private struct Harness {
        let books = RecordingBookApi()
        let seriesApi = StubSeriesApi()
        let library = RecordingLibraryApi()
        let events = KomgaEventBroadcaster()
        let series: KomgaSeries
        let gone = GoneIds()

        init(series: KomgaSeries = Fixture.series("s1", library: "L1", title: "One Piece")) {
            self.series = series
            let gone = self.gone
            seriesApi.onGetOneSeries = { id in
                gone.contains(id.rawValue) ? Fixture.series(id.rawValue, library: "L1", deleted: true) : series
            }
        }

        var api: StubKomgaApi { StubKomgaApi(bookApi: books, seriesApi: seriesApi, libraryApi: library) }
        var actions: SeriesAdminActions { SeriesAdminActions(api: api, events: events) }
    }

    @Test func deletingASeriesWaitsForKomgaThenEmptiesItsLibraryTrash() async throws {
        let h = Harness()
        let (events, gone, series) = (h.events, h.gone, h.series)
        h.seriesApi.onDelete = { id in
            Task {
                try await Task.sleep(for: .milliseconds(20))
                gone.insert(id.rawValue)
                events.emit(.seriesChanged(.init(seriesId: series.id, libraryId: series.libraryId)))
            }
        }

        try await h.actions.delete(series)

        #expect(h.seriesApi.deletes == [series.id])
        #expect(h.library.emptiedTrash == [series.libraryId])
    }

    @Test func aSeriesTheServerKeepsIsReportedNotSilentlyIgnored() async {
        let h = Harness()
        let result = await ServerFileDeleter.delete(
            [SeriesTarget(series: h.series)], api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(result.failures.first?.error is ServerFileDeleter.NotDeleted)
        #expect(h.library.emptiedTrash.isEmpty)
    }

    @Test func renameWritesTheTitleAndSortTitleAndLocksBoth() async throws {
        let h = Harness()
        try await h.actions.rename(h.series, to: "  One Piece (JP)  ")

        let request = try #require(h.seriesApi.updates.first)
        #expect(request.title == .some("One Piece (JP)"))
        #expect(request.titleSort == .some("One Piece (JP)"))
        #expect(request.titleLock == .some(true))
        #expect(request.titleSortLock == .some(true))
    }

    @Test func renameIgnoresBlankAndUnchangedTitles() async throws {
        let h = Harness()
        try await h.actions.rename(h.series, to: "   ")
        try await h.actions.rename(h.series, to: "One Piece")
        #expect(h.seriesApi.updates.isEmpty)
    }

    @Test func onlyOnlineAdminsMayManageSeries() {
        let auth = KomgaAuthenticationState()
        auth.setStateValues(user: Fixture.user(admin: true), libraries: [])
        #expect(SeriesAdminActions.canManage(authState: auth, isOfflineMode: false))
        #expect(!SeriesAdminActions.canManage(authState: auth, isOfflineMode: true))

        auth.setStateValues(user: Fixture.user(admin: false), libraries: [])
        #expect(!SeriesAdminActions.canManage(authState: auth, isOfflineMode: false))
    }
}
