import Foundation
import GRDB
import SplashCore

/// Port of `ExposedSettingsRepository`: the whole `AppSettings` lives in the single `version = 1` row.
public struct GRDBAppSettingsStore: SettingsStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    public func load() async throws -> AppSettings? {
        try await writer.read { db in try AppSettingsRow.fetchOne(db)?.settings }
    }

    public func save(_ value: AppSettings) async throws {
        try await writer.write { db in try AppSettingsRow(settings: value).upsert(db) }
    }
}

/// Port of `ExposedImageReaderSettingsRepository`: global reader settings are the `book_id = 'DEFAULT'` row
/// (the table is keyed by book so per-book overrides remain possible).
public struct GRDBImageReaderSettingsStore: SettingsStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    public func load() async throws -> ImageReaderSettings? {
        try await writer.read { db in
            try ImageReaderSettingsRow.fetchOne(db, key: ImageReaderSettingsRow.defaultBookId)?.settings
        }
    }

    public func save(_ value: ImageReaderSettings) async throws {
        try await writer.write { db in try ImageReaderSettingsRow(settings: value).upsert(db) }
    }
}

/// Port of `ExposedHomeScreenFilterRepository`: the filter list is one JSON array in the `version = 1` row.
/// Generic because the `HomeScreenFilter` domain type arrives in a later phase; the caller sorts by `order`.
public struct GRDBHomeScreenFilterStore<Filter: Codable & Sendable>: SettingsStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    /// Undecodable JSON yields `nil` (Kotlin catches `SerializationException`) so the defaults get re-saved.
    public func load() async throws -> [Filter]? {
        let json = try await writer.read { db in
            try String.fetchOne(db, sql: "SELECT filters FROM HomeScreenFilters WHERE version = 1")
        }
        guard let json else { return nil }
        return try? JSONDecoder().decode([Filter].self, from: Data(json.utf8))
    }

    public func save(_ value: [Filter]) async throws {
        let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try await writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO HomeScreenFilters (version, filters) VALUES (1, ?)
                    ON CONFLICT (version) DO UPDATE SET filters = excluded.filters
                    """,
                arguments: [json])
        }
    }
}

// MARK: - Rows

/// Enum columns hold the Kotlin enum name; an unknown name is a decoding error (Kotlin `valueOf` throws too).
struct UnknownEnumValue: Error, CustomStringConvertible {
    let column: String
    let value: String
    var description: String { "Unknown value '\(value)' in column \(column)" }
}

extension Row {
    func decodeEnum<E: RawRepresentable>(_ column: String) throws -> E where E.RawValue == String {
        let raw: String = try decode(forColumn: column)
        guard let value = E(rawValue: raw) else { throw UnknownEnumValue(column: column, value: raw) }
        return value
    }
}

/// `AppSettingsTable` row.
private struct AppSettingsRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "AppSettings"
    var settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    init(row: Row) throws {
        var s = AppSettings()
        s.username = try row.decode(forColumn: "username")
        s.serverUrl = try row.decode(forColumn: "serverUrl")
        s.cardWidth = try row.decode(forColumn: "card_width")
        s.seriesPageLoadSize = try row.decode(forColumn: "series_page_load_size")
        s.bookPageLoadSize = try row.decode(forColumn: "book_page_load_size")
        s.bookListLayout = try row.decodeEnum("book_list_layout")
        s.appTheme = try row.decodeEnum("app_theme")
        settings = s
    }

    func encode(to container: inout PersistenceContainer) {
        container["version"] = 1
        container["username"] = settings.username
        container["serverUrl"] = settings.serverUrl
        container["card_width"] = settings.cardWidth
        container["series_page_load_size"] = settings.seriesPageLoadSize
        container["book_page_load_size"] = settings.bookPageLoadSize
        container["book_list_layout"] = settings.bookListLayout.rawValue
        container["app_theme"] = settings.appTheme.rawValue
    }
}

/// `ImageReaderSettingsTable` row.
private struct ImageReaderSettingsRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "ImageReaderSettings"
    /// `snd.komelia.db.defaultBookId`.
    static let defaultBookId = "DEFAULT"
    var settings: ImageReaderSettings

    init(settings: ImageReaderSettings) { self.settings = settings }

    init(row: Row) throws {
        var s = ImageReaderSettings()
        s.readerType = try row.decodeEnum("reader_type")
        s.stretchToFit = try row.decode(forColumn: "stretch_to_fit")
        s.pagedScaleType = try row.decodeEnum("paged_scale_type")
        s.pagedReadingDirection = try row.decodeEnum("paged_reading_direction")
        s.pagedPageLayout = try row.decodeEnum("paged_page_layout")
        s.continuousReadingDirection = try row.decodeEnum("continuous_reading_direction")
        s.continuousPadding = try row.decode(forColumn: "continuous_padding")
        s.continuousPageSpacing = try row.decode(forColumn: "continuous_page_spacing")
        s.cropBorders = try row.decode(forColumn: "crop_borders")
        s.flashOnPageChange = try row.decode(forColumn: "flash_on_page_change")
        s.flashDuration = try row.decode(forColumn: "flash_duration")
        s.flashEveryNPages = try row.decode(forColumn: "flash_every_n_pages")
        s.flashWith = try row.decodeEnum("flash_with")
        s.downsamplingKernel = try row.decodeEnum("downsampling_kernel")
        s.linearLightDownsampling = try row.decode(forColumn: "linear_light_downsampling")
        s.upsamplingMode = try row.decodeEnum("upsampling_mode")
        s.loadThumbnailPreviews = try row.decode(forColumn: "load_thumbnail_previews")
        s.volumeKeysNavigation = try row.decode(forColumn: "volume_keys_navigation")
        settings = s
    }

    func encode(to container: inout PersistenceContainer) {
        container["book_id"] = Self.defaultBookId
        container["reader_type"] = settings.readerType.rawValue
        container["stretch_to_fit"] = settings.stretchToFit
        container["paged_scale_type"] = settings.pagedScaleType.rawValue
        container["paged_reading_direction"] = settings.pagedReadingDirection.rawValue
        container["paged_page_layout"] = settings.pagedPageLayout.rawValue
        container["continuous_reading_direction"] = settings.continuousReadingDirection.rawValue
        container["continuous_padding"] = settings.continuousPadding
        container["continuous_page_spacing"] = settings.continuousPageSpacing
        container["crop_borders"] = settings.cropBorders
        container["flash_on_page_change"] = settings.flashOnPageChange
        container["flash_duration"] = settings.flashDuration
        container["flash_every_n_pages"] = settings.flashEveryNPages
        container["flash_with"] = settings.flashWith.rawValue
        container["downsampling_kernel"] = settings.downsamplingKernel.rawValue
        container["linear_light_downsampling"] = settings.linearLightDownsampling
        container["upsampling_mode"] = settings.upsamplingMode.rawValue
        container["load_thumbnail_previews"] = settings.loadThumbnailPreviews
        container["volume_keys_navigation"] = settings.volumeKeysNavigation
    }
}

/// EPUB preferences in the `EpubReaderSettings` row `book_id = 'DEFAULT'` (JSON in `komga_settings_json`,
/// `reader_type = 'READIUM'`). The ttsu column is kept for schema compatibility with the Kotlin table.
public struct GRDBEpubReaderSettingsStore<Value: Codable & Sendable>: SettingsStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    public func load() async throws -> Value? {
        let json = try await writer.read { db in
            try String.fetchOne(
                db, sql: "SELECT komga_settings_json FROM EpubReaderSettings WHERE book_id = 'DEFAULT'")
        }
        guard let json else { return nil }
        return try? JSONDecoder().decode(Value.self, from: Data(json.utf8))
    }

    public func save(_ value: Value) async throws {
        let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try await writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO EpubReaderSettings (book_id, reader_type, komga_settings_json, ttsu_settings_json)
                    VALUES ('DEFAULT', 'READIUM', ?, '{}')
                    ON CONFLICT (book_id) DO UPDATE SET
                        reader_type = excluded.reader_type, komga_settings_json = excluded.komga_settings_json
                    """,
                arguments: [json])
        }
    }
}
