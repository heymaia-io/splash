import CoreGraphics
import Foundation
import KomeliaDB
import KomgaAPI
import ReadiumZIPFoundation

@testable import KomeliaOffline

/// Whole seconds: GRDB stores milliseconds, so arbitrary `Date()`s would not round-trip exactly.
let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

/// An in-memory offline database + the offline object graph, with a temporary download root.
struct OfflineTestEnvironment {
    let database: KomeliaDatabase
    let store: GRDBOfflineDataStore
    let settings: OfflineSettingsStateRepository
    let tasks: GRDBOfflineTasksRepository
    let events: KomgaEventBroadcaster
    let emitter: OfflineTaskEmitter
    let actions: OfflineActions
    let extractors: BookContentExtractors
    let api: OfflineKomgaApi
    let root: URL

    static func make() async throws -> OfflineTestEnvironment {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "KomeliaOfflineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try KomeliaDatabase.inMemory()
        let store = GRDBOfflineDataStore(database: database)
        let settings = try await OfflineSettingsStateRepository.load(database: database, defaultDownloadDirectory: root)
        let tasks = GRDBOfflineTasksRepository(database.offline)
        let events = KomgaEventBroadcaster()
        let emitter = OfflineTaskEmitter(tasksRepository: tasks)
        let locator = OfflineFileLocator(settings: settings)
        let actions = OfflineActions(
            environment: OfflineActionEnvironment(
                store: store, events: events, taskEmitter: emitter, settings: settings, fileLocator: locator))
        let extractors = BookContentExtractors.standard(fileLocator: locator)
        let api = OfflineKomgaApi(
            store: store, actions: actions, extractors: extractors, settings: settings, events: events)
        return OfflineTestEnvironment(
            database: database, store: store, settings: settings, tasks: tasks, events: events, emitter: emitter,
            actions: actions, extractors: extractors, api: api, root: root)
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }

    var locator: OfflineFileLocator { actions.environment.fileLocator }

    /// Imports server → library → series → user (the Kotlin download sequence) and returns the server.
    @discardableResult
    func importHierarchy(
        serverUrl: String = "http://komga.test", libraries: [KomgaLibrary], series: [KomgaSeries], user: KomgaUser,
        source: StubImportSource = StubImportSource()
    ) async throws -> OfflineMediaServer {
        let server = try await actions.mediaServerSave.execute(serverUrl: serverUrl)
        for library in libraries { try await actions.libraryImport.execute(library, serverId: server.id) }
        for s in series { try await actions.seriesImport.execute(s, source: source) }
        try await actions.userImport.execute(user, serverId: server.id)
        return server
    }

    /// Imports a book with its (optional) file written under the download root.
    func importBook(
        _ book: KomgaBook, file: Data? = nil, fileName: String? = nil, userId: KomgaUserId,
        source: StubImportSource = StubImportSource()
    ) async throws {
        let storedPath = "komga.test/\(book.libraryId)/\(book.seriesId)/\(fileName ?? book.name + ".cbz")"
        if let file {
            let url = locator.fileURL(for: storedPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.write(to: url)
        }
        try await actions.bookImport.execute(
            book: book, fileDownloadPath: storedPath, userId: userId, localFileModifiedDate: book.fileLastModified,
            source: source)
    }
}

/// `OfflineImportSource` stub with canned pages / thumbnails.
struct StubImportSource: OfflineImportSource {
    var pages: [KomgaBookId: [KomgaBookPage]] = [:]
    var bookThumbnails: [KomgaBookId: OfflineThumbnailBook] = [:]
    var seriesThumbnails: [KomgaSeriesId: OfflineThumbnailSeries] = [:]

    func bookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] { pages[bookId] ?? [] }
    func selectedBookThumbnail(_ bookId: KomgaBookId) async throws -> OfflineThumbnailBook? { bookThumbnails[bookId] }
    func selectedSeriesThumbnail(_ seriesId: KomgaSeriesId) async throws -> OfflineThumbnailSeries? {
        seriesThumbnails[seriesId]
    }
    func readiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions {
        throw KomgaAPIError.httpStatus(code: 404, body: Data())
    }
    func webPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication {
        throw KomgaAPIError.httpStatus(code: 404, body: Data())
    }
    func readiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? { nil }
}

// MARK: - Wire model builders

enum Fixtures {
    static let user = KomgaUser(
        id: "user-1", email: "reader@komga.test", roles: [KomgaUser.roleUser], sharedAllLibraries: true,
        sharedLibrariesIds: [], labelsAllow: [], labelsExclude: [])

    static func library(_ id: String, name: String, seriesCover: SeriesCover = .first) -> KomgaLibrary {
        KomgaLibrary(id: KomgaLibraryId(id), name: name, root: "/data/\(name)", seriesCover: seriesCover)
    }

    static func series(
        _ id: String, library: String, title: String, booksCount: Int, deleted: Bool = false, oneshot: Bool = false,
        created: Date = baseDate, lastModified: Date = baseDate, genres: [String] = [], totalBookCount: Int? = nil,
        publisher: String = ""
    ) -> KomgaSeries {
        KomgaSeries(
            id: KomgaSeriesId(id), libraryId: KomgaLibraryId(library), name: title, url: "/data/\(title)",
            booksCount: booksCount, booksReadCount: 0, booksUnreadCount: booksCount, booksInProgressCount: 0,
            metadata: KomgaSeriesMetadata(
                status: .ongoing, title: title, titleSort: title, publisher: publisher, language: "en", genres: genres,
                tags: ["series-tag"], totalBookCount: totalBookCount),
            deleted: deleted, oneshot: oneshot,
            booksMetadata: KomgaSeriesBookMetadata(
                authors: [], tags: [], releaseDate: nil, summary: "", summaryNumber: "", created: baseDate,
                lastModified: baseDate),
            created: created, lastModified: lastModified, fileLastModified: baseDate)
    }

    static func book(
        _ id: String, series: KomgaSeries, number: Int, title: String? = nil, pages: Int = 2,
        profile: MediaProfile = .divina, mediaType: String = "application/zip", tags: [String] = [],
        authors: [KomgaAuthor] = [], releaseDate: KomgaLocalDate? = nil, readProgress: ReadProgress? = nil,
        oneshot: Bool = false, deleted: Bool = false, summary: String = "", created: Date = baseDate
    ) -> KomgaBook {
        let name = "\(series.name) \(number)"
        return KomgaBook(
            id: KomgaBookId(id), seriesId: series.id, seriesTitle: series.metadata.title,
            libraryId: series.libraryId, name: name, url: "/data/\(series.name)/\(name).cbz", number: number,
            created: created, lastModified: created, fileLastModified: baseDate.addingTimeInterval(Double(number)),
            sizeBytes: 1_000 * Int64(number), size: "", media: Media(
                status: .ready, mediaType: mediaType, pagesCount: pages, comment: "", epubDivinaCompatible: false,
                epubIsKepub: false, mediaProfile: profile),
            metadata: KomgaBookMetadata(
                title: title ?? name, summary: summary, number: String(number), numberSort: Float(number),
                releaseDate: releaseDate, authors: authors, tags: tags, isbn: "", links: [], created: created,
                lastModified: created),
            readProgress: readProgress, deleted: deleted, fileHash: "", oneshot: oneshot)
    }

    static func pages(_ names: [String], mediaType: String = "image/png") -> [KomgaBookPage] {
        names.enumerated().map { index, name in
            KomgaBookPage(
                number: index + 1, fileName: name, mediaType: mediaType, width: 1, height: 1, sizeBytes: 67, size: "")
        }
    }

    static func thumbnail(bookId: KomgaBookId, bytes: Data) -> OfflineThumbnailBook {
        OfflineThumbnailBook(
            id: KomgaThumbnailId("thumb-\(bookId)"), bookId: bookId, type: .generated, selected: true,
            mediaType: "image/png", fileSize: Int64(bytes.count), width: 1, height: 1, thumbnail: bytes)
    }
}

// MARK: - Generated media

enum GeneratedMedia {
    /// 1×1 transparent PNG.
    static let png = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")!

    /// A CBZ (zip) whose entries all contain `png`, with a distinct trailing byte per entry so pages differ.
    static func cbz(entries: [String]) async throws -> Data {
        let url = FileManager.default.temporaryDirectory.appending(path: "gen-\(UUID().uuidString).cbz")
        defer { try? FileManager.default.removeItem(at: url) }
        let archive = try await Archive(url: url, accessMode: .create)
        for (index, name) in entries.enumerated() {
            let data = png + Data([UInt8(index)])
            try await archive.addEntry(
                with: name, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate,
                provider: { position, size in data.subdata(in: Int(position)..<Int(position) + size) })
        }
        return try Data(contentsOf: url)
    }

    /// A PDF with one page per size.
    static func pdf(pageSizes: [CGSize]) -> Data {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var box = CGRect(origin: .zero, size: pageSizes[0])
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        for size in pageSizes {
            var rect = CGRect(origin: .zero, size: size)
            let info = [kCGPDFContextMediaBox as String: Data(bytes: &rect, count: MemoryLayout<CGRect>.size)]
            context.beginPDFPage(info as CFDictionary)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}

/// Collects events published on an `AsyncStream` in the background.
final class EventRecorder<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Element] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Element>) {
        task = Task { [weak self] in
            for await item in stream { self?.append(item) }
        }
    }

    deinit { task?.cancel() }

    private func append(_ item: Element) {
        lock.withLock { items.append(item) }
    }

    var values: [Element] { lock.withLock { items } }

    /// Polls until `predicate` holds (events are delivered asynchronously).
    func waitFor(timeout: Duration = .seconds(5), _ predicate: ([Element]) -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate(values) { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return predicate(values)
    }
}
