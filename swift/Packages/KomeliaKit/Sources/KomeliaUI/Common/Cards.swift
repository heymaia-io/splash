import KomeliaCore
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
struct ItemCard<Overlay: View>: View {
    let thumbnail: ThumbnailRequest
    let title: String
    let subtitle: String?
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ThumbnailView(thumbnail)
                .aspectRatio(0.703, contentMode: .fit)  // Komga cover ratio
                .overlay(alignment: .topTrailing) { overlay().padding(4) }
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

extension ItemCard where Overlay == EmptyView {
    init(thumbnail: ThumbnailRequest, title: String, subtitle: String?) {
        self.init(thumbnail: thumbnail, title: title, subtitle: subtitle) { EmptyView() }
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

/// `SeriesItemCard.kt`
struct SeriesCard: View {
    let series: KomgaSeries

    var body: some View {
        ItemCard(
            thumbnail: .seriesDefault(series.id),
            title: series.metadata.title,
            subtitle: series.oneshot ? String(localized: "Oneshot")
                : String(localized: "\(series.booksCount) books")
        ) {
            if series.booksUnreadCount > 0, !series.oneshot { CountBadge(count: series.booksUnreadCount) }
        }
    }
}

/// `BookItemCard.kt`
struct BookCard: View {
    let book: KomeliaBook
    var showSeries = false

    var body: some View {
        ItemCard(
            thumbnail: .bookDefault(book.id),
            title: showSeries ? book.seriesTitle : book.metadata.title,
            subtitle: showSeries ? book.metadata.title : String(localized: "\(book.media.pagesCount) pages")
        ) {
            HStack(spacing: 4) {
                if book.downloaded {
                    Image(systemName: book.isLocalFileOutdated ? "arrow.down.circle.dotted" : "arrow.down.circle.fill")
                        .foregroundStyle(.white, .green)
                }
                if book.readProgress == nil {
                    Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.tint)
                        .accessibilityLabel("Unread")
                }
            }
        }
        .overlay(alignment: .bottom) { progressBar }
    }

    @ViewBuilder private var progressBar: some View {
        if let progress = book.readProgress, !progress.completed, book.media.pagesCount > 0 {
            ProgressView(value: Double(progress.page), total: Double(book.media.pagesCount))
                .progressViewStyle(.linear)
                .padding(.horizontal, 4)
                .padding(.bottom, 44)
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

    var body: some View {
        if totalPages > 1 {
            HStack(spacing: 16) {
                Button { onPageChange(currentPage - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(currentPage <= 1)
                Menu("\(currentPage) / \(totalPages)") {
                    ForEach(1...totalPages, id: \.self) { page in
                        Button("\(page)") { onPageChange(page) }
                    }
                }
                .monospacedDigit()
                Button { onPageChange(currentPage + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(currentPage >= totalPages)
            }
            .buttonStyle(.bordered)
            .padding()
        }
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
