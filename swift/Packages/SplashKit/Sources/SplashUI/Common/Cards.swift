import SplashCore
import KomgaAPI
import SwiftUI

/// Adaptive grid sized by the `cardWidth` setting (Kotlin `LazyVerticalGrid(GridCells.Adaptive(cardWidth))`).
struct CardGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let cardWidth: CGFloat
    @ViewBuilder let card: (Item) -> Card

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth * 1.6), spacing: 12)],
                  spacing: 16) {
            ForEach(items) { item in card(item) }
        }
        .padding(.horizontal)
    }
}

/// Cover + caption card shared by series/book/collection/read-list cards (`ItemCard.kt`).
struct ItemCard<Overlay: View, Footer: View>: View {
    let thumbnail: ThumbnailRequest
    let title: String
    let subtitle: String?
    @ViewBuilder var overlay: () -> Overlay
    /// Drawn over the bottom of the cover (read progress), never over the caption.
    @ViewBuilder var coverFooter: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ThumbnailView(thumbnail)
                .aspectRatio(0.703, contentMode: .fit)  // Komga cover ratio
                .overlay(alignment: .topTrailing) { overlay().padding(4) }
                .overlay(alignment: .bottom) { coverFooter() }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2, reservesSpace: true)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension ItemCard where Footer == EmptyView {
    init(
        thumbnail: ThumbnailRequest, title: String, subtitle: String?,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(thumbnail: thumbnail, title: title, subtitle: subtitle, overlay: overlay) { EmptyView() }
    }
}

extension ItemCard where Overlay == EmptyView, Footer == EmptyView {
    init(thumbnail: ThumbnailRequest, title: String, subtitle: String?) {
        self.init(thumbnail: thumbnail, title: title, subtitle: subtitle) { EmptyView() } coverFooter: { EmptyView() }
    }
}

struct CountBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.tint, in: Capsule())
            .foregroundStyle(.white)
    }
}

/// A hidden item is only ever on screen while the private area is unlocked, where it is otherwise
/// indistinguishable from everything else — so it says so.
///
/// Composed *with* the unread count and download glyph in the same overlay slot, never in place of them.
struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(3)
            .background(.purple, in: Circle())
            .accessibilityLabel("Private")
    }
}

/// `SeriesItemCard.kt`
struct SeriesCard: View {
    let series: KomgaSeries
    @Environment(\.privacy) private var privacy

    private var isHidden: Bool {
        guard let privacy, privacy.isUnlocked else { return false }
        return privacy.isHidden(seriesId: series.id) || privacy.isHidden(libraryId: series.libraryId)
    }

    var body: some View {
        ItemCard(
            thumbnail: .seriesDefault(series.id),
            title: series.metadata.title,
            subtitle: series.oneshot ? String(localized: "Oneshot")
                : String(localized: "\(series.booksCount) books")
        ) {
            HStack(spacing: 4) {
                if isHidden { LockBadge() }
                if series.booksUnreadCount > 0, !series.oneshot { CountBadge(count: series.booksUnreadCount) }
            }
        }
    }
}

/// `BookItemCard.kt`
struct BookCard: View {
    let book: SplashBook
    var showSeries = false
    @Environment(\.privacy) private var privacy

    private var isHidden: Bool {
        guard let privacy, privacy.isUnlocked else { return false }
        return privacy.isHidden(bookId: book.id) || privacy.isHidden(seriesId: book.seriesId)
            || privacy.isHidden(libraryId: book.libraryId)
    }

    var body: some View {
        ItemCard(
            thumbnail: .bookDefault(book.id),
            title: showSeries ? book.seriesTitle : book.metadata.title,
            subtitle: showSeries ? book.metadata.title : String(localized: "\(book.media.pagesCount) pages")
        ) {
            HStack(spacing: 4) {
                if isHidden { LockBadge() }
                if book.downloaded {
                    Image(systemName: book.isLocalFileOutdated ? "arrow.down.circle.dotted" : "arrow.down.circle.fill")
                        .foregroundStyle(.white, .green)
                }
                if book.readProgress == nil {
                    Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.tint)
                        .accessibilityLabel("Unread")
                }
            }
        } coverFooter: {
            progressBar
        }
    }

    @ViewBuilder private var progressBar: some View {
        if let progress = book.readProgress, !progress.completed, book.media.pagesCount > 0 {
            ProgressView(value: Double(progress.page), total: Double(book.media.pagesCount))
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .padding(6)
                .background(.black.opacity(0.35))
        }
    }
}

/// `CollectionItemCard.kt`
struct CollectionCard: View {
    let collection: KomgaCollection
    var body: some View {
        ItemCard(thumbnail: .collectionDefault(collection.id), title: collection.name,
                 subtitle: String(localized: "\(collection.seriesIds.count) series"))
    }
}

/// `ReadListItemCard.kt`
struct ReadListCard: View {
    let readList: KomgaReadList
    var body: some View {
        ItemCard(thumbnail: .readListDefault(readList.id), title: readList.name,
                 subtitle: String(localized: "\(readList.bookIds.count) books"))
    }
}

/// `Pagination.kt` — page navigation + page size.
struct PaginationBar: View {
    let currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// One slot in the bar: either a page you can tap, or a run of pages collapsed behind an ellipsis.
    enum Item: Hashable {
        case page(Int)
        case gap(ClosedRange<Int>)
    }

    var body: some View {
        if totalPages > 1 {
            HStack(spacing: 6) {
                Button { onPageChange(currentPage - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(currentPage <= 1)

                ForEach(Self.items(current: currentPage, total: totalPages, window: window), id: \.self) { item in
                    switch item {
                    case .page(let page):
                        Button("\(page)") { onPageChange(page) }
                            .buttonStyle(.bordered)
                            .tint(page == currentPage ? .accentColor : .secondary)
                            .fontWeight(page == currentPage ? .semibold : .regular)
                            .accessibilityAddTraits(page == currentPage ? .isSelected : [])
                    case .gap(let range):
                        // The skipped run is still reachable — two taps to any page, never a dead "…".
                        Menu("…") {
                            ForEach(Array(range), id: \.self) { page in
                                Button("\(page)") { onPageChange(page) }
                            }
                        }
                        .menuStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .accessibilityLabel("More pages")
                    }
                }

                Button { onPageChange(currentPage + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(currentPage >= totalPages)
            }
            .monospacedDigit()
            .buttonStyle(.bordered)
            .padding()
        }
    }

    /// How many pages to show either side of the current one. A phone cannot fit the wider window.
    private var window: Int { sizeClass == .compact ? 1 : 2 }

    /// The first and last page are always reachable in one tap; everything between them collapses into
    /// at most two ellipsis menus, so the bar has a fixed maximum width however deep the library is.
    static func items(current: Int, total: Int, window: Int) -> [Item] {
        guard total > 1 else { return [.page(1)] }
        var items: [Item] = [.page(1)]
        let lower = max(2, current - window)
        let upper = min(total - 1, current + window)

        if lower > 2 { items.append(.gap(2...(lower - 1))) }
        if lower <= upper { items.append(contentsOf: (lower...upper).map(Item.page)) }
        if upper < total - 1 { items.append(.gap((upper + 1)...(total - 1))) }

        items.append(.page(total))
        return items
    }
}

/// `ErrorContent.kt`
struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry", action: retry).buttonStyle(.borderedProminent)
        }
    }
}

extension KomgaSeries {
    var releaseYear: Int? { booksMetadata.releaseDate?.year }
}
