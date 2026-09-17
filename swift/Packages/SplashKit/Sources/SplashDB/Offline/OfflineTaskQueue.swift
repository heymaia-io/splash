import Foundation
import GRDB

/// Port of `ExposedOfflineTasksRepository` (`OfflineTasksRepository`): the persistent download/sync task queue.
public struct OfflineTaskQueue: Sendable {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) { self.writer = writer }

    /// `takeNew()`: atomically flips the highest-priority (then oldest) NEW task to RUNNING and returns it.
    /// A single `UPDATE … RETURNING` inside the (IMMEDIATE) write transaction, so two workers can never
    /// claim the same task.
    public func takeNew() async throws -> OfflineTaskRecord? {
        try await writer.write { db in
            try OfflineTaskRecord.fetchAll(
                db,
                sql: """
                    UPDATE TASK SET status = 'RUNNING'
                    WHERE unique_name IN (
                        SELECT unique_name FROM TASK
                        WHERE status = 'NEW'
                        ORDER BY priority DESC, created_date ASC
                        LIMIT 1
                    )
                    RETURNING *
                    """
            ).first
        }
    }

    /// Upsert keyed by `unique_name`; like Kotlin's `onUpdateExclude = createdDate`, re-saving a task keeps its
    /// original queue position.
    public func save(_ tasks: [OfflineTaskRecord]) async throws {
        try await writer.write { db in
            let statement = try db.cachedStatement(sql: """
                INSERT INTO TASK (unique_name, priority, status, task, created_date) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT (unique_name) DO UPDATE
                SET priority = excluded.priority, status = excluded.status, task = excluded.task
                """)
            for task in tasks {
                try statement.execute(arguments: [
                    task.uniqueName, task.priority, task.status.rawValue, task.task, task.createdDate,
                ])
            }
        }
    }

    public func save(_ task: OfflineTaskRecord) async throws {
        try await save([task])
    }

    public func delete(uniqueName: String) async throws {
        _ = try await writer.write { db in try OfflineTaskRecord.deleteOne(db, key: uniqueName) }
    }

    /// Deletes the task only if nobody claimed it yet (status NEW). Returns whether a row was removed.
    public func deletePending(uniqueName: String) async throws -> Bool {
        try await writer.write { db in
            try db.execute(literal: "DELETE FROM TASK WHERE unique_name = \(uniqueName) AND status = 'NEW'")
            return db.changesCount > 0
        }
    }

    /// Returns tasks left RUNNING by a previous process to NEW (called on startup). Returns the count reset.
    @discardableResult
    public func resetAllRunning() async throws -> Int {
        try await writer.write { db in
            try db.execute(sql: "UPDATE TASK SET status = 'NEW' WHERE status = 'RUNNING'")
            return db.changesCount
        }
    }
}
