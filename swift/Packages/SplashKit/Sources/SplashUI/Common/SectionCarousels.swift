import SplashCore
import KomgaAPI
import SwiftUI

/// Home's shelf layout — filter chips over horizontal cover carousels — shared with the private area so
/// both read the same way. Extracted from `HomeScreen`, which is now its plainest caller.
struct SectionCarousels<CardMenu: View>: View {
    let sections: [HomeViewModel.Section]
    @Binding var activeFilter: Int
    let cardWidth: CGFloat
    let isLoading: Bool
    let navigate: (Destination) -> Void
    /// Extra per-card menu — the private area hangs "Unhide" here; Home passes nothing.
    @ViewBuilder var cardMenu: (Destination) -> CardMenu

    private var visibleSections: [HomeViewModel.Section] {
        let nonEmpty = sections.filter { !$0.isEmpty }
        guard activeFilter != 0 else { return nonEmpty }
        return nonEmpty.filter { $0.filter.order == activeFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                filterChips
                if visibleSections.isEmpty, !isLoading {
                    ContentUnavailableView("Nothing to show", systemImage: "books.vertical")
                }
                ForEach(visibleSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.filter.label).font(.title3.bold()).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                sectionCards(section)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .overlay(alignment: .top) {
            if isLoading { ProgressView().padding() }
        }
    }

    @ViewBuilder private func sectionCards(_ section: HomeViewModel.Section) -> some View {
        switch section {
        case .series(_, let series):
            ForEach(series) { item in
                let destination: Destination = item.oneshot ? .oneshot(item.id) : .series(item.id)
                Button { navigate(destination) } label: {
                    SeriesCard(series: item).frame(width: cardWidth)
                }
                .buttonStyle(.plain)
                .contextMenu { cardMenu(.series(item.id)) }
            }
        case .books(_, let books):
            ForEach(books) { book in
                let destination: Destination = book.oneshot ? .oneshot(book.seriesId) : .book(book.id)
                Button { navigate(destination) } label: {
                    BookCard(book: book, showSeries: true).frame(width: cardWidth)
                }
                .buttonStyle(.plain)
                .contextMenu { cardMenu(.book(book.id)) }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip(label: String(localized: "All"), tag: 0)
                ForEach(sections.filter { !$0.isEmpty }) { section in
                    chip(label: section.filter.label, tag: section.filter.order)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(label: String, tag: Int) -> some View {
        Button(label) { activeFilter = tag }
            .buttonStyle(.bordered)
            .tint(activeFilter == tag ? .accentColor : .secondary)
    }
}

extension SectionCarousels where CardMenu == EmptyView {
    init(
        sections: [HomeViewModel.Section], activeFilter: Binding<Int>, cardWidth: CGFloat,
        isLoading: Bool, navigate: @escaping (Destination) -> Void
    ) {
        self.init(
            sections: sections, activeFilter: activeFilter, cardWidth: cardWidth, isLoading: isLoading,
            navigate: navigate, cardMenu: { _ in EmptyView() })
    }
}
