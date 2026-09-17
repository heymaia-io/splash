import Foundation
import GRDB
@testable import SplashDB

/// Whole-second dates: GRDB stores millisecond precision, so arbitrary `Date()`s would not compare equal.
let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

/// A migrated on-disk `DatabasePool` pair in a fresh temp directory (removed by `cleanup()`).
struct TemporaryDatabase {
    let directory: URL
    let database: SplashDatabase

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "SplashDBTests-\(UUID().uuidString)")
        database = try SplashDatabase(directory: directory)
    }

    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

/// Inserts server → library → series → book (the FK chain a book needs).
func insertBook(_ id: String, in db: Database) throws {
    if try OfflineSeriesRecord.fetchOne(db, key: "series-1") == nil {
        try OfflineMediaServerRecord(id: "server-1", url: "https://komga.example").insert(db)
        try OfflineLibraryRecord(
            id: "library-1", serverId: "server-1", name: "Comics", root: "/data/comics",
            importComicInfoBook: true, importComicInfoSeries: true, importComicInfoCollection: true,
            importComicInfoReadList: true, importComicInfoSeriesAppendVolume: false, importEpubBook: true,
            importEpubSeries: true, importMylarSeries: true, importLocalArtwork: true, importBarcodeIsbn: false,
            scanForceModifiedTime: false, scanOnStartup: false, scanInterval: "EVERY_6H", scanCbx: true,
            scanPdf: true, scanEpub: true, repairExtensions: false, convertToCbz: false,
            emptyTrashAfterScan: false, seriesCover: "FIRST", hashFiles: true, hashPages: false,
            hashKoreader: false, analyzeDimensions: true, oneshotsDirectory: nil, unavailable: false
        ).insert(db)
        try OfflineSeriesRecord(
            id: "series-1", libraryId: "library-1", name: "Series", url: "/data/comics/Series", booksCount: 1,
            createdDate: fixedDate, lastModifiedDate: fixedDate, fileLastModifiedDate: fixedDate
        ).insert(db)
    }
    try makeBook(id).insert(db)
}

func makeBook(_ id: String) -> OfflineBookRecord {
    OfflineBookRecord(
        id: id, seriesId: "series-1", libraryId: "library-1", name: "Book \(id)",
        url: "/data/comics/Series/\(id).cbz", fileSize: 12_345_678, number: 1, fileHash: "abc",
        createdDate: fixedDate, lastModifiedDate: fixedDate,
        remoteFileModifiedDate: fixedDate, localFileModifiedDate: fixedDate.addingTimeInterval(60),
        fileDownloadPath: "/downloads/\(id).cbz")
}
