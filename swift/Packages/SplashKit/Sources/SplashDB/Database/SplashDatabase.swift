import Foundation
import GRDB

/// Port of `snd.komelia.db.KomeliaDatabase`: two SQLite files, each migrated on open.
///
/// Kotlin used a 1-connection Hikari pool per file (WAL, `foreign_keys=ON`, `busy_timeout=5000`, IMMEDIATE
/// write transactions) plus a separate read-only data source for offline reads. A GRDB `DatabasePool` is the
/// same shape in one object: WAL, a single serialized writer (IMMEDIATE transactions by default) and a
/// concurrent read pool.
public final class SplashDatabase: Sendable {
    public static let appFileName = "splash.sqlite"
    public static let offlineFileName = "offline.sqlite"

    /// App settings / home screen filters (`splash.sqlite`).
    public let app: any DatabaseWriter
    /// Offline mirror of Komga entities + task queue (`offline.sqlite`).
    public let offline: any DatabaseWriter

    /// Opens (creating if needed) both databases inside `directory` and runs their migrations.
    public convenience init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = Self.configuration()
        try self.init(
            app: DatabasePool(path: directory.appending(path: Self.appFileName).path, configuration: config),
            offline: DatabasePool(path: directory.appending(path: Self.offlineFileName).path, configuration: config))
    }

    /// Wraps already-opened writers (e.g. in-memory `DatabaseQueue`s in tests) and migrates them.
    public init(app: any DatabaseWriter, offline: any DatabaseWriter) throws {
        try AppMigrations.migrator.migrate(app)
        try OfflineMigrations.migrator.migrate(offline)
        self.app = app
        self.offline = offline
    }

    /// Two private in-memory databases — for tests and previews.
    public static func inMemory() throws -> SplashDatabase {
        let config = configuration()
        return try SplashDatabase(
            app: DatabaseQueue(configuration: config),
            offline: DatabaseQueue(configuration: config))
    }

    /// Pragmas mirrored from the Xerial `SQLiteConfig` in Kotlin. WAL is implied by `DatabasePool`.
    public static func configuration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.busyMode = .timeout(5)
        return config
    }
}
