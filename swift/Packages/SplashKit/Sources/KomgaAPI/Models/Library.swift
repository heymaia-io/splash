import Foundation

// Port of snd.komga.client.library.KomgaLibrary.kt

public struct KomgaLibrary: Codable, Hashable, Sendable, Identifiable {
    public var id: KomgaLibraryId
    public var name: String
    public var root: String
    public var importComicInfoBook: Bool
    public var importComicInfoSeries: Bool
    public var importComicInfoCollection: Bool
    public var importComicInfoReadList: Bool
    public var importComicInfoSeriesAppendVolume: Bool
    public var importEpubBook: Bool
    public var importEpubSeries: Bool
    public var importMylarSeries: Bool
    public var importLocalArtwork: Bool
    public var importBarcodeIsbn: Bool
    public var scanForceModifiedTime: Bool
    public var scanInterval: ScanInterval
    public var scanOnStartup: Bool
    public var scanCbx: Bool
    public var scanPdf: Bool
    public var scanEpub: Bool
    public var scanDirectoryExclusions: [String]
    public var repairExtensions: Bool
    public var convertToCbz: Bool
    public var emptyTrashAfterScan: Bool
    public var seriesCover: SeriesCover
    public var hashFiles: Bool
    public var hashPages: Bool
    public var hashKoreader: Bool
    public var analyzeDimensions: Bool
    public var oneshotsDirectory: String?
    public var unavailable: Bool

    public init(
        id: KomgaLibraryId, name: String, root: String, importComicInfoBook: Bool = true,
        importComicInfoSeries: Bool = true, importComicInfoCollection: Bool = true,
        importComicInfoReadList: Bool = true, importComicInfoSeriesAppendVolume: Bool = true,
        importEpubBook: Bool = true, importEpubSeries: Bool = true, importMylarSeries: Bool = true,
        importLocalArtwork: Bool = true, importBarcodeIsbn: Bool = true, scanForceModifiedTime: Bool = false,
        scanInterval: ScanInterval = .every6h, scanOnStartup: Bool = false, scanCbx: Bool = true,
        scanPdf: Bool = true, scanEpub: Bool = true, scanDirectoryExclusions: [String] = [],
        repairExtensions: Bool = false, convertToCbz: Bool = false, emptyTrashAfterScan: Bool = false,
        seriesCover: SeriesCover = .first, hashFiles: Bool = true, hashPages: Bool = false,
        hashKoreader: Bool = false, analyzeDimensions: Bool = true, oneshotsDirectory: String? = nil,
        unavailable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.root = root
        self.importComicInfoBook = importComicInfoBook
        self.importComicInfoSeries = importComicInfoSeries
        self.importComicInfoCollection = importComicInfoCollection
        self.importComicInfoReadList = importComicInfoReadList
        self.importComicInfoSeriesAppendVolume = importComicInfoSeriesAppendVolume
        self.importEpubBook = importEpubBook
        self.importEpubSeries = importEpubSeries
        self.importMylarSeries = importMylarSeries
        self.importLocalArtwork = importLocalArtwork
        self.importBarcodeIsbn = importBarcodeIsbn
        self.scanForceModifiedTime = scanForceModifiedTime
        self.scanInterval = scanInterval
        self.scanOnStartup = scanOnStartup
        self.scanCbx = scanCbx
        self.scanPdf = scanPdf
        self.scanEpub = scanEpub
        self.scanDirectoryExclusions = scanDirectoryExclusions
        self.repairExtensions = repairExtensions
        self.convertToCbz = convertToCbz
        self.emptyTrashAfterScan = emptyTrashAfterScan
        self.seriesCover = seriesCover
        self.hashFiles = hashFiles
        self.hashPages = hashPages
        self.hashKoreader = hashKoreader
        self.analyzeDimensions = analyzeDimensions
        self.oneshotsDirectory = oneshotsDirectory
        self.unavailable = unavailable
    }
}

public enum SeriesCover: String, Codable, Hashable, Sendable, CaseIterable {
    case first = "FIRST"
    case firstUnreadOrFirst = "FIRST_UNREAD_OR_FIRST"
    case firstUnreadOrLast = "FIRST_UNREAD_OR_LAST"
    case last = "LAST"
}

public enum ScanInterval: String, Codable, Hashable, Sendable, CaseIterable {
    case disabled = "DISABLED"
    case hourly = "HOURLY"
    case every6h = "EVERY_6H"
    case every12h = "EVERY_12H"
    case daily = "DAILY"
    case weekly = "WEEKLY"
}

public struct KomgaLibraryCreateRequest: Codable, Hashable, Sendable {
    public var name: String
    public var root: String
    public var importComicInfoBook = true
    public var importComicInfoSeries = true
    public var importComicInfoCollection = true
    public var importComicInfoReadList = true
    public var importComicInfoSeriesAppendVolume = true
    public var importEpubBook = true
    public var importEpubSeries = true
    public var importMylarSeries = true
    public var importLocalArtwork = true
    public var importBarcodeIsbn = true
    public var scanForceModifiedTime = false
    public var scanInterval: ScanInterval = .every6h
    public var scanOnStartup = false
    public var scanCbx = true
    public var scanPdf = true
    public var scanEpub = true
    public var scanDirectoryExclusions: [String] = []
    public var repairExtensions = false
    public var convertToCbz = false
    public var emptyTrashAfterScan = false
    public var seriesCover: SeriesCover = .first
    public var hashFiles = true
    public var hashPages = false
    public var analyzeDimensions = true
    public var oneshotsDirectory: String?

    public init(name: String, root: String) {
        self.name = name
        self.root = root
    }
}

public struct KomgaLibraryUpdateRequest: Encodable, Sendable {
    public var name: String?
    public var root: String?
    public var importComicInfoBook: Bool?
    public var importComicInfoSeries: Bool?
    public var importComicInfoSeriesAppendVolume: Bool?
    public var importComicInfoCollection: Bool?
    public var importComicInfoReadList: Bool?
    public var importEpubBook: Bool?
    public var importEpubSeries: Bool?
    public var importMylarSeries: Bool?
    public var importLocalArtwork: Bool?
    public var importBarcodeIsbn: Bool?
    public var scanForceModifiedTime: Bool?
    public var repairExtensions: Bool?
    public var convertToCbz: Bool?
    public var emptyTrashAfterScan: Bool?
    public var seriesCover: SeriesCover?
    public var hashFiles: Bool?
    public var hashPages: Bool?
    public var analyzeDimensions: Bool?
    public var scanOnStartup: Bool?
    public var scanCbx: Bool?
    public var scanEpub: Bool?
    public var scanPdf: Bool?
    public var scanInterval: ScanInterval?
    public var oneshotsDirectory: PatchValue<String> = .unset
    public var scanDirectoryExclusions: PatchValue<[String]> = .unset

    public init() {}
}

// MARK: - Filesystem (desktop-only in the original; kept for protocol completeness)

public struct DirectoryRequest: Codable, Hashable, Sendable {
    public var path: String
    public init(path: String) { self.path = path }
}

public struct DirectoryListing: Codable, Hashable, Sendable {
    public var parent: String?
    public var directories: [DirectoryPath]
}

public struct DirectoryPath: Codable, Hashable, Sendable {
    public var type: String
    public var name: String
    public var path: String
}
