import Foundation
import GRDB
import SplashCore

/// Port of `snd.komelia.db.OfflineSettings`. May move to SplashOffline once that domain lands.
///
/// Ids are plain strings for now (SplashDB has no direct KomgaAPI dependency); `userId` is a `KomgaUserId`
/// value and `serverId` an `OfflineMediaServerId` value in Kotlin.
public struct OfflineSettings: Codable, Hashable, Sendable {
    /// `OfflineUser.ROOT` — the local user row seeded by the offline migration.
    public static let rootUserId = "0"

    public var isOfflineModeEnabled: Bool
    /// Kotlin `PlatformFile`; on iOS a path (or later a security-scoped bookmark) of the download folder.
    public var downloadDirectory: String
    public var userId: String
    public var serverId: String?
    public var readProgressSyncDate: Date?
    public var dataSyncDate: Date?

    public init(
        isOfflineModeEnabled: Bool = false,
        downloadDirectory: String,
        userId: String = OfflineSettings.rootUserId,
        serverId: String? = nil,
        readProgressSyncDate: Date? = nil,
        dataSyncDate: Date? = nil
    ) {
        self.isOfflineModeEnabled = isOfflineModeEnabled
        self.downloadDirectory = downloadDirectory
        self.userId = userId
        self.serverId = serverId
        self.readProgressSyncDate = readProgressSyncDate
        self.dataSyncDate = dataSyncDate
    }
}

/// Port of `ExposedOfflineSettingsRepository` (single `version = 1` row in the offline `SETTINGS` table).
public struct GRDBOfflineSettingsStore: SettingsStore {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    public func load() async throws -> OfflineSettings? {
        try await writer.read { db in try OfflineSettingsRow.fetchOne(db)?.settings }
    }

    public func save(_ value: OfflineSettings) async throws {
        try await writer.write { db in try OfflineSettingsRow(settings: value).upsert(db) }
    }
}

private struct OfflineSettingsRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "SETTINGS"
    var settings: OfflineSettings

    init(settings: OfflineSettings) { self.settings = settings }

    init(row: Row) throws {
        settings = OfflineSettings(
            isOfflineModeEnabled: try row.decode(forColumn: "is_offline_mode_enabled"),
            downloadDirectory: try row.decode(forColumn: "download_directory"),
            userId: try row.decode(String?.self, forColumn: "user_id") ?? OfflineSettings.rootUserId,
            serverId: try row.decode(forColumn: "server_id"),
            readProgressSyncDate: try row.decode(forColumn: "read_progress_sync_date"),
            dataSyncDate: try row.decode(forColumn: "data_sync_date"))
    }

    func encode(to container: inout PersistenceContainer) {
        container["version"] = 1
        container["is_offline_mode_enabled"] = settings.isOfflineModeEnabled
        container["user_id"] = settings.userId
        container["server_id"] = settings.serverId
        container["download_directory"] = settings.downloadDirectory
        container["read_progress_sync_date"] = settings.readProgressSyncDate
        container["data_sync_date"] = settings.dataSyncDate
    }
}
