import Foundation
import Testing
@testable import SplashUI
@testable import KomgaAPI

/// [NUEVO] The per-series sort options (number, title, page count) must each reach Komga as exactly one
/// order on the right property.
@Suite struct BooksSortOptionTests {
    private static func query(_ option: BooksSortOption) -> [String] {
        KomgaPageRequest(pageIndex: 0, size: 20, sort: option.komgaSort).queryItems
            .filter { $0.name == "sort" }
            .map { $0.value ?? "" }
    }

    @Test func eachOptionSendsOneOrderOnTheExpectedProperty() {
        #expect(Self.query(.numberAsc) == ["metadata.numberSort,asc"])
        #expect(Self.query(.numberDesc) == ["metadata.numberSort,desc"])
        #expect(Self.query(.titleAsc) == ["metadata.title,asc"])
        #expect(Self.query(.titleDesc) == ["metadata.title,desc"])
        #expect(Self.query(.pagesAsc) == ["media.pagesCount,asc"])
        #expect(Self.query(.pagesDesc) == ["media.pagesCount,desc"])
    }

    @Test func everyOptionIsOfferedOnce() {
        #expect(BooksSortOption.allCases.count == 6)
        #expect(Set(BooksSortOption.allCases.map(\.id)).count == BooksSortOption.allCases.count)
    }
}
