import KomgaAPI
import SwiftUI

/// One selectable ordering (e.g. "Title A–Z"). Each screen's option enum conforms, so the chain below
/// composes orderings without knowing which screen it serves (strategy pattern).
protocol SortOption: CaseIterable, Identifiable, Hashable, Sendable where AllCases: RandomAccessCollection {
    var komgaSort: KomgaSort { get }
    var label: LocalizedStringKey { get }
    /// False for orderings that make no sense as a tie-breaker (e.g. a random shuffle).
    var canBeSecondary: Bool { get }
    /// False for orderings with no ties to break (a random shuffle), so nothing can follow them.
    var canHaveSecondary: Bool { get }
}

extension SortOption {
    var canBeSecondary: Bool { true }
    var canHaveSecondary: Bool { true }

    /// The property this option orders by. Two options on the same property (Title A–Z / Z–A) must not be
    /// chained: the second can never break a tie the first leaves.
    var field: String? { komgaSort.orders.first?.property }
}

/// "Sort by" + an optional "Then by". The second order only breaks ties left by the first, so
/// "Pages (most first), then Title A–Z" lists books by length and alphabetizes those of equal length.
struct SortChain<Option: SortOption>: Hashable, Sendable {
    private(set) var primary: Option
    private(set) var secondary: Option?

    init(primary: Option, secondary: Option? = nil) {
        self.primary = primary
        self.secondary = secondary
        dropInvalidSecondary()
    }

    var komgaSort: KomgaSort { primary.komgaSort.and(secondary?.komgaSort ?? .unsorted) }

    var secondaryChoices: [Option] {
        guard primary.canHaveSecondary else { return [] }
        return Option.allCases.filter { $0.canBeSecondary && $0.field != primary.field }
    }

    /// Changing the primary can invalidate the secondary; this is the one place that rule is enforced.
    mutating func setPrimary(_ option: Option) {
        primary = option
        dropInvalidSecondary()
    }

    mutating func setSecondary(_ option: Option?) {
        secondary = option
        dropInvalidSecondary()
    }

    private mutating func dropInvalidSecondary() {
        if let secondary, !secondaryChoices.contains(secondary) { self.secondary = nil }
    }
}

/// The two pickers, shared by every screen that offers a sort chain.
struct SortChainMenu<Option: SortOption>: View {
    @Binding var chain: SortChain<Option>

    var body: some View {
        Picker("Sort by", selection: Binding(get: { chain.primary }, set: { chain.setPrimary($0) })) {
            ForEach(Option.allCases) { Text($0.label).tag($0) }
        }
        if !chain.secondaryChoices.isEmpty {
            Picker("Then by", selection: Binding(get: { chain.secondary }, set: { chain.setSecondary($0) })) {
                Text("None").tag(Option?.none)
                ForEach(chain.secondaryChoices) { Text($0.label).tag(Option?.some($0)) }
            }
        }
    }
}
