import Foundation
import KomgaAPI
import Testing
@testable import SplashCore
@testable import SplashUI

/// The pages grid on the book screen opens the reader on a chosen page. That page has to win over the saved
/// progress and stay inside the book, because both reader models position themselves from `readProgressPage`.
@MainActor
@Suite struct ReaderStartPageTests {
    private func reader(initialPage: Int?, pageCount: Int = 10, progress: ReadProgress? = nil) -> ReaderViewModel {
        let books = RecordingBookApi()
        books.onGetOne = { _ in Fixture.book(pagesCount: pageCount, readProgress: progress) }
        books.onGetBookPages = { _ in Fixture.pages(pageCount) }
        let series = StubSeriesApi()
        series.onGetOneSeries = { _ in Fixture.series() }
        let api = StubKomgaApi(bookApi: books, seriesApi: series)
        let settings = SettingsState(initial: ImageReaderSettings()) { _ in }
        return ReaderViewModel(bookId: "b1", api: api, settings: settings, initialPage: initialPage)
    }

    @Test func requestedPageOverridesSavedProgress() async {
        let model = reader(initialPage: 5, progress: Fixture.progress(page: 3))
        await model.initialize()
        #expect(model.readProgressPage == 5)
    }

    @Test func requestedPageIsClampedToTheBook() async {
        let tooFar = reader(initialPage: 50)
        await tooFar.initialize()
        #expect(tooFar.readProgressPage == 10)

        let tooEarly = reader(initialPage: 0)
        await tooEarly.initialize()
        #expect(tooEarly.readProgressPage == 1)
    }

    @Test func withoutARequestedPageProgressStillWins() async {
        let model = reader(initialPage: nil, progress: Fixture.progress(page: 7))
        await model.initialize()
        #expect(model.readProgressPage == 7)

        let finished = reader(initialPage: nil, progress: Fixture.progress(page: 10, completed: true))
        await finished.initialize()
        #expect(finished.readProgressPage == 1)
    }

    @Test func clampingNeverLeavesTheOneBasedRange() {
        #expect(ReaderViewModel.clampedPage(3, count: 0) == 1)
        #expect(ReaderViewModel.clampedPage(-2, count: 5) == 1)
        #expect(ReaderViewModel.clampedPage(5, count: 5) == 5)
    }
}
