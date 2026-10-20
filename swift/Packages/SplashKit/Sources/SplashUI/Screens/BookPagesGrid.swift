import KomgaAPI
import SplashCore
import SwiftUI

/// Every page of a book as a tappable thumbnail, so reading can resume from any page rather than only from
/// the saved progress. Cells are lazy and go through `ThumbnailView`'s cache, so a long book only fetches
/// what scrolls into view.
///
/// A plain `LazyVGrid` rather than `CardGrid`: this sits inside `BookDetails`, which already pads its content,
/// and `CardGrid` adds its own horizontal padding.
struct BookPagesGrid: View {
    let bookId: KomgaBookId
    let pages: LoadState<[KomgaBookPage]>
    /// Receives the 1-based page number.
    let onSelect: (Int) -> Void

    private static let coverRatio: CGFloat = 0.703
    private let columns = [GridItem(.adaptive(minimum: 90, maximum: 140), spacing: 8)]

    var body: some View {
        switch pages {
        case .uninitialized:
            EmptyView()
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .error(let error):
            Text(error.localizedDescription).foregroundStyle(.secondary).font(.footnote)
        case .success(let pages):
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pages, id: \.number) { page in
                    Button { onSelect(page.number) } label: { cell(page) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(page.number)")
                }
            }
        }
    }

    private func cell(_ page: KomgaBookPage) -> some View {
        VStack(spacing: 4) {
            ThumbnailView(.bookPage(bookId, page: page.number), contentMode: .fit)
                .aspectRatio(Self.aspectRatio(of: page), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            Text(verbatim: "\(page.number)").font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Komga reports page dimensions after analysis; fall back to the cover ratio when they are missing.
    static func aspectRatio(of page: KomgaBookPage) -> CGFloat {
        guard let width = page.width, let height = page.height, width > 0, height > 0 else { return coverRatio }
        return CGFloat(width) / CGFloat(height)
    }
}
