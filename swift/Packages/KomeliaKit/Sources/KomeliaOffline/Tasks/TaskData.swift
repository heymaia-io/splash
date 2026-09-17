import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.tasks.model.TaskData` — persisted as JSON in `TASK.task`.
///
/// Wire format mirrors kotlinx.serialization's sealed-class output (`{"type":"DownloadBook","bookId":"…"}`).
/// Not ported: `ScanLibrary`, `EmptyTrash`, `RefreshBookMetadata`, `RefreshSeriesMetadata` — their Kotlin
/// handlers are no-ops / `TODO()` (offline mode never scans or refreshes); unknown rows are dropped on decode.
public enum TaskData: Hashable, Sendable {
    case aggregateSeriesMetadata(KomgaSeriesId)
    case deleteBook(KomgaBookId)
    /// Stored `OfflineBook.fileDownloadPath` (Kotlin: `PlatformFile`).
    case deleteBookFiles(String)
    case deleteSeries(KomgaSeriesId)
    case deleteLibrary(KomgaLibraryId)
    case downloadBook(KomgaBookId)
    case downloadSeries(KomgaSeriesId)
    case downloadBookCancel(KomgaBookId)

    /// `TaskData.uniqueName` — the TASK primary key, so re-submitting the same work is idempotent.
    public var uniqueName: String {
        switch self {
        case .aggregateSeriesMetadata(let id): "AggregateSeriesMetadata_\(id)"
        case .deleteBook(let id): "DeleteBook_\(id)"
        case .deleteBookFiles(let path): "DeleteBookFiles_\(path)"
        case .deleteSeries(let id): "DeleteSeries_\(id)"
        case .deleteLibrary(let id): "DeleteLibrary_\(id)"
        case .downloadBook(let id): "DownloadBook_\(id)"
        case .downloadSeries(let id): "DownloadSeries_\(id)"
        case .downloadBookCancel(let id): "DownloadBookCancel_\(id)"
        }
    }
}

extension TaskData: Codable {
    private enum CodingKeys: String, CodingKey { case type, seriesId, bookId, libraryId, file }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "AggregateSeriesMetadata": self = .aggregateSeriesMetadata(try c.decode(KomgaSeriesId.self, forKey: .seriesId))
        case "DeleteBook": self = .deleteBook(try c.decode(KomgaBookId.self, forKey: .bookId))
        case "DeleteBookFiles": self = .deleteBookFiles(try c.decode(String.self, forKey: .file))
        case "DeleteSeries": self = .deleteSeries(try c.decode(KomgaSeriesId.self, forKey: .seriesId))
        case "DeleteLibrary": self = .deleteLibrary(try c.decode(KomgaLibraryId.self, forKey: .libraryId))
        case "DownloadBook": self = .downloadBook(try c.decode(KomgaBookId.self, forKey: .bookId))
        case "DownloadSeries": self = .downloadSeries(try c.decode(KomgaSeriesId.self, forKey: .seriesId))
        case "DownloadBookCancel": self = .downloadBookCancel(try c.decode(KomgaBookId.self, forKey: .bookId))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unsupported task \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .aggregateSeriesMetadata(let id):
            try c.encode("AggregateSeriesMetadata", forKey: .type); try c.encode(id, forKey: .seriesId)
        case .deleteBook(let id): try c.encode("DeleteBook", forKey: .type); try c.encode(id, forKey: .bookId)
        case .deleteBookFiles(let path):
            try c.encode("DeleteBookFiles", forKey: .type); try c.encode(path, forKey: .file)
        case .deleteSeries(let id): try c.encode("DeleteSeries", forKey: .type); try c.encode(id, forKey: .seriesId)
        case .deleteLibrary(let id):
            try c.encode("DeleteLibrary", forKey: .type); try c.encode(id, forKey: .libraryId)
        case .downloadBook(let id): try c.encode("DownloadBook", forKey: .type); try c.encode(id, forKey: .bookId)
        case .downloadSeries(let id):
            try c.encode("DownloadSeries", forKey: .type); try c.encode(id, forKey: .seriesId)
        case .downloadBookCancel(let id):
            try c.encode("DownloadBookCancel", forKey: .type); try c.encode(id, forKey: .bookId)
        }
    }
}

/// Port of `TaskEntry` + the priority constants of TaskData.kt.
public struct TaskEntry: Hashable, Sendable {
    public enum Status: String, Hashable, Sendable {
        case new = "NEW"
        case running = "RUNNING"
    }

    public static let highestPriority = 8
    public static let highPriority = 6
    public static let defaultPriority = 4
    public static let lowPriority = 2
    public static let lowestPriority = 0

    public var task: TaskData
    public var priority: Int
    public var status: Status
    public var uniqueName: String

    public init(task: TaskData, priority: Int = TaskEntry.defaultPriority, status: Status = .new) {
        self.task = task
        self.priority = priority
        self.status = status
        self.uniqueName = task.uniqueName
    }
}

/// Port of `snd.komelia.offline.tasks.repository.OfflineTasksRepository`.
public protocol OfflineTasksRepository: Sendable {
    /// Atomically claims the highest-priority NEW task (NEW → RUNNING). Rows that cannot be decoded are deleted.
    func takeNew() async throws -> TaskEntry?
    func save(_ entries: [TaskEntry]) async throws
    func delete(uniqueName: String) async throws
    /// Deletes the task only while it is still NEW (not claimed yet); returns whether a row was removed.
    func deletePending(uniqueName: String) async throws -> Bool
    func resetAllRunning() async throws -> Int
}
