import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SplashImage

@Suite struct ReaderImageTests {
    /// Page with a white border of `border` px around a red rectangle.
    static func page(width: Int, height: Int, border: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: border, y: border, width: width - 2 * border, height: height - 2 * border))
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, context.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    let id = PageId(bookId: "B", pageNumber: 1)

    @Test func adaptiveDecodingNeverExceedsNeedOrOriginal() async throws {
        let image = try ReaderImageFactory().makeImage(
            pageId: id, data: Self.page(width: 2000, height: 3000, border: 0), cropBorders: false)
        #expect(image.originalSize == CGSize(width: 2000, height: 3000))

        let small = try #require(await image.bitmap(forDisplayedPixels: CGSize(width: 400, height: 600)))
        #expect(max(small.pixelSize.width, small.pixelSize.height) <= 768)

        let big = try #require(await image.bitmap(forDisplayedPixels: CGSize(width: 8000, height: 12000)))
        #expect(big.pixelSize == CGSize(width: 2000, height: 3000))
    }

    @Test func cropBordersFindsContent() async throws {
        let image = try ReaderImageFactory().makeImage(
            pageId: id, data: Self.page(width: 1000, height: 1500, border: 100), cropBorders: true)
        let rect = image.contentRect
        #expect(abs(rect.minX - 100) <= 6 && abs(rect.minY - 100) <= 6)
        #expect(abs(rect.width - 800) <= 12 && abs(rect.height - 1300) <= 12)
        let bitmap = try #require(await image.bitmap(forDisplayedPixels: CGSize(width: 800, height: 1300)))
        #expect(abs(bitmap.pixelSize.width / bitmap.pixelSize.height - 800.0 / 1300.0) < 0.02)
    }

    @Test func noBorderMeansNoCrop() throws {
        let image = try ReaderImageFactory().makeImage(
            pageId: id, data: Self.page(width: 600, height: 900, border: 0), cropBorders: true)
        #expect(image.contentRect == CGRect(x: 0, y: 0, width: 600, height: 900))
    }

    @Test func fitLayout() {
        #expect(ReaderLayout.fit(CGSize(width: 100, height: 200), in: CGSize(width: 1000, height: 1000), stretch: false)
                == CGSize(width: 100, height: 200))
        #expect(ReaderLayout.fit(CGSize(width: 100, height: 200), in: CGSize(width: 1000, height: 1000), stretch: true)
                == CGSize(width: 500, height: 1000))
        #expect(ReaderLayout.fit(CGSize(width: 2000, height: 1000), in: CGSize(width: 1000, height: 1000), stretch: false)
                == CGSize(width: 1000, height: 500))
    }

    @Test func undecodableDataThrows() {
        #expect(throws: ReaderImageError.self) {
            _ = try ReaderImageFactory().makeImage(pageId: id, data: Data("nope".utf8), cropBorders: false)
        }
    }
}

@Suite struct PDFReaderImageTests {
    /// Two-page PDF: US Letter with a grey box inset 72pt.
    static func pdf(pages: Int = 2) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 0.3, alpha: 1))
            context.fill(box.insetBy(dx: 72, dy: 72))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    let id = PageId(bookId: "P", pageNumber: 1)

    @Test func pdfPagesRenderAtRequestedResolutionBeyondNaturalSize() async throws {
        let image = try ReaderImageFactory().makeImage(pageId: id, data: Self.pdf(), cropBorders: false, pdfPage: 2)
        #expect(image.isVector)
        #expect(image.originalSize == CGSize(width: 1224, height: 1584))
        let zoomed = try #require(await image.bitmap(forDisplayedPixels: CGSize(width: 3000, height: 3900)))
        #expect(zoomed.pixelSize.height > 1584)  // vectors can exceed natural size
        #expect(abs(zoomed.pixelSize.width / zoomed.pixelSize.height - 612.0 / 792.0) < 0.01)
        // The grey box must actually be drawn (regression: page rendered off-canvas → all white).
        #expect(Self.centerGray(zoomed.image) < 0.5)
    }

    static func centerGray(_ image: CGImage) -> Double {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return Double(pixel[0]) / 255
    }

    @Test func pdfCropBordersRemovesWhiteMargin() throws {
        let image = try ReaderImageFactory().makeImage(pageId: id, data: Self.pdf(pages: 1), cropBorders: true)
        let rect = image.contentRect
        #expect(abs(rect.minX - 144) < 8)  // 72pt × 2
        #expect(abs(rect.width - (1224 - 288)) < 12)
    }

    @Test func missingPdfPageThrows() {
        #expect(throws: ReaderImageError.self) {
            _ = try ReaderImageFactory().makeImage(pageId: id, data: Self.pdf(pages: 1), cropBorders: false, pdfPage: 5)
        }
    }
}
