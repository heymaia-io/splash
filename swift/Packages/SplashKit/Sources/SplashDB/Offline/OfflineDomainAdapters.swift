import Foundation
import GRDB
import SplashCore
import SplashOffline
import KomgaAPI

/// Port of `ExposedOfflineTasksRepository` in domain terms: `TaskEntry` ⇄ `TASK` rows (JSON `TaskData`).
public struct GRDBOfflineTasksRepository: OfflineTasksRepository {
    private let queue: OfflineTaskQueue
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) {
        self.writer = writer
        queue = OfflineTaskQueue(writer)
    }

    public func takeNew() async throws -> TaskEntry? {
        while let record = try await queue.takeNew() {
            if let entry = Self.entry(record) { return entry }
            // Unknown / legacy task type: drop it instead of blocking the queue.
            try await queue.delete(uniqueName: record.uniqueName)
        }
        return nil
    }

    public func save(_ entries: [TaskEntry]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let records = try entries.map { entry in
            OfflineTaskRecord(
                uniqueName: entry.uniqueName, priority: entry.priority,
                status: OfflineTaskRecord.Status(rawValue: entry.status.rawValue) ?? .new,
                task: String(decoding: try encoder.encode(entry.task), as: UTF8.self))
        }
        try await queue.save(records)
    }

    public func delete(uniqueName: String) async throws {
        try await queue.delete(uniqueName: uniqueName)
    }

    public func deletePending(uniqueName: String) async throws -> Bool {
        try await queue.deletePending(uniqueName: uniqueName)
    }

    public func resetAllRunning() async throws -> Int {
        try await queue.resetAllRunning()
    }

    /// All queued entries, highest priority first (diagnostics / tests).
    public func findAll() async throws -> [TaskEntry] {
        try await writer.read { db in
            try OfflineTaskRecord.order(Column("priority").desc, Column("created_date")).fetchAll(db)
        }.compactMap(Self.entry)
    }

    private static func entry(_ record: OfflineTaskRecord) -> TaskEntry? {
        guard let task = try? JSONDecoder().decode(TaskData.self, from: Data(record.task.utf8)) else { return nil }
        return TaskEntry(
            task: task, priority: record.priority, status: TaskEntry.Status(rawValue: record.status.rawValue) ?? .new)
    }
}

/// Port of the Kotlin `OfflineSettingsRepositoryWrapper`: the domain `OfflineSettingsRepository` over
/// `SettingsState<OfflineSettings>` (single `SETTINGS` row).
public final class OfflineSettingsStateRepository: OfflineSettingsRepository {
    public let state: SettingsState<OfflineSettings>

    public init(state: SettingsState<OfflineSettings>) { self.state = state }

    /// Loads the row (creating it with `defaultDownloadDirectory` on first launch).
    public static func load(database: SplashDatabase, defaultDownloadDirectory: URL) async throws
        -> OfflineSettingsStateRepository
    {
        let state = try await SettingsState.load(
            from: GRDBOfflineSettingsStore(database.offline),
            default: OfflineSettings(downloadDirectory: defaultDownloadDirectory.path(percentEncoded: false)))
        return OfflineSettingsStateRepository(state: state)
    }

    public var isOfflineModeEnabled: Bool { state.value.isOfflineModeEnabled }
    public var userId: KomgaUserId { KomgaUserId(state.value.userId) }
    public var serverId: OfflineMediaServerId? { state.value.serverId.map(OfflineMediaServerId.init) }
    public var downloadDirectory: URL { URL(filePath: state.value.downloadDirectory, directoryHint: .isDirectory) }
    public var readProgressSyncDate: Date? { state.value.readProgressSyncDate }
    public var dataSyncDate: Date? { state.value.dataSyncDate }

    public func putOfflineMode(_ offline: Bool) async throws { try await state.set(\.isOfflineModeEnabled, offline) }
    public func putUserId(_ userId: KomgaUserId) async throws { try await state.set(\.userId, userId.rawValue) }
    public func putServerId(_ serverId: OfflineMediaServerId?) async throws {
        try await state.set(\.serverId, serverId?.rawValue)
    }
    public func putDownloadDirectory(_ directory: URL) async throws {
        try await state.set(\.downloadDirectory, directory.path(percentEncoded: false))
    }
    public func putReadProgressSyncDate(_ date: Date) async throws {
        try await state.set(\.readProgressSyncDate, date)
    }
    public func putDataSyncDate(_ date: Date) async throws { try await state.set(\.dataSyncDate, date) }

    public func offlineModeChanges() -> AsyncStream<Bool> { state.values(\.isOfflineModeEnabled) }

    public func userIdChanges() -> AsyncStream<KomgaUserId> {
        let upstream = state.values(\.userId)
        return AsyncStream { continuation in
            let task = Task {
                for await id in upstream { continuation.yield(KomgaUserId(id)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
