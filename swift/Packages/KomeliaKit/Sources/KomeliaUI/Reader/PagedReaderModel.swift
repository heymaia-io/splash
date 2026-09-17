import CoreGraphics
import Foundation
import KomeliaCore
import KomeliaImage
import KomgaAPI
import Observation

/// Screen shown past the first/last page (`TransitionPage.BookStart` / `BookEnd`).
public enum TransitionPage: Equatable {
    case bookStart(current: KomeliaBook, previous: KomeliaBook?)
    case bookEnd(current: KomeliaBook, next: KomeliaBook?)
}

/// A loaded page of the current spread.
public struct LoadedPage: Identifiable {
    public let metadata: PageMetadata
    public let image: ReaderImage?
    public let error: Error?
    public var id: PageId { metadata.id }
}

/// Port of `PagedReaderState.kt` (spread map verbatim, 10-page image cache, transition pages).
@MainActor
@Observable
public final class PagedReaderModel {
    public private(set) var spreads: [[PageMetadata]] = []
    public private(set) var currentSpreadIndex = 0
    public private(set) var currentSpread: [LoadedPage] = []
    public private(set) var transitionPage: TransitionPage?
    public private(set) var layout: PageDisplayLayout
    public private(set) var layoutOffset = false
    public private(set) var scaleType: LayoutScaleType
    public private(set) var readingDirection: PagedReadingDirection
    /// Bumped on every page turn (drives the e-ink style flash overlay and zoom reset).
    public private(set) var pageChangeCounter = 0

    let reader: ReaderViewModel
    private var imageCache: [PageId: ReaderImage] = [:]
    private var cacheOrder: [PageId] = []
    private static let cacheSize = 10
    private var loadTask: Task<Void, Never>?

    public init(reader: ReaderViewModel) {
        self.reader = reader
        let settings = reader.settings.value
        layout = settings.pagedPageLayout
        scaleType = settings.pagedScaleType
        readingDirection = Self.direction(for: reader.series?.metadata.readingDirection, fallback: settings.pagedReadingDirection)
    }

    nonisolated static func direction(for series: KomgaReadingDirection?, fallback: PagedReadingDirection)
        -> PagedReadingDirection
    {
        switch series {
        case .leftToRight: .leftToRight
        case .rightToLeft: .rightToLeft
        default: fallback
        }
    }

    public var currentPageNumber: Int { spreads[safe: currentSpreadIndex]?.last?.pageNumber ?? 1 }
    public var pageCount: Int { reader.books?.currentBookPages.count ?? 0 }

    /// `onNewBookLoaded` — call after the reader loads/changes book.
    public func bookDidChange() {
        guard let books = reader.books else { return }
        spreads = Self.buildSpreadMap(books.currentBookPages, layout: layout, offset: layoutOffset)
        let index = spreads.firstIndex { $0.contains { $0.pageNumber == reader.readProgressPage } } ?? 0
        currentSpreadIndex = index
        transitionPage = nil
        load(spreadIndex: index, reportProgress: false)
    }

    // MARK: Navigation (`nextPage` / `previousPage`)

    public func nextPage() {
        if currentSpreadIndex < spreads.count - 1 {
            if transitionPage != nil { transitionPage = nil } else { goTo(spreadIndex: currentSpreadIndex + 1) }
        } else if transitionPage == nil {
            guard let books = reader.books else { return }
            transitionPage = .bookEnd(current: books.currentBook, next: books.nextBook)
        } else if case .bookEnd(_, let next) = transitionPage {
            // Past the last book: ask the reader to exit to the series (Kotlin replaces the screen).
            Task {
                currentSpread = []
                transitionPage = nil
                await reader.loadNextBook()
                if next != nil { bookDidChange() }
            }
        }
    }

    public func previousPage() {
        if currentSpreadIndex != 0 {
            if transitionPage != nil { transitionPage = nil } else { goTo(spreadIndex: currentSpreadIndex - 1) }
        } else if transitionPage == nil {
            guard let books = reader.books else { return }
            transitionPage = .bookStart(current: books.currentBook, previous: books.previousBook)
        } else if case .bookStart(_, let previous) = transitionPage, previous != nil {
            Task {
                currentSpread = []
                transitionPage = nil
                await reader.loadPreviousBook()
                bookDidChange()
            }
        }
    }

    /// Tap zones: three equal columns; left/right mean previous/next according to the reading direction
    /// (not the physical side). Returns true when the center column was hit (toggle settings overlay).
    public func handleTap(atX x: CGFloat, width: CGFloat) -> Bool {
        let column = Int((x / max(width, 1)) * 3)
        switch (column, readingDirection) {
        case (0, .leftToRight), (2..., .rightToLeft): previousPage()
        case (0, .rightToLeft), (2..., .leftToRight): nextPage()
        default: return true
        }
        return false
    }

    public func goTo(pageNumber: Int) {
        guard let index = spreads.firstIndex(where: { $0.contains { $0.pageNumber == pageNumber } }) else { return }
        goTo(spreadIndex: index)
    }

    func goTo(spreadIndex: Int) {
        guard spreads.indices.contains(spreadIndex), spreadIndex != currentSpreadIndex else { return }
        load(spreadIndex: spreadIndex, reportProgress: true)
    }

    // MARK: Settings

    public func setLayout(_ layout: PageDisplayLayout) {
        self.layout = layout
        reader.update { $0.pagedPageLayout = layout }
        rebuildKeepingPage()
    }

    public func toggleLayoutOffset() {
        layoutOffset.toggle()
        rebuildKeepingPage()
    }

    public func setScaleType(_ type: LayoutScaleType) {
        scaleType = type
        reader.update { $0.pagedScaleType = type }
    }

    public func setReadingDirection(_ direction: PagedReadingDirection) {
        readingDirection = direction
        reader.update { $0.pagedReadingDirection = direction }
    }

    /// Crop-borders changes invalidate decoded images.
    public func reloadImages() {
        imageCache.removeAll()
        cacheOrder.removeAll()
        load(spreadIndex: currentSpreadIndex, reportProgress: false)
    }

    private func rebuildKeepingPage() {
        let page = currentSpread.first?.metadata.pageNumber ?? reader.readProgressPage
        guard let books = reader.books else { return }
        spreads = Self.buildSpreadMap(books.currentBookPages, layout: layout, offset: layoutOffset)
        let index = spreads.firstIndex { $0.contains { $0.pageNumber == page } } ?? 0
        currentSpreadIndex = index
        load(spreadIndex: index, reportProgress: false)
    }

    // MARK: Loading (`loadPage` / `loadSpread`)

    private func load(spreadIndex: Int, reportProgress: Bool) {
        guard spreads.indices.contains(spreadIndex) else { return }
        if spreadIndex != currentSpreadIndex || reportProgress {
            currentSpreadIndex = spreadIndex
            pageChangeCounter += 1
            if let last = spreads[spreadIndex].last { reader.onProgressChange(page: last.pageNumber) }
        }
        let metadata = spreads[spreadIndex]
        // Show placeholders immediately (Kotlin shows them after 10ms if loading is slow).
        currentSpread = metadata.map { meta in
            LoadedPage(metadata: meta, image: imageCache[meta.id], error: nil)
        }
        transitionPage = nil

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let loaded = await self.loadPages(metadata)
            guard !Task.isCancelled, self.currentSpreadIndex == spreadIndex else { return }
            self.currentSpread = loaded
            // Warm neighbouring spreads (`getSpreadLoadRange`).
            let neighbours = [spreadIndex - 1, spreadIndex + 1, spreadIndex + 2]
                .filter { self.spreads.indices.contains($0) }
                .flatMap { self.spreads[$0] }
            await self.reader.pages.prefetch(neighbours.map(\.id))
        }
    }

    private func loadPages(_ metadata: [PageMetadata]) async -> [LoadedPage] {
        var result: [LoadedPage] = []
        for meta in metadata {
            if let cached = imageCache[meta.id] {
                result.append(LoadedPage(metadata: meta, image: cached, error: nil))
                continue
            }
            do {
                let data = try await reader.pages.data(for: meta.id)
                let crop = reader.settings.value.cropBorders
                let factory = reader.imageFactory
                let image = try await Task.detached(priority: .userInitiated) {
                    try factory.makeImage(pageId: meta.id, data: data, cropBorders: crop)
                }.value
                cache(image, for: meta.id)
                result.append(LoadedPage(metadata: meta, image: image, error: nil))
            } catch {
                result.append(LoadedPage(metadata: meta, image: nil, error: error))
            }
        }
        return result
    }

    private func cache(_ image: ReaderImage, for id: PageId) {
        imageCache[id] = image
        cacheOrder.removeAll { $0 == id }
        cacheOrder.append(id)
        while cacheOrder.count > Self.cacheSize {
            let evicted = cacheOrder.removeFirst()
            if let old = imageCache.removeValue(forKey: evicted) { Task { await old.releaseBitmap() } }
        }
    }

    // MARK: Spread map (verbatim port of buildSpreadMap / buildSpreadMapForDoublePages)

    nonisolated static func buildSpreadMap(_ pages: [PageMetadata], layout: PageDisplayLayout, offset: Bool)
        -> [[PageMetadata]]
    {
        switch layout {
        case .singlePage: pages.map { [$0] }
        case .doublePages: doublePageSpreads(pages, withCover: true, offset: offset)
        case .doublePagesNoCover: doublePageSpreads(pages, withCover: false, offset: offset)
        }
    }

    private nonisolated static func doublePageSpreads(_ pages: [PageMetadata], withCover: Bool, offset: Bool)
        -> [[PageMetadata]]
    {
        guard !pages.isEmpty else { return [] }
        // Segments of portrait pages separated by landscape (already double) pages.
        var segments: [(single: [PageMetadata], landscape: PageMetadata?)] = []
        var toProcess = pages[...]
        if withCover {
            segments.append(([pages[0]], nil))
            toProcess = pages.dropFirst()
        }
        var current: [PageMetadata] = []
        for page in toProcess {
            if page.isLandscape {
                segments.append((current, page))
                current = []
            } else {
                current.append(page)
            }
        }
        if !current.isEmpty { segments.append((current, nil)) }

        var spreads: [[PageMetadata]] = []
        for segment in segments {
            if offset {
                if let first = segment.single.first { spreads.append([first]) }
                spreads.append(contentsOf: segment.single.dropFirst().chunked(2))
            } else {
                spreads.append(contentsOf: segment.single.chunked(2))
            }
            if let landscape = segment.landscape { spreads.append([landscape]) }
        }
        return spreads
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }

    func chunked(_ size: Int) -> [[Element]] {
        var result: [[Element]] = []
        var chunk: [Element] = []
        for element in self {
            chunk.append(element)
            if chunk.count == size {
                result.append(chunk)
                chunk = []
            }
        }
        if !chunk.isEmpty { result.append(chunk) }
        return result
    }
}
