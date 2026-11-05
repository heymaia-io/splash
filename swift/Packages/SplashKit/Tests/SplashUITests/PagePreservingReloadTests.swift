import Testing
@testable import SplashUI

/// Deleting from page 10 must not throw the reader back to page 1.
@MainActor
@Suite struct PagePreservingReloadTests {
    /// A fake paged list: `load` records the page it was asked for and publishes the (possibly shrunken) count.
    @MainActor private final class FakeList {
        var totalPages: Int
        private(set) var requested: [Int] = []
        init(totalPages: Int) { self.totalPages = totalPages }

        func load(_ page: Int) async { requested.append(page) }
    }

    @Test func staysOnTheCurrentPageWhenItStillExists() async {
        let list = FakeList(totalPages: 12)
        await PagePreservingReload.run(page: 10, totalPages: { list.totalPages }, load: list.load)
        #expect(list.requested == [10])
    }

    @Test func stepsBackToTheNewLastPageWhenTheDeleteEmptiedTheOldOne() async {
        let list = FakeList(totalPages: 9)  // page 10 no longer exists after the delete
        await PagePreservingReload.run(page: 10, totalPages: { list.totalPages }, load: list.load)
        #expect(list.requested == [10, 9])
    }

    @Test func neverGoesBelowThePageOneWhenTheListBecomesEmpty() async {
        let list = FakeList(totalPages: 0)
        await PagePreservingReload.run(page: 1, totalPages: { list.totalPages }, load: list.load)
        #expect(list.requested == [1])
    }
}
