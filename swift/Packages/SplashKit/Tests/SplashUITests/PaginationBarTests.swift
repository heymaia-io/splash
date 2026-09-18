import Testing
@testable import SplashUI

/// The page list is pure arithmetic and easy to get subtly wrong at the edges — an off-by-one here
/// either hides a page entirely or renders an ellipsis covering nothing.
@MainActor
@Suite struct PaginationBarTests {
    private func items(_ current: Int, of total: Int, window: Int = 2) -> [PaginationBar.Item] {
        PaginationBar.items(current: current, total: total, window: window)
    }

    @Test func shortRunsShowEveryPage() {
        #expect(items(1, of: 2) == [.page(1), .page(2)])
        #expect(items(3, of: 5) == [.page(1), .page(2), .page(3), .page(4), .page(5)])
    }

    @Test func aGapOnlyAppearsWhenItCoversSomething() {
        // Six pages with a window of two: page 2 is adjacent, so there is nothing to collapse on the left.
        #expect(items(2, of: 6) == [.page(1), .page(2), .page(3), .page(4), .gap(5...5), .page(6)])
    }

    @Test func bothEndsStayReachableInTheMiddleOfALongRun() {
        let result = items(10, of: 20)
        #expect(result == [
            .page(1), .gap(2...7), .page(8), .page(9), .page(10), .page(11), .page(12), .gap(13...19),
            .page(20),
        ])
        // First and last are always one tap away, however deep the library.
        #expect(result.first == .page(1))
        #expect(result.last == .page(20))
    }

    @Test func theCurrentPageIsAlwaysPresent() {
        for total in [2, 3, 7, 50, 999] {
            for current in [1, total / 2, total] where current >= 1 {
                #expect(items(current, of: total).contains(.page(current)),
                        "page \(current) of \(total) missing")
            }
        }
    }

    @Test func gapsNeverOverlapOrRepeatAPage() {
        for total in [2, 5, 8, 31, 400] {
            for current in 1...total {
                var seen = Set<Int>()
                for item in items(current, of: total) {
                    let pages: [Int] = switch item {
                    case .page(let p): [p]
                    case .gap(let range): Array(range)
                    }
                    for page in pages {
                        #expect(seen.insert(page).inserted, "page \(page) listed twice (\(current)/\(total))")
                        #expect((1...total).contains(page), "page \(page) out of range (\(current)/\(total))")
                    }
                }
                #expect(seen.count == total, "not every page reachable for \(current)/\(total)")
            }
        }
    }

    @Test func compactWindowStillKeepsTheNeighbours() {
        #expect(items(10, of: 20, window: 1) == [
            .page(1), .gap(2...8), .page(9), .page(10), .page(11), .gap(12...19), .page(20),
        ])
    }
}
