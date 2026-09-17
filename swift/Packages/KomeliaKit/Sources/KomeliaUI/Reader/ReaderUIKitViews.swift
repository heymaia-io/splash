#if canImport(UIKit)
import KomeliaCore
import KomeliaImage
import SwiftUI
import UIKit

// MARK: - Paged

/// Zoomable spread (`ScalableContainer` + `ScreenScaleState` for the paged reader). UIScrollView gives pinch,
/// pan, bounce and deceleration natively; after zooming, pages are re-decoded at the new resolution.
final class SpreadScrollView: UIScrollView, UIScrollViewDelegate {
    private let container = UIView()
    private var imageViews: [UIImageView] = []
    private var pages: [LoadedPage] = []
    private var configuration: Configuration?
    var onTap: ((CGPoint) -> Void)?

    struct Configuration: Equatable {
        var scaleType: LayoutScaleType
        var stretchToFit: Bool
        var rightToLeft: Bool
        var pageIds: [PageId]
        var contentSizes: [CGSize]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        addSubview(container)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(pages: [LoadedPage], scaleType: LayoutScaleType, stretchToFit: Bool, rightToLeft: Bool) {
        let sizes = pages.map { $0.image?.contentSize ?? $0.metadata.size ?? .zero }
        let config = Configuration(
            scaleType: scaleType, stretchToFit: stretchToFit, rightToLeft: rightToLeft,
            pageIds: pages.map(\.id), contentSizes: sizes)
        let pagesChanged = config.pageIds != configuration?.pageIds
        self.pages = pages
        guard config != configuration || imageViews.count != pages.count else {
            refreshBitmaps()
            return
        }
        configuration = config
        if pagesChanged { zoomScale = 1 }
        rebuild()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if container.bounds.size == .zero || lastLaidOutBounds != bounds.size {
            lastLaidOutBounds = bounds.size
            rebuild()
        }
        centerContent()
    }

    private var lastLaidOutBounds: CGSize = .zero

    private func rebuild() {
        guard let config = configuration, bounds.width > 0 else { return }
        zoomScale = 1
        let sizes = SpreadLayout.pageSizes(
            contentSizes: config.contentSizes, area: bounds.size, scaleType: config.scaleType,
            stretchToFit: config.stretchToFit, screenScale: window?.screen.scale ?? 2)
        let (content, frames) = SpreadLayout.frames(for: sizes, rightToLeft: config.rightToLeft)

        imageViews.forEach { $0.removeFromSuperview() }
        imageViews = frames.map { frame in
            let view = UIImageView(frame: frame)
            view.contentMode = .scaleAspectFit
            view.backgroundColor = .clear
            container.addSubview(view)
            return view
        }
        container.frame = CGRect(origin: .zero, size: content)
        contentSize = content
        // Initial position: top edge; horizontally the reading-direction start (`addPan` to limits).
        let x = config.rightToLeft ? max(content.width - bounds.width, 0) : 0
        contentOffset = CGPoint(x: x, y: 0)
        centerContent()
        refreshBitmaps()
    }

    private func centerContent() {
        let insetX = max((bounds.width - contentSize.width) / 2, 0)
        let insetY = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    /// `updateSpreadImageState` → ask each image for enough pixels at the current zoom.
    private func refreshBitmaps() {
        let screenScale = window?.screen.scale ?? 2
        for (index, page) in pages.enumerated() {
            guard let image = page.image, imageViews.indices.contains(index) else {
                if imageViews.indices.contains(index) { imageViews[index].image = nil }
                continue
            }
            let view = imageViews[index]
            let needed = CGSize(
                width: view.bounds.width * zoomScale * screenScale,
                height: view.bounds.height * zoomScale * screenScale)
            Task { @MainActor [weak view] in
                guard let bitmap = await image.bitmap(forDisplayedPixels: needed) else { return }
                view?.image = UIImage(cgImage: bitmap.image)
            }
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { container }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        refreshBitmaps()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?(gesture.location(in: superview ?? self))
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.01 {
            setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: container)
            let size = CGSize(width: bounds.width / 2.5, height: bounds.height / 2.5)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                            width: size.width, height: size.height), animated: true)
        }
    }
}

struct PagedSpreadView: UIViewRepresentable {
    let pages: [LoadedPage]
    let scaleType: LayoutScaleType
    let stretchToFit: Bool
    let rightToLeft: Bool
    let onTap: (CGPoint, CGFloat) -> Void

    func makeUIView(context: Context) -> SpreadScrollView {
        SpreadScrollView(frame: .zero)
    }

    func updateUIView(_ view: SpreadScrollView, context: Context) {
        view.onTap = { [weak view] point in onTap(point, view?.bounds.width ?? 1) }
        view.update(pages: pages, scaleType: scaleType, stretchToFit: stretchToFit, rightToLeft: rightToLeft)
    }
}

// MARK: - Continuous

/// Zoomable strip with manual virtualization. Zoom and scroll share one UIScrollView — the reason Kotlin routes
/// both through `ScreenScaleState` instead of a LazyList.
final class StripScrollView: UIScrollView, UIScrollViewDelegate {
    private let container = UIView()
    private var pageViews: [Int: UIImageView] = [:]
    private var frames: [CGRect] = []
    private var model: ContinuousReaderModel?
    private var builtVersion = -1
    private var builtSize: CGSize = .zero
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        contentInsetAdjustmentBehavior = .never
        addSubview(container)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: ContinuousReaderModel) {
        self.model = model
        if builtVersion != model.layoutVersion { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let model, bounds.width > 0 else { return }
        if builtVersion != model.layoutVersion || builtSize != bounds.size {
            rebuild(model)
        }
        updateVisiblePages()
    }

    private func rebuild(_ model: ContinuousReaderModel) {
        let anchorPage = model.consumePendingScroll() ?? model.currentPageNumber
        builtVersion = model.layoutVersion
        builtSize = bounds.size
        zoomScale = 1
        frames = model.layoutFrames(viewport: bounds.size)
        let end = frames.last.map { model.isVertical ? $0.maxY : $0.maxX } ?? 0
        let content = model.isVertical
            ? CGSize(width: bounds.width, height: end)
            : CGSize(width: end, height: bounds.height)
        container.frame = CGRect(origin: .zero, size: content)
        contentSize = content
        pageViews.values.forEach { $0.removeFromSuperview() }
        pageViews.removeAll()
        scroll(toPage: anchorPage, model: model)
    }

    private func scroll(toPage page: Int, model: ContinuousReaderModel) {
        guard let frame = frames[safe: page - 1] else { return }
        if model.isVertical {
            contentOffset = CGPoint(x: 0, y: min(frame.minY, max(contentSize.height - bounds.height, 0)))
        } else if model.readingDirection == .rightToLeft {
            // Right-to-left strips are laid out mirrored: page 1 at the far right.
            contentOffset = CGPoint(x: max(mirroredX(frame).minX, 0), y: 0)
        } else {
            contentOffset = CGPoint(x: min(frame.minX, max(contentSize.width - bounds.width, 0)), y: 0)
        }
    }

    private func mirroredX(_ frame: CGRect) -> CGRect {
        CGRect(x: contentSize.width / max(zoomScale, 0.01) - frame.maxX, y: frame.minY,
               width: frame.width, height: frame.height)
    }

    private func displayFrame(_ index: Int) -> CGRect {
        guard let model, model.readingDirection == .rightToLeft else { return frames[index] }
        return CGRect(x: container.bounds.width - frames[index].maxX, y: frames[index].minY,
                      width: frames[index].width, height: frames[index].height)
    }

    private func updateVisiblePages() {
        guard let model, !frames.isEmpty else { return }
        let visibleRect = CGRect(
            x: contentOffset.x / zoomScale, y: contentOffset.y / zoomScale,
            width: bounds.width / zoomScale, height: bounds.height / zoomScale)
        let preload = visibleRect.insetBy(
            dx: model.isVertical ? 0 : -visibleRect.width, dy: model.isVertical ? -visibleRect.height : 0)

        var visible: [Int] = []
        var wanted = Set<Int>()
        for index in frames.indices {
            let frame = displayFrame(index)
            if frame.intersects(preload) { wanted.insert(index) }
            if frame.intersects(visibleRect) { visible.append(index) }
        }
        for (index, view) in pageViews where !wanted.contains(index) {
            view.removeFromSuperview()
            pageViews[index] = nil
        }
        let screenScale = window?.screen.scale ?? 2
        for index in wanted.sorted() where pageViews[index] == nil {
            let view = UIImageView(frame: displayFrame(index))
            view.contentMode = .scaleAspectFit
            view.backgroundColor = UIColor.secondarySystemBackground
            container.addSubview(view)
            pageViews[index] = view
            let page = model.pages[index]
            let needed = CGSize(width: view.bounds.width * screenScale * zoomScale,
                                height: view.bounds.height * screenScale * zoomScale)
            Task { @MainActor [weak view, weak model] in
                guard let image = await model?.image(for: page),
                      let bitmap = await image.bitmap(forDisplayedPixels: needed) else { return }
                view?.backgroundColor = .clear
                view?.image = UIImage(cgImage: bitmap.image)
            }
        }
        if let first = visible.first, let last = visible.last {
            // Reading order: RTL strips list later pages to the left, so visible indices are still ascending.
            model.visiblePagesChanged(first..<(last + 1))
            model.release(outside: first..<(last + 1))
        }
    }

    private func refreshVisibleResolution() {
        guard let model else { return }
        let screenScale = window?.screen.scale ?? 2
        for (index, view) in pageViews {
            let page = model.pages[index]
            let needed = CGSize(width: view.bounds.width * screenScale * zoomScale,
                                height: view.bounds.height * screenScale * zoomScale)
            Task { @MainActor [weak view, weak model] in
                guard let image = await model?.image(for: page),
                      let bitmap = await image.bitmap(forDisplayedPixels: needed) else { return }
                view?.image = UIImage(cgImage: bitmap.image)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { updateVisiblePages() }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { container }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        refreshVisibleResolution()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?(gesture.location(in: superview ?? self))
    }

    /// Screen-sized step (`scrollScreenForward/Backward`).
    func page(forward: Bool) {
        guard let model else { return }
        var offset = contentOffset
        if model.isVertical {
            let step = bounds.height * 0.9 * (forward ? 1 : -1)
            offset.y = min(max(offset.y + step, 0), max(contentSize.height - bounds.height, 0))
        } else {
            let sign: CGFloat = (model.readingDirection == .rightToLeft) != forward ? 1 : -1
            let step = bounds.width * 0.9 * -sign
            offset.x = min(max(offset.x + step, 0), max(contentSize.width - bounds.width, 0))
        }
        setContentOffset(offset, animated: true)
    }
}

struct ContinuousStripView: UIViewRepresentable {
    let model: ContinuousReaderModel
    let stepRequest: StepRequest?
    let onTap: (CGPoint, CGFloat) -> Void

    struct StepRequest: Equatable {
        let id: Int
        let forward: Bool
    }

    final class Coordinator {
        var lastStep: Int?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> StripScrollView { StripScrollView(frame: .zero) }

    func updateUIView(_ view: StripScrollView, context: Context) {
        _ = model.layoutVersion  // observe
        view.onTap = { [weak view] point in onTap(point, view?.bounds.width ?? 1) }
        view.bind(model)
        if let stepRequest, stepRequest.id != context.coordinator.lastStep {
            context.coordinator.lastStep = stepRequest.id
            view.page(forward: stepRequest.forward)
        }
    }
}
#endif
