import GRDB
import KomgaAPI
import SplashCore
import Testing
@testable import SplashDB

/// The store is the only thing standing between the user's hidden set and a silent wipe, so these tests are
/// mostly about *tolerance*: a bad or unrecognised blob must degrade to "nothing hidden", never throw.
@Suite struct PrivacyStoreTests {
    private func store() throws -> (SplashDatabase, GRDBPrivacyStore<PrivacyState>) {
        let database = try SplashDatabase.inMemory()
        return (database, GRDBPrivacyStore<PrivacyState>(database.app))
    }

    @Test func emptyDatabaseLoadsNothing() async throws {
        let (_, store) = try store()
        #expect(try await store.load() == nil)
    }

    @Test func roundTripsThePerServerSets() async throws {
        let (_, store) = try store()
        var state = PrivacyState()
        state.lockPolicy = .afterTimeout
        state.lockTimeout = 900
        state.update("https://a.example") { $0.series.insert(KomgaSeriesId("s1")) }
        state.update("https://b.example") { $0.books.insert(KomgaBookId("b1")) }
        try await store.save(state)

        let loaded = try #require(try await store.load())
        #expect(loaded == state)
        #expect(loaded.content(for: "https://a.example").series == [KomgaSeriesId("s1")])
        #expect(loaded.content(for: "https://b.example").books == [KomgaBookId("b1")])
        #expect(loaded.content(for: "https://c.example").isEmpty)
    }

    @Test func savingTwiceReplacesTheSingletonRow() async throws {
        let (database, store) = try store()
        var state = PrivacyState()
        state.update("https://a.example") { $0.libraries.insert(KomgaLibraryId("l1")) }
        try await store.save(state)
        state.update("https://a.example") { $0.libraries.insert(KomgaLibraryId("l2")) }
        try await store.save(state)

        let rows = try await database.app.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Privacy")
        }
        #expect(rows == 1)
        #expect(try await store.load()?.content(for: "https://a.example").libraries.count == 2)
    }

    /// A shape this build does not understand must not throw — `load()` would turn the throw into `nil`, the
    /// defaults would be re-saved, and the user's hidden set would be gone.
    @Test func unrecognisedPayloadDegradesToNothingHidden() async throws {
        let (database, store) = try store()
        try await database.app.write { db in
            try db.execute(
                sql: "INSERT INTO Privacy (version, state) VALUES (1, ?)",
                arguments: [#"{"somethingFromTheFuture": 1}"#])
        }
        let loaded = try #require(try await store.load())
        #expect(loaded.byServer.isEmpty)
        #expect(loaded.lockPolicy == .onLeaving)
    }

    /// Preferences survive even when the sets cannot be read.
    @Test func lockPreferencesSurviveAnUnreadableSet() async throws {
        let (database, store) = try store()
        try await database.app.write { db in
            try db.execute(
                sql: "INSERT INTO Privacy (version, state) VALUES (1, ?)",
                arguments: [#"{"lockPolicy": "UNTIL_APP_QUITS", "lockTimeout": 60, "byServer": "not-an-object"}"#])
        }
        let loaded = try #require(try await store.load())
        #expect(loaded.lockPolicy == .untilAppQuits)
        #expect(loaded.lockTimeout == 60)
        #expect(loaded.byServer.isEmpty)
    }

    @Test func malformedJsonLoadsNil() async throws {
        let (database, store) = try store()
        try await database.app.write { db in
            try db.execute(sql: "INSERT INTO Privacy (version, state) VALUES (1, ?)", arguments: ["{{{"])
        }
        #expect(try await store.load() == nil)
    }
}
