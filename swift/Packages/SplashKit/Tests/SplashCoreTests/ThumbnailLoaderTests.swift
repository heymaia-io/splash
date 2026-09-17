import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import SplashCore
@testable import KomgaAPI

@Suite struct ThumbnailLoaderTests {
    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    func makeLoader(api: CountingBookApi) -> (ThumbnailLoader, URL) {
        let dir = FileManager.default.temporaryDirectory.appending(path: "thumbs-\(UUID().uuidString)")
        let komga = StubKomgaApi(bookApi: api)
        let loader = ThumbnailLoader(
            api: { komga }, namespace: { "http://server" }, configuration: .init(directory: dir))
        return (loader, dir)
    }

    @Test func downsamplesCachesAndCoalesces() async throws {
        let api = CountingBookApi(data: Self.png(width: 1000, height: 1500))
        let (loader, dir) = makeLoader(api: api)
        defer { try? FileManager.default.removeItem(at: dir) }

        async let a = loader.image(for: .bookDefault("B"), maxPixelSize: 300)
        async let b = loader.image(for: .bookDefault("B"), maxPixelSize: 300)
        let (first, second) = try await (a, b)
        #expect(first?.pixelSize == CGSize(width: 200, height: 300))
        #expect(second != nil)
        #expect(api.calls == 1)

        // Different size: served from disk, no network.
        let bigger = try await loader.image(for: .bookDefault("B"), maxPixelSize: 600)
        #expect(bigger?.pixelSize.height == 600)
        #expect(api.calls == 1)

        // Invalidation drops memory + disk => refetch.
        await loader.invalidate(prefix: ThumbnailRequest.prefix(book: "B"))
        _ = try await loader.image(for: .bookDefault("B"), maxPixelSize: 300)
        #expect(api.calls == 2)
    }

    @Test func missingThumbnailIsNil() async throws {
        let api = CountingBookApi(data: nil)
        let (loader, dir) = makeLoader(api: api)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try await loader.image(for: .bookDefault("X"), maxPixelSize: 100) == nil)
    }

    @Test func diskTrimRemovesOldestFirst() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "trim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0..<3 {
            let file = dir.appending(path: "f\(i)")
            try Data(count: 100).write(to: file)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: Double(i) * 1000)], ofItemAtPath: file.path)
        }
        ThumbnailLoader.trim(directory: dir, budget: 250)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(remaining == ["f1", "f2"])
    }
}

// MARK: - Test doubles

final class CountingBookApi: KomgaBookApi, @unchecked Sendable {
    private let counter = Mutex(0)
    let data: Data?
    init(data: Data?) { self.data = data }
    var calls: Int { counter.withLock { $0 } }

    func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data? {
        counter.withLock { $0 += 1 }
        try await Task.sleep(for: .milliseconds(50))
        return data
    }

    func getOne(_ bookId: KomgaBookId) async throws -> SplashBook { fatalError() }
    func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> SplashBook? { fatalError() }
    func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> SplashBook? { fatalError() }
    func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws { fatalError() }
    func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] { fatalError() }
    func analyze(_ bookId: KomgaBookId) async throws { fatalError() }
    func refreshMetadata(_ bookId: KomgaBookId) async throws { fatalError() }
    func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws { fatalError() }
    func deleteReadProgress(_ bookId: KomgaBookId) async throws { fatalError() }
    func deleteBook(_ bookId: KomgaBookId) async throws { fatalError() }
    func regenerateThumbnails(forBiggerResultOnly: Bool) async throws { fatalError() }
    func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data { fatalError() }
    func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail] { fatalError() }
    func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws -> KomgaBookThumbnail { fatalError() }
    func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList] { fatalError() }
    func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data { fatalError() }
    func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data { fatalError() }
    func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? { fatalError() }
    func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws { fatalError() }
    func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions { fatalError() }
    func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication { fatalError() }
    func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data { fatalError() }
}

/// Only `bookApi` is exercised; every other member traps if touched.
struct StubKomgaApi: KomgaApi {
    let bookApi: any KomgaBookApi
    var actuatorApi: any KomgaActuatorApi { fatalError() }
    var announcementsApi: any KomgaAnnouncementsApi { fatalError() }
    var collectionsApi: any KomgaCollectionsApi { fatalError() }
    var fileSystemApi: any KomgaFileSystemApi { fatalError() }
    var libraryApi: any KomgaLibraryApi { fatalError() }
    var readListApi: any KomgaReadListApi { fatalError() }
    var referentialApi: any KomgaReferentialApi { fatalError() }
    var seriesApi: any KomgaSeriesApi { fatalError() }
    var settingsApi: any KomgaSettingsApi { fatalError() }
    var tasksApi: any KomgaTaskApi { fatalError() }
    var userApi: any KomgaUserApi { fatalError() }
    func createSSESession() async throws -> any KomgaSSESession { fatalError() }
}
