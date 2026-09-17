import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.readprogress.OfflineReadProgress`.
public struct OfflineReadProgress: Hashable, Sendable {
    public var bookId: KomgaBookId
    public var userId: KomgaUserId
    public var page: Int
    public var completed: Bool
    public var readDate: Date
    public var deviceId: String
    public var deviceName: String
    public var locator: R2Locator?
    public var createdDate: Date
    public var lastModifiedDate: Date

    public init(
        bookId: KomgaBookId, userId: KomgaUserId, page: Int, completed: Bool, readDate: Date = Date(),
        deviceId: String = "", deviceName: String = "", locator: R2Locator? = nil, createdDate: Date = Date(),
        lastModifiedDate: Date = Date()
    ) {
        self.bookId = bookId
        self.userId = userId
        self.page = page
        self.completed = completed
        self.readDate = readDate
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.locator = locator
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }

    /// Wire representation used when rebuilding `KomgaBook.readProgress`.
    public var komgaReadProgress: ReadProgress {
        ReadProgress(
            page: page, completed: completed, readDate: readDate, deviceId: deviceId, deviceName: deviceName,
            created: createdDate, lastModified: lastModifiedDate)
    }
}

extension ReadProgress {
    /// `ReadProgress.toOfflineReadProgress(bookId, userId)`
    public func toOfflineReadProgress(bookId: KomgaBookId, userId: KomgaUserId, locator: R2Locator? = nil)
        -> OfflineReadProgress
    {
        OfflineReadProgress(
            bookId: bookId, userId: userId, page: page, completed: completed, readDate: readDate,
            deviceId: deviceId, deviceName: deviceName, locator: locator, createdDate: created,
            lastModifiedDate: lastModified)
    }
}

/// Port of `snd.komelia.offline.sync.model.OfflineLogEntry` (the `LOG_JOURNAL` table).
public struct OfflineLogEntry: Hashable, Sendable, Identifiable {
    public enum EntryType: String, Hashable, Sendable, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case error = "ERROR"
    }

    public var id: UUID
    public var message: String
    public var type: EntryType
    public var timestamp: Date

    public init(id: UUID = UUID(), message: String, type: EntryType, timestamp: Date = Date()) {
        self.id = id
        self.message = message
        self.type = type
        self.timestamp = timestamp
    }

    /// `infoLogEntry { }`
    public static func info(_ message: String) -> OfflineLogEntry { OfflineLogEntry(message: message, type: .info) }

    /// `errorLogEntry(e) { }` / `logError(e) { }` — message, newline, `<ErrorType>: <description>`.
    public static func error(_ message: String, _ error: (any Error)?) -> OfflineLogEntry {
        var text = message
        if let error { text += "\n\(Swift.type(of: error)): \(error)" }
        return OfflineLogEntry(message: text, type: .error)
    }
}
