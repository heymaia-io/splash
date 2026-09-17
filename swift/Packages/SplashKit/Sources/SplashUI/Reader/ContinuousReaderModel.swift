import CoreGraphics
import Foundation
import SplashCore
import SplashImage
import Observation

/// Port of `ContinuousReaderState.kt`: a strip of pages (vertical or horizontal) with side padding and page
/// spacing. The scroll/zoom mechanics live in the UIKit view; this model owns layout math, image loading and
/// progress.
@MainActor
@Observable
public final class ContinuousReaderModel {
    public private(set) var readingDirection: ContinuousReadingDirection
    public private(set) var sidePaddingFraction: CGFloat
    public private(set) var pageSpacing: CGFloat
    public private(set) var currentPageNumber = 1
    /// Incremented when the strip must be rebuilt (book or layout change).
    public private(set) var layoutVersion = 0
    /// Page the view should scroll to after a rebuild.
    public private(set) var pendingScrollPage: Int?

    let reader: ReaderViewModel
    private var images: [PageId: ReaderImage] = [:]
    private var loading: [PageId: Task<ReaderImage?, Never>] = [:]

    public init(reader: ReaderViewModel) {
        self.reader = reader
        let settings = reader.settings.value
        readingDirection = settings.continuousReadingDirection
        sidePaddingFraction = CGFloat(settings.continuousPadding)
        pageSpacing = CGFloat(settings.continuousPageSpacing)
    }

    public var pages: [PageMetadata] { reader.books?.currentBookPages ?? [] }
    public var isVertical: Bool { readingDirection == .topToBottom }

    public func bookDidChange() {
        images.values.forEach { image in Task { await image.releaseBitmap() } }
        images.removeAll()
        loading.values.forEach { $0.cancel() }
        loading.removeAll()
        currentPageNumber = reader.readProgressPage
        pendingScrollPage = reader.readProgressPage
        layoutVersion += 1
    }

    public func consumePendingScroll() -> Int? {
        defer { pendingScrollPage = nil }
        return pendingScrollPage
    }

    /// Frames of every page along the strip for a viewport. Unknown page sizes are guessed from the first known
    /// size (`guessPageDisplaySize`) and corrected when the image loads.
    public func layoutFrames(viewport: CGSize) -> [CGRect] {
        let cross = isVertical ? viewport.width : viewport.height
        let padding = (cross * sidePaddingFraction).rounded()
        let available = max(cross - 2 * padding, 1)
        let fallback = pages.lazy.compactMap { self.knownSize($0) }.first ?? CGSize(width: 2, height: 3)
        var cursor: CGFloat = 0
        return pages.map { page in
            let size = knownSize(page) ?? fallback
            let frame: CGRect
            if isVertical {
                let height = (size.height / max(size.width, 1) * available).rounded()
                frame = CGRect(x: padding, y: cursor, width: available, height: height)
                cursor += height + pageSpacing
            } else {
                let width = (size.width / max(size.height, 1) * available).rounded()
                frame = CGRect(x: cursor, y: padding, width: width, height: available)
                cursor += width + pageSpacing
            }
            return frame
        }
    }

    private func knownSize(_ page: PageMetadata) -> CGSize? {
        images[page.id]?.contentSize ?? page.size
    }

    public func image(for page: PageMetadata) async -> ReaderImage? {
        if let image = images[page.id] { return image }
        if let running = loading[page.id] { return await running.value }
        let task = Task<ReaderImage?, Never> { [reader] in
            guard let data = try? await reader.pages.data(for: page.id) else { return nil }
            let crop = reader.settings.value.cropBorders
            let factory = reader.imageFactory
            return try? await Task.detached(priority: .userInitiated) {
                try factory.makeImage(pageId: page.id, data: data, cropBorders: crop)
            }.value
        }
        loading[page.id] = task
        let image = await task.value
        loading[page.id] = nil
        if let image {
            let sizeChanged = page.size != image.contentSize
            images[page.id] = image
            if sizeChanged { layoutVersion += 1 }  // `updatePageSize`
        }
        return image
    }

    /// Pages far from the viewport release their bitmaps (`onPageDispose`).
    public func release(outside visible: Range<Int>, margin: Int = 4) {
        let keep = (visible.lowerBound - margin)..<(visible.upperBound + margin)
        for (index, page) in pages.enumerated() where !keep.contains(index) {
            if let image = images[page.id] { Task { await image.releaseBitmap() } }
        }
    }

    /// `onCurrentPageChange` — the last page that is at least partially visible drives progress.
    public func visiblePagesChanged(_ visible: Range<Int>) {
        guard let last = visible.last, let page = pages[safe: last], page.pageNumber != currentPageNumber else { return }
        currentPageNumber = page.pageNumber
        reader.onProgressChange(page: page.pageNumber)
        let ahead = ((visible.upperBound)..<(visible.upperBound + 3)).compactMap { pages[safe: $0]?.id }
        Task { await reader.pages.prefetch(ahead) }
    }

    public func scroll(toPage page: Int) {
        pendingScrollPage = page
        layoutVersion += 1
    }

    // MARK: Settings

    public func setReadingDirection(_ direction: ContinuousReadingDirection) {
        readingDirection = direction
        reader.update { $0.continuousReadingDirection = direction }
        scroll(toPage: currentPageNumber)
    }

    public func setSidePadding(_ fraction: CGFloat) {
        sidePaddingFraction = min(max(fraction, 0), 0.45)
        reader.update { [value = Float(sidePaddingFraction)] in $0.continuousPadding = value }
        scroll(toPage: currentPageNumber)
    }

    public func setPageSpacing(_ spacing: CGFloat) {
        pageSpacing = min(max(spacing, 0), 500)
        reader.update { [value = Int(pageSpacing)] in $0.continuousPageSpacing = value }
        scroll(toPage: currentPageNumber)
    }

    public func reloadImages() {
        bookDidChange()
    }
}
