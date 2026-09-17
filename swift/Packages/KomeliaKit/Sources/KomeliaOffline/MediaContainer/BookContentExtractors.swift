import Foundation
import KomgaAPI
import Synchronization
import ReadiumZIPFoundation

/// Port of `snd.komelia.offline.mediacontainer.DivinaExtractor` (strategy per container media type).
public protocol DivinaExtractor: Sendable {
    var mediaTypes: [String] { get }
    func entryBytes(file: URL, entryName: String) async throws -> Data
}

/// Port of `EpubExtractor`.
public protocol EpubExtractor: Sendable {
    func entryBytes(file: URL, entryName: String) async throws -> Data
}

/// Port of the jvm `ZipExtractor` / `DivinaZipExtractor` / `EpubZipExtractor` on Readium's ZIPFoundation fork
/// (async API; the fork is required because Readium, used for EPUB, depends on it).
///
/// [NUEVO] Kotlin reopened the archive (and re-parsed its central directory) for every page. Readers request pages
/// sequentially from the same book, so the last few opened archives are cached. `Archive` is not thread-safe;
/// the actor serializes all access.
public actor ZipEntryExtractor: DivinaExtractor, EpubExtractor {
    public nonisolated let mediaTypes = ["application/zip"]

    private struct CachedArchive {
        let url: URL
        let modificationDate: Date?
        let archive: Archive
    }

    private var entries: [CachedArchive] = []
    private let capacity: Int

    public init(capacity: Int = 2) { self.capacity = max(1, capacity) }

    public func entryBytes(file: URL, entryName: String) async throws -> Data {
        let archive = try await archive(for: file)
        guard let entry = try await archive.get(entryName) else {
            throw OfflineError.notFound("zip entry does not exist: \(entryName)")
        }
        let buffer = DataBuffer()
        _ = try await archive.extract(entry, skipCRC32: true) { chunk in await buffer.append(chunk) }
        return await buffer.data
    }

    /// Drops cached handles (e.g. before deleting a file).
    public func evict(file: URL) {
        entries.removeAll { $0.url == file.standardizedFileURL }
    }

    private func archive(for file: URL) async throws -> Archive {
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
        let archive = try await Archive(url: url, accessMode: .read)
        entries.insert(CachedArchive(url: url, modificationDate: modified, archive: archive), at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
        return archive
    }
}

/// Accumulates extracted chunks (the fork's consumer closure is `@Sendable async`).
private actor DataBuffer {
    var data = Data()
    func append(_ chunk: Data) { data.append(chunk) }
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
    public func bookPage(book: OfflineBook, media: OfflineMedia, page: Int) async throws -> Data {
        guard media.status == .ready else { throw OfflineError.invalidState("Media is not ready") }
        let file = fileLocator.fileURL(for: book.fileDownloadPath)
        switch media.mediaProfile {
        case .divina:
            return try await divinaExtractor(for: media).entryBytes(file: file, entryName: try entryName(media, page))
        case .epub:
            guard media.epubDivinaCompatible else {
                throw OfflineError.invalidState("Epub profile does not support getting page content")
            }
            guard let epubExtractor else { throw OfflineError.invalidState("Epub content is not supported") }
            return try await epubExtractor.entryBytes(file: file, entryName: try entryName(media, page))
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
    public func fileContent(book: OfflineBook, media: OfflineMedia, fileName: String) async throws -> Data {
        let file = fileLocator.fileURL(for: book.fileDownloadPath)
        switch media.mediaProfile {
        case .divina: return try await divinaExtractor(for: media).entryBytes(file: file, entryName: fileName)
        case .epub:
            guard let epubExtractor else { throw OfflineError.invalidState("Epub content is not supported") }
            return try await epubExtractor.entryBytes(file: file, entryName: fileName)
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
