import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.settings.OfflineSettingsRepository`.
///
/// Kotlin exposes one `Flow` per field; Swift exposes the current values synchronously (the offline API reads the
/// user id on every call, like `StateFlow.value`) plus change streams for the fields that drive behaviour.
/// Implemented in KomeliaDB over `SettingsState<OfflineSettings>`.
public protocol OfflineSettingsRepository: Sendable {
    var isOfflineModeEnabled: Bool { get }
    var userId: KomgaUserId { get }
    var serverId: OfflineMediaServerId? { get }
    /// Root folder for downloaded files (`PlatformFile` in Kotlin).
    var downloadDirectory: URL { get }
    var readProgressSyncDate: Date? { get }
    var dataSyncDate: Date? { get }

    func putOfflineMode(_ offline: Bool) async throws
    func putUserId(_ userId: KomgaUserId) async throws
    func putServerId(_ serverId: OfflineMediaServerId?) async throws
    func putDownloadDirectory(_ directory: URL) async throws
    func putReadProgressSyncDate(_ date: Date) async throws
    func putDataSyncDate(_ date: Date) async throws

    /// `getOfflineMode(): Flow<Boolean>` — current value first.
    func offlineModeChanges() -> AsyncStream<Bool>
    /// `getUserId(): Flow<KomgaUserId>` — current value first.
    func userIdChanges() -> AsyncStream<KomgaUserId>
}

/// Resolves the stored `OfflineBook.fileDownloadPath` against the *current* download root.
/// [NUEVO] see `OfflineBook.fileDownloadPath`.
public struct OfflineFileLocator: Sendable {
    public let downloadRoot: @Sendable () -> URL

    public init(downloadRoot: @escaping @Sendable () -> URL) { self.downloadRoot = downloadRoot }

    public init(settings: any OfflineSettingsRepository) {
        self.init(downloadRoot: { settings.downloadDirectory })
    }

    public func fileURL(for storedPath: String) -> URL {
        if storedPath.hasPrefix("/") { return URL(filePath: storedPath) }
        if storedPath.hasPrefix("file:"), let url = URL(string: storedPath) { return url }
        return downloadRoot().appending(path: storedPath, directoryHint: .notDirectory)
    }

    /// Path relative to the root when `url` is inside it, otherwise the absolute path.
    public func storedPath(for url: URL) -> String {
        let root = downloadRoot().standardizedFileURL.path(percentEncoded: false)
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }
}
