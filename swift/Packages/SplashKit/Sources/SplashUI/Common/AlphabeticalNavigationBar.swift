import KomgaAPI
import SwiftUI

/// [NUEVO] First-character filter for a series listing — the `ALL # A–Z` row the Komga web UI puts above the
/// grid (`AlphabeticalNavigation.vue`). Paging through 28 pages of covers was the only way to reach the tail
/// of a large library.
///
/// Each case knows the search condition it stands for (strategy), so view models only ask for
/// `seriesCondition` and the bar itself stays presentation-only. Komga's own grouping endpoint
/// (`POST api/v1/series/list/alphabetical-groups`) is deliberately not used: it would only add per-letter
/// counts, at the cost of a new API method plus offline SQL.
public enum SeriesLetterFilter: Hashable, Identifiable, Sendable {
    case all
    /// Titles beginning with none of A–Z: numbers, symbols, non-Latin scripts. The web UI labels this `#`.
    case nonAlphabetic
    case letter(Character)

    public static let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    public static let allCases: [SeriesLetterFilter] =
        [.all, .nonAlphabetic] + alphabet.map(SeriesLetterFilter.letter)

    public var id: String {
        switch self {
        case .all: "ALL"
        case .nonAlphabetic: "#"
        case .letter(let character): String(character)
        }
    }

    var label: String {
        switch self {
        case .all: String(localized: "ALL")
        default: id
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .all: String(localized: "All titles")
        case .nonAlphabetic: String(localized: "Titles starting with a number or symbol")
        case .letter(let character): String(localized: "Titles starting with \(String(character))")
        }
    }

    /// `nil` means no restriction. Prefixes are lower-cased like the web UI sends them; Komga compares
    /// `titleSort` case-insensitively either way.
    public var seriesCondition: SeriesCondition? {
        switch self {
        case .all:
            nil
        case .nonAlphabetic:
            .allOf(Self.alphabet.map { .titleSort(.doesNotBeginWith(String($0).lowercased())) })
        case .letter(let character):
            .titleSort(.beginsWith(String(character).lowercased()))
        }
    }
}

/// The `ALL # A–Z` chip row. Every letter stays tappable — an empty one simply shows "No series".
struct AlphabeticalNavigationBar: View {
    @Binding var selection: SeriesLetterFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SeriesLetterFilter.allCases) { item in
                    let isSelected = item == selection
                    Button(item.label) { selection = item }
                        .font(.caption.weight(isSelected ? .bold : .regular))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(isSelected ? .accentColor : .secondary)
                        .accessibilityLabel(item.accessibilityLabel)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }
}
