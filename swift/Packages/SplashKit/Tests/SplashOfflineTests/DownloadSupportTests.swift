import Foundation
import KomgaAPI
import Testing

@testable import SplashOffline

@Suite struct FileHasherTests {
    /// Reference values from python `xxhash.xxh3_128_hexdigest` over bytes `(i * 31 + 7) & 0xFF`; the lengths
    /// cover every XXH3-128 code path (0, 1–3, 4–8, 9–16, 17–128, 129–240, long, block boundaries).
    static let vectors: [(Int, String)] = [
        (0, "99aa06d3014798d86001c324468d497f"), (1, "495b62073ef70ca44c5cca45d0f4811f"),
        (3, "46f66cb93538156515f7093b173d005c"), (4, "7fefeeffb4d0eab3b987ca5d9241572a"),
        (8, "803c675a846cc6c256bb836ceb6d4baa"), (9, "d46556872d230f224376673580310154"),
        (16, "650fe308c566747df853dd94614dfa07"), (17, "18217300b5132d5a78c349fe81b2f26c"),
        (33, "91a4c56ad1b91d883b25275300c8b44e"), (65, "5642c5d38e6e787dd0d1d7884590a330"),
        (97, "0912f66857975b13fa4138b7dc44e45b"), (128, "b4f87b99d2db8a511e04fad9f0cacb4d"),
        (129, "6881633650cd8924c51bc887976aef63"), (200, "8d8629a1aef9ef9060ea018811f9a437"),
        (240, "de57aab31e77a2ff93e173833f75ab66"), (241, "92b991a7192f3f080b3b630948ce4a00"),
        (1024, "4c17271c906df79223bc880ebf0d29c6"), (1025, "70a4eb1b9691d77fc09fdfbc398c7d82"),
        (1088, "fcf9dfe2b0ba271ba16bad67843c5a45"), (4097, "b074f6deb50fbb5eb319759b4671c221"),
        (100_000, "8ce7a24d31cd94b1ccf90df7e7e37036"),
    ]

    @Test(arguments: vectors)
    func matchesReferenceImplementation(length: Int, expected: String) {
        let data = Data((0..<length).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        #expect(FileHasher.xxh3_128Hex(data) == expected)
    }

    @Test func hashesFilesThroughMemoryMapping() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "hash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data((0..<4097).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }).write(to: url)
        #expect(try FileHasher.xxh3_128Hex(of: url) == "b074f6deb50fbb5eb319759b4671c221")
    }
}

@Suite struct DownloadPathBuilderTests {
    @Test func serverDirectoryName() {
        #expect(DownloadPathBuilder.serverDirectoryName(for: URL(string: "http://localhost:25601")!) == "localhost_25601")
        #expect(DownloadPathBuilder.serverDirectoryName(for: URL(string: "https://komga.example/")!) == "komga.example")
        #expect(
            DownloadPathBuilder.serverDirectoryName(for: URL(string: "https://nas.lan:8443/apps/komga/")!)
                == "nas.lan_8443_apps_komga")
    }

    @Test func relativePathIsVerbatimButSanitized() {
        let path = DownloadPathBuilder.relativePath(
            serverURL: URL(string: "http://localhost:25601")!, libraryName: "Comics", seriesName: "Fixture Hero",
            bookURL: "/data/Comics/Fixture Hero/Fixture Hero v01.cbz")
        #expect(path == "localhost_25601/Comics/Fixture Hero/Fixture Hero v01.cbz")

        let odd = DownloadPathBuilder.relativePath(
            serverURL: URL(string: "http://h")!, libraryName: "A/B", seriesName: "What?: \"x\". ",
            bookURL: "file:///data/My%20Book.cbz")
        #expect(odd == "h/AB/What x/My Book.cbz")
        #expect(DownloadPathBuilder.sanitize("..") == "_")
        #expect(DownloadPathBuilder.sanitize("") == "_")
    }

    @Test func fileLocatorStoresRelativePaths() {
        let root = URL(filePath: "/tmp/downloads", directoryHint: .isDirectory)
        let locator = OfflineFileLocator(downloadRoot: { root })
        let file = root.appending(path: "srv/Lib/Series/Book.cbz")
        #expect(locator.storedPath(for: file) == "srv/Lib/Series/Book.cbz")
        #expect(locator.fileURL(for: "srv/Lib/Series/Book.cbz").path() == file.path())
        #expect(locator.fileURL(for: "/elsewhere/Book.cbz").path() == "/elsewhere/Book.cbz")
        #expect(locator.storedPath(for: URL(filePath: "/elsewhere/Book.cbz")) == "/elsewhere/Book.cbz")
    }

    @Test func taskDataUsesKotlinWireFormat() throws {
        let data = try JSONEncoder().encode(TaskData.downloadBook("B1"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(json == ["type": "DownloadBook", "bookId": "B1"])
        for task in [
            TaskData.aggregateSeriesMetadata("S"), .deleteBook("B"), .deleteBookFiles("a/b.cbz"), .deleteSeries("S"),
            .deleteLibrary("L"), .downloadBook("B"), .downloadSeries("S"), .downloadBookCancel("B"),
        ] {
            #expect(try JSONDecoder().decode(TaskData.self, from: JSONEncoder().encode(task)) == task)
        }
        #expect(TaskData.downloadSeries("S1").uniqueName == "DownloadSeries_S1")
    }
}
