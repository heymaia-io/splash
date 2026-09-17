import Foundation
import Testing
@testable import SplashDB

@Suite struct OfflineTaskQueueTests {
    @Test func takesHighestPriorityThenOldest() async throws {
        let queue = OfflineTaskQueue(try SplashDatabase.inMemory().offline)
        try await queue.save([
            OfflineTaskRecord(uniqueName: "low", priority: 1, task: "{}", createdDate: fixedDate),
            OfflineTaskRecord(uniqueName: "high-new", priority: 5, task: "{}", createdDate: fixedDate + 10),
            OfflineTaskRecord(uniqueName: "high-old", priority: 5, task: "{}", createdDate: fixedDate),
        ])

        let first = try #require(try await queue.takeNew())
        #expect(first.uniqueName == "high-old")
        #expect(first.status == .running)
        #expect(try await queue.takeNew()?.uniqueName == "high-new")
        #expect(try await queue.takeNew()?.uniqueName == "low")
        #expect(try await queue.takeNew() == nil)

        #expect(try await queue.resetAllRunning() == 3)
        #expect(try await queue.takeNew()?.uniqueName == "high-old")
    }

    @Test func resaveKeepsCreatedDateAndDeleteRemoves() async throws {
        let database = try SplashDatabase.inMemory()
        let queue = OfflineTaskQueue(database.offline)
        try await queue.save(OfflineTaskRecord(uniqueName: "a", priority: 1, task: "{}", createdDate: fixedDate))
        try await queue.save(OfflineTaskRecord(uniqueName: "a", priority: 9, task: #"{"v":2}"#))

        let stored = try await database.offline.read { db in try OfflineTaskRecord.fetchOne(db, key: "a") }
        #expect(stored == OfflineTaskRecord(uniqueName: "a", priority: 9, task: #"{"v":2}"#, createdDate: fixedDate))

        try await queue.delete(uniqueName: "a")
        #expect(try await queue.takeNew() == nil)
    }

    @Test func concurrentClaimersNeverShareATask() async throws {
        let temp = try TemporaryDatabase()
        defer { temp.cleanup() }
        let queue = OfflineTaskQueue(temp.database.offline)
        let taskCount = 200
        try await queue.save((0..<taskCount).map {
            OfflineTaskRecord(uniqueName: "task-\($0)", priority: $0 % 7, task: "{}")
        })

        let claimed = try await withThrowingTaskGroup(of: [String].self) { group in
            for _ in 0..<8 {
                group.addTask {
                    var mine: [String] = []
                    while let task = try await queue.takeNew() { mine.append(task.uniqueName) }
                    return mine
                }
            }
            return try await group.reduce(into: []) { $0 += $1 }
        }
        #expect(claimed.count == taskCount)
        #expect(Set(claimed).count == taskCount)
    }
}
