import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.tasks.OfflineTaskEmitter` — the only entry point for queued offline work.
/// Every submission is persisted first (survives app termination) and then wakes the `TaskProcessor`.
public struct OfflineTaskEmitter: Sendable {
    private let tasksRepository: any OfflineTasksRepository
    /// `MutableSharedFlow<TaskAddedEvent>`
    let taskAdded: AsyncBroadcaster<Void>

    public init(tasksRepository: any OfflineTasksRepository, taskAdded: AsyncBroadcaster<Void> = AsyncBroadcaster()) {
        self.tasksRepository = tasksRepository
        self.taskAdded = taskAdded
    }

    public func aggregateSeriesMetadata(_ seriesId: KomgaSeriesId, priority: Int = TaskEntry.defaultPriority)
        async throws
    {
        try await submit([TaskEntry(task: .aggregateSeriesMetadata(seriesId), priority: priority)])
    }

    public func deleteBook(_ bookId: KomgaBookId, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .deleteBook(bookId), priority: priority)])
    }

    public func deleteBookFiles(_ storedPath: String, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .deleteBookFiles(storedPath), priority: priority)])
    }

    public func deleteBookFiles(_ storedPaths: [String], priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit(storedPaths.map { TaskEntry(task: .deleteBookFiles($0), priority: priority) })
    }

    public func deleteSeries(_ seriesId: KomgaSeriesId, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .deleteSeries(seriesId), priority: priority)])
    }

    public func deleteLibrary(_ libraryId: KomgaLibraryId, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .deleteLibrary(libraryId), priority: priority)])
    }

    public func downloadBook(_ bookId: KomgaBookId, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .downloadBook(bookId), priority: priority)])
    }

    public func downloadBooks(_ bookIds: [KomgaBookId], priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit(bookIds.map { TaskEntry(task: .downloadBook($0), priority: priority) })
    }

    public func downloadSeries(_ seriesId: KomgaSeriesId, priority: Int = TaskEntry.defaultPriority) async throws {
        try await submit([TaskEntry(task: .downloadSeries(seriesId), priority: priority)])
    }

    /// [NUEVO] A download that has not been claimed yet is dequeued right away; the cancel task (which jumps the
    /// queue — Kotlin used the default priority) then stops a transfer that is already running.
    public func cancelBookDownload(_ bookId: KomgaBookId, priority: Int = TaskEntry.highestPriority) async throws {
        _ = try await tasksRepository.deletePending(uniqueName: TaskData.downloadBook(bookId).uniqueName)
        try await submit([TaskEntry(task: .downloadBookCancel(bookId), priority: priority)])
    }

    private func submit(_ entries: [TaskEntry]) async throws {
        guard !entries.isEmpty else { return }
        try await tasksRepository.save(entries)
        taskAdded.emit(())
    }
}
