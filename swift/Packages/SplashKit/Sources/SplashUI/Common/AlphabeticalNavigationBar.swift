import KomgaAPI
import SwiftUI

/// [NUEVO] First-character filter for a series listing — the `ALL # A–Z` row the Komga web UI puts above the
/// grid (`AlphabeticalNavigation.vue`). Paging through 28 pages of covers was the only way to reach the tail
/// of a large library.
///
/// Each case knows the search condition it stands for (strategy), so view models only ask for
/// `seriesCondition` / `bookCondition` and the bar itself stays presentation-only. Komga's own grouping
/// endpoint (`POST api/v1/series/list/alphabetical-groups`) is deliberately not used: it would only add
/// per-letter counts, at the cost of a new API method plus offline SQL.
public enum LetterFilter: Hashable, Identifiable, Sendable {
    case all
    /// Titles beginning with none of A–Z: numbers, symbols, non-Latin scripts. The web UI labels this `#`.
    case nonAlphabetic
    case letter(Character)

    public static let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    public static let allCases: [LetterFilter] =
        [.all, .nonAlphabetic] + alphabet.map(LetterFilter.letter)

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

    /// Same filter for the books of a series. Komga has no `titleSort` condition for books (upstream
    /// `TitleSort` is series-only), so this matches the plain `title`. Books named "Chapter 12" or "Vol. 3"
    /// therefore collect under `#`, exactly as the web UI would group them.
    public var bookCondition: BookCondition? {
        switch self {
        case .all:
            nil
        case .nonAlphabetic:
            .allOf(Self.alphabet.map { .title(.doesNotBeginWith(String($0).lowercased())) })
        case .letter(let character):
            .title(.beginsWith(String(character).lowercased()))
        }
    }
}

/// Kept for readability at the series-only call sites; the enum itself is shared with books.
public typealias SeriesLetterFilter = LetterFilter

/// The `ALL # A–Z` chip row. Every letter stays tappable — an empty one simply shows an empty grid.
struct AlphabeticalNavigationBar: View {
    @Binding var selection: LetterFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LetterFilter.allCases) { item in
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
