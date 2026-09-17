import Foundation
import GRDB
import Testing
@testable import SplashDB

@Suite struct OfflineRecordTests {
    @Test func bookMediaAndPagesRoundTripAndCascade() async throws {
        let database = try SplashDatabase.inMemory()
        let media = OfflineMediaRecord(
            bookId: "book-1", status: "READY", mediaType: "application/zip", mediaProfile: "DIVINA",
            pageCount: 2, comment: nil, extension: #"{"type":"none"}"#)
        let pages = [
            OfflineMediaPageRecord(
                bookId: "book-1", number: 1, fileName: "001.jpg", mediaType: "image/jpeg",
                width: 1200, height: 1800, fileSize: 400_000),
            OfflineMediaPageRecord(bookId: "book-1", number: 2, fileName: "002.png", mediaType: "image/png"),
        ]

        try await database.offline.write { db in
            try insertBook("book-1", in: db)
            try media.insert(db)
            for page in pages { try page.insert(db) }
        }

        try await database.offline.read { db in
            #expect(try OfflineBookRecord.fetchOne(db, key: "book-1") == makeBook("book-1"))
            #expect(try OfflineMediaRecord.fetchOne(db, key: "book-1") == media)
            let fetched = try OfflineMediaPageRecord.order(Column("number")).fetchAll(db)
            #expect(fetched == pages)
        }

        // BOOK → MEDIA_PAGE cascades (added FK). MEDIA keeps the original non-cascading FK, so delete it first.
        try await database.offline.write { db in
            _ = try OfflineMediaRecord.deleteOne(db, key: "book-1")
            _ = try OfflineBookRecord.deleteOne(db, key: "book-1")
        }
        #expect(try await database.offline.read(OfflineMediaPageRecord.fetchCount) == 0)
    }

    @Test func foreignKeysAreEnforced() async throws {
        let database = try SplashDatabase.inMemory()
        await #expect(throws: DatabaseError.self) {
            try await database.offline.write { db in
                try OfflineMediaPageRecord(bookId: "missing", number: 1, fileName: "a", mediaType: "b").insert(db)
            }
        }
    }

    @Test func columnDefaultsUseGRDBDateFormat() async throws {
        let database = try SplashDatabase.inMemory()
        let before = Date().addingTimeInterval(-1)
        try await database.offline.write { db in
            try db.execute(sql: """
                INSERT INTO TASK (unique_name, priority, status, task) VALUES ('t', 1, 'NEW', '{}')
                """)
        }
        let task = try await database.offline.read { db in try OfflineTaskRecord.fetchOne(db, key: "t") }
        let created = try #require(task?.createdDate)
        #expect(created > before && created < Date().addingTimeInterval(1))
    }

    @Test func thumbnailBlobRoundTrip() async throws {
        let database = try SplashDatabase.inMemory()
        let thumbnail = OfflineThumbnailBookRecord(
            id: "thumb-1", bookId: "book-1", thumbnail: Data([0xFF, 0xD8, 0xFF]), url: nil, type: "GENERATED",
            selected: true, mediaType: "image/jpeg", fileSize: 3, width: 300, height: 450)
        try await database.offline.write { db in
            try insertBook("book-1", in: db)
            try thumbnail.insert(db)
        }
        #expect(try await database.offline.read { db in try OfflineThumbnailBookRecord.fetchOne(db, key: "thumb-1") }
            == thumbnail)
    }

    @Test func poolAllowsReadsDuringWrites() async throws {
        let temp = try TemporaryDatabase()
        defer { temp.cleanup() }
        let pool = temp.database.offline
        #expect(pool is DatabasePool)
        try await pool.write { db in try insertBook("book-0", in: db) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 1...100 {
                    try await pool.write { db in
                        try makeBook("book-\(i)").insert(db)
                        try OfflineMediaPageRecord(
                            bookId: "book-\(i)", number: 1, fileName: "p", mediaType: "image/png"
                        ).insert(db)
                    }
                }
            }
            for _ in 0..<4 {
                group.addTask {
                    var last = 0
                    for _ in 0..<100 {
                        let count = try await pool.read(OfflineBookRecord.fetchCount)
                        #expect(count >= last)  // snapshot isolation: counts never go backwards
                        last = count
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(try await pool.read(OfflineBookRecord.fetchCount) == 101)
    }
}
