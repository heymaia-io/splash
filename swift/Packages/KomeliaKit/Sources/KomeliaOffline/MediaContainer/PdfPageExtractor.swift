import CoreGraphics
import Foundation
import Synchronization

/// [NUEVO] Offline pages of PDF books. Kotlin left `MediaProfile.PDF -> TODO()`. Komga's
/// `GET /books/{id}/pages/{n}` returns a *single-page PDF* for PDF books, and the reader renders any `%PDF`
/// payload with CGPDFDocument. So offline returns the same thing: page `n` copied into a new one-page PDF.
public final class PdfPageExtractor: Sendable {
    private struct CachedDocument: @unchecked Sendable {  // only touched while holding the lock
        let url: URL
        let document: CGPDFDocument
    }

    private let cache = Mutex<CachedDocument?>(nil)

    public init() {}

    public func pageCount(file: URL) throws -> Int {
        try cache.withLock { cached in try Self.document(file, &cached).numberOfPages }
    }

    /// `page` is 1-based.
    public func singlePagePDF(file: URL, page: Int) throws -> Data {
        try cache.withLock { cached in
            let document = try Self.document(file, &cached)
            guard let pdfPage = document.page(at: page) else {
                throw OfflineError.invalidArgument("Page \(page) does not exist")
            }
            return try Self.render(pdfPage)
        }
    }

    private static func document(_ file: URL, _ cached: inout CachedDocument?) throws -> CGPDFDocument {
        let url = file.standardizedFileURL
        if let cached, cached.url == url { return cached.document }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw OfflineError.fileUnavailable(url.path(percentEncoded: false))
        }
        guard let document = CGPDFDocument(url as CFURL) else {
            throw OfflineError.invalidState("Cannot open PDF \(url.lastPathComponent)")
        }
        cached = CachedDocument(url: url, document: document)
        return document
    }

    /// Draws the page (honouring its `/Rotate`) into a fresh PDF context of the page's visible size.
    private static func render(_ page: CGPDFPage) throws -> Data {
        let cropBox = page.getBoxRect(.cropBox)
        let quarterTurns = ((page.rotationAngle % 360) + 360) % 360 / 90
        var mediaBox = CGRect(
            origin: .zero,
            size: quarterTurns % 2 == 1 ? CGSize(width: cropBox.height, height: cropBox.width) : cropBox.size)

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw OfflineError.invalidState("Cannot create PDF context") }

        context.beginPDFPage(nil)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: mediaBox, rotate: 0, preserveAspectRatio: true))
        context.clip(to: cropBox)
        context.drawPDFPage(page)
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }
}
