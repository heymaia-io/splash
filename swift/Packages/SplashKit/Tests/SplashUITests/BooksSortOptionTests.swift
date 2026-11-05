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

    // MARK: Sort chain ("Sort by" + "Then by")

    private static func query(_ chain: SortChain<BooksSortOption>) -> [String] {
        KomgaPageRequest(pageIndex: 0, size: 20, sort: chain.komgaSort).queryItems
            .filter { $0.name == "sort" }
            .map { $0.value ?? "" }
    }

    @Test func chainSendsPrimaryThenSecondaryInOrder() {
        let chain = SortChain<BooksSortOption>(primary: .pagesDesc, secondary: .titleAsc)
        #expect(Self.query(chain) == ["media.pagesCount,desc", "metadata.title,asc"])
    }

    @Test func chainWithoutSecondaryIsJustThePrimary() {
        #expect(Self.query(SortChain(primary: .numberAsc)) == ["metadata.numberSort,asc"])
    }

    @Test func secondaryChoicesExcludeThePrimarysOwnField() {
        let choices = SortChain<BooksSortOption>(primary: .titleAsc).secondaryChoices
        #expect(!choices.contains(.titleAsc))
        #expect(!choices.contains(.titleDesc))
        #expect(choices.contains(.pagesDesc))
    }

    @Test func changingPrimaryDropsASecondaryOnTheSameField() {
        var chain = SortChain<BooksSortOption>(primary: .pagesDesc, secondary: .titleAsc)
        chain.setPrimary(.titleDesc)
        #expect(chain.secondary == nil)
    }

    @Test func changingPrimaryKeepsAStillValidSecondary() {
        var chain = SortChain<BooksSortOption>(primary: .pagesDesc, secondary: .titleAsc)
        chain.setPrimary(.numberAsc)
        #expect(chain.secondary == .titleAsc)
    }

    @Test func aSecondaryOnThePrimarysFieldIsRejected() {
        var chain = SortChain<BooksSortOption>(primary: .pagesDesc)
        chain.setSecondary(.pagesAsc)
        #expect(chain.secondary == nil)
    }
}

@Suite struct SeriesSortChainTests {
    @Test func randomOffersNoSecondaryAndIsNeverOfferedAsOne() {
        #expect(SortChain<SeriesSortOption>(primary: .random).secondaryChoices.isEmpty)
        #expect(!SortChain<SeriesSortOption>(primary: .titleAsc).secondaryChoices.contains(.random))
    }

    @Test func randomCannotBeSetAsSecondary() {
        var chain = SortChain<SeriesSortOption>(primary: .titleAsc)
        chain.setSecondary(.random)
        #expect(chain.secondary == nil)
    }

    @Test func switchingToRandomDropsTheSecondary() {
        var chain = SortChain<SeriesSortOption>(primary: .titleAsc, secondary: .updatedDesc)
        chain.setPrimary(.random)
        #expect(chain.secondary == nil)
    }
}
