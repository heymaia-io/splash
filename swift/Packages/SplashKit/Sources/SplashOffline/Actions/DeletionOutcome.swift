import Foundation
import KomgaAPI

/// Side effects of a delete that must run only after the transaction commits (events + file removal tasks).
/// Lets `LibraryDeleteAction → SeriesDeleteManyAction → BookDeleteManyAction` compose inside ONE transaction,
/// which Kotlin achieved with nested `TransactionTemplate.execute` calls.
struct DeletionOutcome: Sendable {
    var events: [KomgaEvent] = []
    var filePaths: [String] = []

    mutating func merge(_ other: DeletionOutcome) {
        events += other.events
        filePaths += other.filePaths
    }

    func publish(events broadcaster: KomgaEventBroadcaster, taskEmitter: OfflineTaskEmitter) async throws {
        for event in events { broadcaster.emit(event) }
        try await taskEmitter.deleteBookFiles(filePaths)
    }
}

/// Dependencies shared by every action (Kotlin passed them one by one to each constructor).
public struct OfflineActionEnvironment: Sendable {
    public let store: any OfflineDataStore
    public let events: KomgaEventBroadcaster
    public let taskEmitter: OfflineTaskEmitter
    public let settings: any OfflineSettingsRepository
    public let fileLocator: OfflineFileLocator

    public init(
        store: any OfflineDataStore, events: KomgaEventBroadcaster, taskEmitter: OfflineTaskEmitter,
        settings: any OfflineSettingsRepository, fileLocator: OfflineFileLocator? = nil
    ) {
        self.store = store
        self.events = events
        self.taskEmitter = taskEmitter
        self.settings = settings
        self.fileLocator = fileLocator ?? OfflineFileLocator(settings: settings)
    }

    /// Kotlin `isOffline: StateFlow<Boolean>` — decides between `*Deleted` and `*Changed` events.
    var isOffline: Bool { settings.isOfflineModeEnabled }
}
