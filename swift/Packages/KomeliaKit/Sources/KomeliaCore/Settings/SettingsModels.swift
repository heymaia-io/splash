import Foundation

// Ports of komelia-domain/core/settings/model/*.kt and komelia-infra/database/shared/*Settings.kt.
// Raw values are the Kotlin enum names: they are the persistence contract.

public enum AppTheme: String, Codable, Sendable, CaseIterable {
    case dark = "DARK", light = "LIGHT", darker = "DARKER"
}

public enum BooksLayout: String, Codable, Sendable, CaseIterable {
    case grid = "GRID", list = "LIST"
}

public enum ReaderType: String, Codable, Sendable, CaseIterable {
    case paged = "PAGED"
    /// Requires the ONNX panel detector — out of scope on iOS; kept so persisted values round-trip.
    case panels = "PANELS"
    case continuous = "CONTINUOUS"
}

public enum LayoutScaleType: String, Codable, Sendable, CaseIterable {
    case screen = "SCREEN", fitWidth = "FIT_WIDTH", fitHeight = "FIT_HEIGHT", original = "ORIGINAL"
}

public enum PagedReadingDirection: String, Codable, Sendable, CaseIterable {
    case leftToRight = "LEFT_TO_RIGHT", rightToLeft = "RIGHT_TO_LEFT"
}

public enum PageDisplayLayout: String, Codable, Sendable, CaseIterable {
    case singlePage = "SINGLE_PAGE", doublePages = "DOUBLE_PAGES", doublePagesNoCover = "DOUBLE_PAGES_NO_COVER"
}

public enum ContinuousReadingDirection: String, Codable, Sendable, CaseIterable {
    case topToBottom = "TOP_TO_BOTTOM", leftToRight = "LEFT_TO_RIGHT", rightToLeft = "RIGHT_TO_LEFT"
}

public enum ReaderFlashColor: String, Codable, Sendable, CaseIterable {
    case black = "BLACK", white = "WHITE", whiteAndBlack = "WHITE_AND_BLACK"
}

/// `snd.komelia.image.ReduceKernel` (libvips kernels). On iOS only a subset maps to vImage/Core Image;
/// values are kept for persistence compatibility.
public enum ReduceKernel: String, Codable, Sendable, CaseIterable {
    case nearest = "NEAREST", linear = "LINEAR", cubic = "CUBIC", mitchell = "MITCHELL"
    case lanczos2 = "LANCZOS2", lanczos3 = "LANCZOS3", mks2013 = "MKS2013", mks2021 = "MKS2021"
    case `default` = "DEFAULT"
}

public enum UpsamplingMode: String, Codable, Sendable, CaseIterable {
    case nearest = "NEAREST", bilinear = "BILINEAR", mitchell = "MITCHELL", catmullRom = "CATMULL_ROM"
}

/// `snd.komelia.db.AppSettings` (update-check fields dropped: no in-app updater on iOS).
public struct AppSettings: Codable, Hashable, Sendable {
    public var username: String = "admin@example.org"
    public var serverUrl: String = "http://localhost:25600"
    public var cardWidth: Int = 170
    public var seriesPageLoadSize: Int = 20
    public var bookPageLoadSize: Int = 20
    public var bookListLayout: BooksLayout = .grid
    public var appTheme: AppTheme = .dark

    public init() {}
}

/// `snd.komelia.db.ImageReaderSettings` (ONNX upscaler fields dropped: out of scope).
public struct ImageReaderSettings: Codable, Hashable, Sendable {
    public var readerType: ReaderType = .paged
    public var stretchToFit: Bool = true
    public var pagedScaleType: LayoutScaleType = .screen
    public var pagedReadingDirection: PagedReadingDirection = .leftToRight
    public var pagedPageLayout: PageDisplayLayout = .singlePage
    public var continuousReadingDirection: ContinuousReadingDirection = .topToBottom
    public var continuousPadding: Float = 0
    public var continuousPageSpacing: Int = 0
    public var cropBorders: Bool = false

    public var flashOnPageChange: Bool = false
    public var flashDuration: Int64 = 100
    public var flashEveryNPages: Int = 1
    public var flashWith: ReaderFlashColor = .black
    public var downsamplingKernel: ReduceKernel = .lanczos3
    public var linearLightDownsampling: Bool = false
    public var upsamplingMode: UpsamplingMode = .catmullRom
    public var loadThumbnailPreviews: Bool = true
    public var volumeKeysNavigation: Bool = false

    public init() {}
}
