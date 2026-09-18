import Foundation
import Testing
@testable import KomgaAPI

@Suite("Wire model decoding against real Komga payloads")
struct ModelDecodingTests {
    @Test func book() throws {
        let book = try Fixture.decode(KomgaBook.self, "book")
        #expect(!book.id.rawValue.isEmpty)
        #expect(book.media.status == .ready)
        #expect(book.media.mediaProfile == .divina)
        #expect(book.media.mediaType == "application/zip")
        #expect(book.metadata.authors.contains(KomgaAuthor(name: "Fixture Writer", role: KomgaAuthor.Role.writer)))
        #expect(book.metadata.releaseDate != nil)
        #expect(book.readProgress == nil)
        #expect(book.sizeBytes > 0)
    }

    @Test func bookPages() throws {
        let pages = try Fixture.decode([KomgaBookPage].self, "book_pages")
        #expect(!pages.isEmpty)
        #expect(pages.first?.number == 1)
        #expect(pages.first?.width != nil)
    }

    @Test func seriesWithWebtoonDirection() throws {
        let series = try Fixture.decode(KomgaSeries.self, "series")
        #expect(series.metadata.readingDirection == .webtoon)
        #expect(series.booksCount == 2)
    }

    @Test func pages() throws {
        let series = try Fixture.decode(Page<KomgaSeries>.self, "series_page")
        #expect(series.totalElements == 6)
        #expect(series.content.count == 6)
        #expect(series.content.contains { $0.oneshot })
        #expect(series.pageable?.pageSize == 20)

        let books = try Fixture.decode(Page<KomgaBook>.self, "books_page")
        #expect(books.totalElements == 12)
        #expect(books.content.contains { $0.oneshot })
    }

    @Test func librariesUserCollectionsReadLists() throws {
        let libraries = try Fixture.decode([KomgaLibrary].self, "libraries")
        #expect(Set(libraries.map(\.name)) == ["Comics", "Manga", "Webtoon"])
        #expect(libraries.first { $0.name == "Comics" }?.oneshotsDirectory == "_oneshots")

        let me = try Fixture.decode(KomgaUser.self, "user_me")
        #expect(me.isAdmin)
        #expect(me.email == "admin@fixture.local")

        let collections = try Fixture.decode(Page<KomgaCollection>.self, "collections_page")
        #expect(collections.content.first?.seriesIds.count == 2)

        let readLists = try Fixture.decode(Page<KomgaReadList>.self, "readlists_page")
        #expect(readLists.content.first?.ordered == true)
        #expect(readLists.content.first?.bookIds.count == 2)
    }

    @Test func settingsWithNullMultiSource() throws {
        let settings = try Fixture.decode(KomgaSettings.self, "settings")
        #expect(settings.serverPort.effectiveValue == 25600)
        #expect(settings.serverPort.databaseSource == nil)
        #expect(settings.serverContextPath.effectiveValue == "")
        #expect(settings.thumbnailSize == .default)
    }

    @Test func authenticationActivityAndThumbnails() throws {
        let activity = try Fixture.decode(Page<KomgaAuthenticationActivity>.self, "auth_activity_page")
        #expect(activity.content.allSatisfy { !$0.source.isEmpty })
        let thumbnails = try Fixture.decode([KomgaBookThumbnail].self, "book_thumbnails")
        #expect(thumbnails.contains { $0.selected })
    }

    @Test func unpagedPageableInstance() throws {
        let json = #"""
        {"content":[],"pageable":"INSTANCE","totalElements":0,"totalPages":1,"last":true,"number":0,
         "sort":{"sorted":false,"unsorted":true,"empty":true},"first":true,"numberOfElements":0,"size":0,"empty":true}
        """#
        let page = try KomgaJSON.makeDecoder().decode(Page<KomgaBook>.self, from: Data(json.utf8))
        #expect(page.pageable == nil)
        #expect(page.empty)
    }

    @Test(arguments: ["", "SIDEWAYS"])
    func lenientReadingDirection(raw: String) throws {
        var json = try String(decoding: Fixture.data("series"), as: UTF8.self)
        json = json.replacingOccurrences(of: #""readingDirection":"WEBTOON""#, with: #""readingDirection":"\#(raw)""#)
        let series = try KomgaJSON.makeDecoder().decode(KomgaSeries.self, from: Data(json.utf8))
        #expect(series.metadata.readingDirection == nil)
    }

    @Test func instantParsingVariants() {
        #expect(KomgaInstant.parse("2026-09-17T08:08:36Z") != nil)
        #expect(KomgaInstant.parse("2026-09-17T08:10:57.524+00:00") != nil)
        #expect(KomgaInstant.parse("2026-09-17T08:10:57.524Z") != nil)
        #expect(KomgaInstant.parse("garbage") == nil)
    }

    @Test func komeliaBookForwardsAndOutdatedCheck() throws {
        let book = try Fixture.decode(KomgaBook.self, "book")
        var komelia = SplashBook(book: book, downloaded: true,
                                  localFileLastModified: book.fileLastModified.addingTimeInterval(0.4))
        #expect(komelia.name == book.name)
        #expect(!komelia.isLocalFileOutdated)
        komelia.localFileLastModified = book.fileLastModified.addingTimeInterval(5)
        #expect(komelia.isLocalFileOutdated)
    }
}

@Suite("Server info (/actuator/info)")
struct ServerInfoDecodingTests {
    /// The real payload, taken from the fixture server's OpenAPI example.
    @Test func decodesActuatorInfo() throws {
        let json = #"""
        {"git":{"branch":"master","commit":{"id":"9be980d","time":"2025-03-12T03:40:38Z"}},
         "build":{"artifact":"komga","name":"komga","version":"1.21.2","group":"komga"},
         "java":{"version":"23.0.2","vendor":{"name":"Eclipse Adoptium","version":"Temurin-23.0.2+7"}},
         "os":{"name":"Linux","version":"6.8.0-57-generic","arch":"amd64"}}
        """#
        let info = try KomgaJSON.makeDecoder().decode(KomgaServerInfo.self, from: Data(json.utf8))
        #expect(info.version == "1.21.2")
        #expect(info.gitBranch == "master")
        #expect(info.gitCommitId == "9be980d")
        #expect(info.javaVersion == "23.0.2")
        #expect(info.javaVendor == "Eclipse Adoptium")
        #expect(info.osName == "Linux")
        #expect(info.osArch == "amd64")
    }

    /// Every actuator section is optional — a server can disable any of them, and a missing section must
    /// leave the screen blank rather than fail the whole decode.
    @Test func toleratesMissingSections() throws {
        let info = try KomgaJSON.makeDecoder().decode(
            KomgaServerInfo.self, from: Data(#"{"build":{"version":"1.0.0"}}"#.utf8))
        #expect(info.version == "1.0.0")
        #expect(info.javaVersion == nil)
        #expect(info.osName == nil)
        #expect(info.gitCommitId == nil)
    }
}
