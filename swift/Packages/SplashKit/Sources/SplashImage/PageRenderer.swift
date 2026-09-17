import CoreGraphics
import Foundation
import ImageIO

/// How a page's pixels are produced (Strategy): raster images are decoded with ImageIO, PDF pages are
/// rasterized from vectors with Core Graphics — so PDF text stays sharp at any zoom (plan Phase 14).
protocol PageRenderer: Sendable {
    /// Natural size in pixels (PDF: points at 2× so fit/original layouts look like a ~144 dpi page).
    var naturalSize: CGSize { get }
    /// Renders the whole page so that its longest side is `maxPixelSize`.
    func render(maxPixelSize: Int) -> CGImage?
    /// Small rendering for border analysis.
    func thumbnail() -> CGImage?
}

struct RasterPageRenderer: PageRenderer, @unchecked Sendable {
    let source: CGImageSource  // immutable after creation; ImageIO sources are thread-safe for reads
    let naturalSize: CGSize

    func render(maxPixelSize: Int) -> CGImage? {
        ReaderImageDecoder.decode(source: source, maxPixelSize: maxPixelSize)
    }

    func thumbnail() -> CGImage? {
        ReaderImageDecoder.decode(source: source, maxPixelSize: 512)
    }
}

struct PDFPageRenderer: PageRenderer, @unchecked Sendable {
    static let pointsToPixels: CGFloat = 2
    let document: CGPDFDocument  // CGPDFDocument is immutable and thread-safe for drawing
    let pageNumber: Int
    let naturalSize: CGSize

    init?(data: Data, pageNumber: Int = 1) {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: pageNumber)
        else { return nil }
        self.document = document
        self.pageNumber = pageNumber
        let box = Self.displayBox(page)
        naturalSize = CGSize(width: box.width * Self.pointsToPixels, height: box.height * Self.pointsToPixels)
    }

    static func isPDF(_ data: Data) -> Bool {
        data.prefix(1024).range(of: Data("%PDF".utf8)) != nil
    }

    /// Crop box with rotation applied.
    private static func displayBox(_ page: CGPDFPage) -> CGSize {
        let box = page.getBoxRect(.cropBox)
        let rotated = page.rotationAngle % 180 != 0
        return rotated ? CGSize(width: box.height, height: box.width) : box.size
    }

    func render(maxPixelSize: Int) -> CGImage? {
        guard let page = document.page(at: pageNumber) else { return nil }
        let size = Self.displayBox(page)
        let scale = CGFloat(maxPixelSize) / max(size.width, size.height)
        let width = max(Int((size.width * scale).rounded()), 1)
        let height = max(Int((size.height * scale).rounded()), 1)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        // PDFs have transparent backgrounds; paper is white.
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        // Scale first, then map the (rotated) crop box onto a point-sized rect: getDrawingTransform never
        // scales up, and applying the scale after its centering translation would push the page off-canvas.
        context.scaleBy(x: CGFloat(width) / size.width, y: CGFloat(height) / size.height)
        let transform = page.getDrawingTransform(
            .cropBox, rect: CGRect(origin: .zero, size: size), rotate: 0, preserveAspectRatio: true)
        context.concatenate(transform)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    func thumbnail() -> CGImage? { render(maxPixelSize: 512) }
}
