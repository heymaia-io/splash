import Foundation
import KomgaAPI
import Synchronization
import Testing

@testable import SplashOffline

/// Records launches; downloads block until released (or cancelled), like a real transfer.
final class FakeDownloadManager: PlatformDownloadManager {
    private struct State {
        var launched: [KomgaBookId] = []
        var cancelled: [KomgaBookId] = []
        var gates: [KomgaBookId: CheckedContinuation<Void, Never>] = [:]
        var released: Set<KomgaBookId> = []
    }

    private let state = Mutex(State())
    let blocking: Bool

    init(blocking: Bool = false) { self.blocking = blocking }

    var launched: [KomgaBookId] { state.withLock { $0.launched } }
    var cancelled: [KomgaBookId] { state.withLock { $0.cancelled } }

    func launchBookDownload(_ bookId: KomgaBookId) async throws {
        state.withLock { $0.launched.append(bookId) }
        guard blocking else { return }
        await withCheckedContinuation { continuation in
            state.withLock { state in
                if state.released.contains(bookId) { continuation.resume() } else { state.gates[bookId] = continuation }
            }
        }
    }

    func cancelBookDownload(_ bookId: KomgaBookId) async {
        state.withLock { state in
            state.cancelled.append(bookId)
            state.released.insert(bookId)
            state.gates.removeValue(forKey: bookId)?.resume()
        }
    }

    func waitForLaunch(of bookId: KomgaBookId) async {
        while !launched.contains(bookId) { try? await Task.sleep(for: .milliseconds(10)) }
    }
}

@Suite(.serialized, .timeLimit(.minutes(1)))
struct TaskQueueTests {
    private func processor(
        _ env: OfflineTestEnvironment, manager: FakeDownloadManager, seriesBooks: [KomgaSeriesId: [KomgaBookId]]
    ) -> TaskProcessor {
        let handler = TaskHandler(
            actions: env.actions, tasksRepository: env.tasks, downloadManager: manager,
            seriesBookIds: { seriesBooks[$0] ?? [] })
        return TaskProcessor(tasksRepository: env.tasks, handler: handler, taskEmitter: env.emitter, store: env.store)
    }

    @Test func downloadSeriesFansOutToOneTaskPerBook() async throws {
        let env = try await OfflineTestEnvironment.make()
        defer { env.cleanup() }
        let manager = FakeDownloadManager()
        let processor = processor(env, manager: manager, seriesBooks: ["S1": ["B1", "B2", "B3"]])
        await processor.start()

        try await env.emitter.downloadSeries("S1")
        await processor.waitUntilIdle()

        #expect(Set(manager.launched) == ["B1", "B2", "B3"])
        #expect(manager.launched.count == 3)
        #expect(try await env.tasks.findAll().isEmpty)  // every task deleted once handled
        await processor.stop()
    }

    @Test func queuedTasksPersistUntilTheProcessorRuns() async throws {
        let env = try await OfflineTestEnvironment.make()
        defer { env.cleanup() }
        try await env.emitter.downloadBooks(["B1", "B2"])
        try await env.emitter.downloadBook("B1")  // same unique name: still one task
        #expect(try await env.tasks.findAll().map(\.task) == [.downloadBook("B1"), .downloadBook("B2")])

        let manager = FakeDownloadManager()
        let processor = processor(env, manager: manager, seriesBooks: [:])
        await processor.start()
        await processor.waitUntilIdle()
        #expect(Set(manager.launched) == ["B1", "B2"])
        await processor.stop()
    }

    @Test func cancelStopsARunningDownloadAndDequeuesPendingOnes() async throws {
        let env = try await OfflineTestEnvironment.make()
        defer { env.cleanup() }

        // B2 is still pending (processor not started): cancelling dequeues it without launching.
        try await env.emitter.downloadBook("B2", priority: TaskEntry.lowPriority)
        try await env.emitter.cancelBookDownload("B2")

        let manager = FakeDownloadManager(blocking: true)
        let processor = processor(env, manager: manager, seriesBooks: [:])
        await processor.start()
        await processor.waitUntilIdle()
        #expect(manager.launched.isEmpty)
        #expect(manager.cancelled == ["B2"])

        // B1 is running (blocked in the manager): cancel reaches the manager and the task finishes.
        try await env.emitter.downloadBook("B1")
        await manager.waitForLaunch(of: "B1")
        try await env.emitter.cancelBookDownload("B1")
        await processor.waitUntilIdle()
        #expect(manager.cancelled == ["B2", "B1"])
        #expect(try await env.tasks.findAll().isEmpty)
        await processor.stop()
    }

    @Test func runningTasksAreResetOnRestart() async throws {
        let env = try await OfflineTestEnvironment.make()
        defer { env.cleanup() }
        try await env.emitter.downloadBook("B1")
        _ = try await env.tasks.takeNew()  // simulate a process killed mid-download
        #expect(try await env.tasks.takeNew() == nil)

        let manager = FakeDownloadManager()
        let processor = processor(env, manager: manager, seriesBooks: [:])
        await processor.start()
        await processor.waitUntilIdle()
        #expect(manager.launched == ["B1"])
        await processor.stop()
    }

    @Test func deleteTasksRunTheDeleteActions() async throws {
        let env = try await OfflineTestEnvironment.make()
        defer { env.cleanup() }
        let series = Fixtures.series("S1", library: "L1", title: "Alpha", booksCount: 1)
        try await env.importHierarchy(
            libraries: [Fixtures.library("L1", name: "Comics")], series: [series], user: Fixtures.user)
        let book = Fixtures.book("B1", series: series, number: 1)
        try await env.importBook(book, file: Data("x".utf8), userId: Fixtures.user.id)
        let file = env.locator.fileURL(for: try await env.store.read { try $0.books.get("B1").fileDownloadPath })

        let processor = processor(env, manager: FakeDownloadManager(), seriesBooks: [:])
        await processor.start()
        await processor.waitUntilIdle()  // aggregate task from the import
        try await env.emitter.deleteSeries("S1")
        await processor.waitUntilIdle()

        #expect(try await env.store.read { try $0.series.find("S1") } == nil)
        #expect(try await env.store.read { try $0.books.find("B1") } == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(try await env.tasks.findAll().isEmpty)
        await processor.stop()
    }
}
