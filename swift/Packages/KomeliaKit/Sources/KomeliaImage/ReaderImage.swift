import CoreGraphics
import Foundation
import ImageIO

/// Decoded page bitmap. `CGImage` is immutable, so it is safe to hand across actors.
public struct PageBitmap: @unchecked Sendable {
    public let image: CGImage
    public var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }
}

/// Port of the `ReaderImage` contract (`TilingReaderImage.kt` / platform actuals).
///
/// DEVIATION ([NUEVO], plan Phase 8): libvips + explicit tiling is replaced by *resolution-adaptive decoding*
/// with ImageIO: the page is decoded at the size it is displayed at (screen pixels × zoom), capped at
/// `maxDecodeDimension`, and re-decoded when zoom asks for more detail. ImageIO's subsampled JPEG decoding
/// keeps peak memory at the displayed size, which is what the Kotlin tiling thresholds (2048²/4096²/6144²)
/// were protecting against.
public actor ReaderImage {
    public static let maxDecodeDimension = 6144

    public let pageId: PageId
    public nonisolated let originalSize: CGSize
    /// Crop rectangle in original pixel coordinates (whole image when trimming is off/not found).
    public nonisolated let contentRect: CGRect

    private let renderer: any PageRenderer
    private var current: PageBitmap?
    private var currentMaxDimension = 0

    init(pageId: PageId, renderer: any PageRenderer, contentRect: CGRect) {
        self.pageId = pageId
        self.renderer = renderer
        self.originalSize = renderer.naturalSize
        self.contentRect = contentRect
    }

    /// True for vector (PDF) pages, which may be rendered beyond their natural size when zoomed.
    public nonisolated var isVector: Bool { renderer is PDFPageRenderer }

    /// Size of the visible content (after border crop).
    public nonisolated var contentSize: CGSize { contentRect.size }

    /// `requestUpdate(visibleDisplaySize, zoomFactor, maxDisplaySize)` collapsed to "how many pixels does the
    /// longest side need". Returns the cached bitmap when it is already detailed enough.
    public func bitmap(forDisplayedPixels needed: CGSize) -> PageBitmap? {
        let scale = max(needed.width / max(contentSize.width, 1), needed.height / max(contentSize.height, 1))
        let fullLongest = max(originalSize.width, originalSize.height)
        // Raster pages never exceed their pixels; vector pages can be rendered larger for sharp zoom.
        let limit = isVector ? CGFloat(Self.maxDecodeDimension) : fullLongest
        var target = Int((fullLongest * min(scale, limit / fullLongest)).rounded(.up))
        // Round up to buckets of 256 px to avoid re-rendering for tiny zoom changes.
        target = min(((target + 255) / 256) * 256, Self.maxDecodeDimension, Int(limit))
        if let current, currentMaxDimension >= target { return current }

        guard let decoded = renderer.render(maxPixelSize: max(target, 64)) else {
            return current
        }
        let cropped = ReaderImageDecoder.crop(decoded, to: contentRect, originalSize: originalSize)
        current = PageBitmap(image: cropped)
        currentMaxDimension = target
        return current
    }

    /// Lets memory go when the page leaves the cache window (`image.close()`).
    public func releaseBitmap() {
        current = nil
        currentMaxDimension = 0
    }

    /// Fit-size computation (`calculateSizeForArea(maxPageSize, stretchToFit)`).
    public nonisolated func displaySize(fitting area: CGSize, stretchToFit: Bool) -> CGSize {
        ReaderLayout.fit(contentSize, in: area, stretch: stretchToFit)
    }
}

public enum ReaderLayout {
    /// Aspect-fit `size` into `area`; never upscales unless `stretch` is true.
    public static func fit(_ size: CGSize, in area: CGSize, stretch: Bool) -> CGSize {
        guard size.width > 0, size.height > 0, area.width > 0, area.height > 0 else { return .zero }
        var scale = min(area.width / size.width, area.height / size.height)
        if !stretch { scale = min(scale, 1) }
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }
}

/// Port of `ReaderImageFactory` + `ImageProcessingPipeline` (crop-borders step; color correction is applied
/// separately by the view layer when enabled).
public struct ReaderImageFactory: Sendable {
    public init() {}

    /// Accepts encoded images (JPEG/PNG/WebP/HEIC/…) and single- or multi-page PDF data (`pdfPage`).
    public func makeImage(pageId: PageId, data: Data, cropBorders: Bool, pdfPage: Int = 1) throws -> ReaderImage {
        let renderer = try Self.renderer(for: data, pageId: pageId, pdfPage: pdfPage)
        let size = renderer.naturalSize
        var rect = CGRect(origin: .zero, size: size)
        if cropBorders, let thumb = renderer.thumbnail(),
           let trim = ReaderImageDecoder.findTrim(in: thumb, originalSize: size) {
            rect = trim
        }
        return ReaderImage(pageId: pageId, renderer: renderer, contentRect: rect)
    }

    private static func renderer(for data: Data, pageId: PageId, pdfPage: Int) throws -> any PageRenderer {
        if PDFPageRenderer.isPDF(data) {
            guard let pdf = PDFPageRenderer(data: data, pageNumber: pdfPage) else {
                throw ReaderImageError.undecodable(pageId)
            }
            return pdf
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let size = ReaderImageDecoder.pixelSize(of: source)
        else { throw ReaderImageError.undecodable(pageId) }
        return RasterPageRenderer(source: source, naturalSize: size)
    }
}

public enum ReaderImageError: Error, CustomStringConvertible {
    case undecodable(PageId)
    public var description: String {
        switch self {
        case .undecodable(let id): "Page \(id.pageNumber) could not be decoded"
        }
    }
}
