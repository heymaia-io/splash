import Foundation
import KomgaAPI
import Synchronization
import ZIPFoundation

/// Port of `snd.komelia.offline.mediacontainer.DivinaExtractor` (strategy per container media type).
public protocol DivinaExtractor: Sendable {
    var mediaTypes: [String] { get }
    func entryBytes(file: URL, entryName: String) throws -> Data
}

/// Port of `EpubExtractor`.
public protocol EpubExtractor: Sendable {
    func entryBytes(file: URL, entryName: String) throws -> Data
}

/// Port of the jvm `ZipExtractor` / `DivinaZipExtractor` / `EpubZipExtractor` on ZIPFoundation.
///
/// [NUEVO] Kotlin reopened the archive (and re-parsed its central directory) for every page. Readers request pages
/// sequentially from the same book, so the last few opened archives are cached. ZIPFoundation's `Archive` is not
/// thread-safe; all access goes through the mutex.
public final class ZipEntryExtractor: DivinaExtractor, EpubExtractor {
    public let mediaTypes = ["application/zip"]

    private struct CachedArchive: @unchecked Sendable {  // only touched while holding `cache`'s lock
        let url: URL
        let modificationDate: Date?
        let archive: Archive
    }

    private let cache = Mutex<[CachedArchive]>([])
    private let capacity: Int

    public init(capacity: Int = 2) { self.capacity = max(1, capacity) }

    public func entryBytes(file: URL, entryName: String) throws -> Data {
        try cache.withLock { entries in
            let archive = try Self.archive(for: file, in: &entries, capacity: capacity)
            guard let entry = archive[entryName] else {
                throw OfflineError.notFound("zip entry does not exist: \(entryName)")
            }
            var data = Data(capacity: Int(clamping: entry.uncompressedSize))
            _ = try archive.extract(entry, skipCRC32: true) { data.append($0) }
            return data
        }
    }

    /// Drops cached handles (e.g. before deleting a file).
    public func evict(file: URL) {
        cache.withLock { entries in entries.removeAll { $0.url == file.standardizedFileURL } }
    }

    private static func archive(for file: URL, in entries: inout [CachedArchive], capacity: Int) throws -> Archive {
        let url = file.standardizedFileURL
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[
            .modificationDate] as? Date
        if let index = entries.firstIndex(where: { $0.url == url }) {
            let cached = entries.remove(at: index)
            if cached.modificationDate == modified {
                entries.insert(cached, at: 0)
                return cached.archive
            }
        }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw OfflineError.fileUnavailable(url.path(percentEncoded: false))
        }
        let archive = try Archive(url: url, accessMode: .read)
        entries.insert(CachedArchive(url: url, modificationDate: modified, archive: archive), at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
        return archive
    }
}

/// Port of `BookContentExtractors`: picks the extractor for a book's container and returns raw page bytes.
public struct BookContentExtractors: Sendable {
    private let divinaExtractors: [String: any DivinaExtractor]
    private let epubExtractor: (any EpubExtractor)?
    private let pdfExtractor: PdfPageExtractor?
    private let fileLocator: OfflineFileLocator

    public init(
        divinaExtractors: [any DivinaExtractor], epubExtractor: (any EpubExtractor)?,
        pdfExtractor: PdfPageExtractor?, fileLocator: OfflineFileLocator
    ) {
        var byType: [String: any DivinaExtractor] = [:]
        for extractor in divinaExtractors { for type in extractor.mediaTypes { byType[type] = extractor } }
        self.divinaExtractors = byType
        self.epubExtractor = epubExtractor
        self.pdfExtractor = pdfExtractor
        self.fileLocator = fileLocator
    }

    /// Default set: one shared ZIP extractor for CBZ and EPUB, Core Graphics for PDF (RAR is not supported).
    public static func standard(fileLocator: OfflineFileLocator) -> BookContentExtractors {
        let zip = ZipEntryExtractor()
        return BookContentExtractors(
            divinaExtractors: [zip], epubExtractor: zip, pdfExtractor: PdfPageExtractor(), fileLocator: fileLocator)
    }

    /// `getBookPage(book, media, page)` — `page` is 1-based.
    public func bookPage(book: OfflineBook, media: OfflineMedia, page: Int) throws -> Data {
        guard media.status == .ready else { throw OfflineError.invalidState("Media is not ready") }
        let file = fileLocator.fileURL(for: book.fileDownloadPath)
        switch media.mediaProfile {
        case .divina:
            return try divinaExtractor(for: media).entryBytes(file: file, entryName: try entryName(media, page))
        case .epub:
            guard media.epubDivinaCompatible else {
                throw OfflineError.invalidState("Epub profile does not support getting page content")
            }
            guard let epubExtractor else { throw OfflineError.invalidState("Epub content is not supported") }
            return try epubExtractor.entryBytes(file: file, entryName: try entryName(media, page))
        case .pdf:
            // [NUEVO] replaces Kotlin's TODO(): a one-page PDF, like the server's page endpoint.
            guard let pdfExtractor else { throw KomgaAPIError.unsupported("PDF pages are not supported") }
            guard page >= 1, media.pageCount == 0 || page <= media.pageCount else {
                throw OfflineError.invalidArgument("Page \(page) does not exist")
            }
            return try pdfExtractor.singlePagePDF(file: file, page: page)
        case nil:
            throw OfflineError.invalidState("Media is not ready")
        }
    }

    private func entryName(_ media: OfflineMedia, _ page: Int) throws -> String {
        guard page >= 1, page <= media.pageCount, media.pages.indices.contains(page - 1) else {
            throw OfflineError.invalidArgument("Page \(page) does not exist")
        }
        return media.pages[page - 1].fileName
    }

    /// `getFileContent(book, media, filename)`
    public func fileContent(book: OfflineBook, media: OfflineMedia, fileName: String) throws -> Data {
        let file = fileLocator.fileURL(for: book.fileDownloadPath)
        switch media.mediaProfile {
        case .divina: return try divinaExtractor(for: media).entryBytes(file: file, entryName: fileName)
        case .epub:
            guard let epubExtractor else { throw OfflineError.invalidState("Epub content is not supported") }
            return try epubExtractor.entryBytes(file: file, entryName: fileName)
        case .pdf, nil:
            throw OfflineError.invalidState("Extractor does not support extraction of files")
        }
    }

    private func divinaExtractor(for media: OfflineMedia) throws -> any DivinaExtractor {
        guard let type = media.mediaType else { throw OfflineError.invalidState("Book media type is null") }
        guard let extractor = divinaExtractors[type] else {
            throw KomgaAPIError.unsupported("Unsupported book file format \(type)")
        }
        return extractor
    }
}
