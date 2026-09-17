import Foundation
import GRDB
import SplashOffline
import KomgaAPI

/// Port of `ExposedOfflineSeriesRepository`.
struct GRDBSeriesRepository: OfflineSeriesRepository {
    let db: Database

    func save(_ series: OfflineSeries) throws {
        try OfflineSeriesRecord(
            id: series.id.rawValue, libraryId: series.libraryId.rawValue, name: series.name, url: series.url,
            booksCount: series.bookCount, deleted: series.deleted, oneshot: series.oneshot,
            createdDate: series.created, lastModifiedDate: series.lastModified,
            fileLastModifiedDate: series.fileLastModified
        ).upsert(db)
    }

    func find(_ id: KomgaSeriesId) throws -> OfflineSeries? {
        try OfflineSeriesRecord.fetchOne(db, key: id.rawValue).map(Self.model)
    }

    func findAllByLibraryId(_ libraryId: KomgaLibraryId) throws -> [OfflineSeries] {
        try OfflineSeriesRecord.filter(Column("library_id") == libraryId.rawValue).fetchAll(db).map(Self.model)
    }

    func delete(_ ids: [KomgaSeriesId]) throws {
        _ = try OfflineSeriesRecord.deleteAll(db, keys: ids.map(\.rawValue))
    }

    private static func model(_ r: OfflineSeriesRecord) -> OfflineSeries {
        OfflineSeries(
            id: KomgaSeriesId(r.id), libraryId: KomgaLibraryId(r.libraryId), name: r.name, url: r.url,
            oneshot: r.oneshot, bookCount: r.booksCount, deleted: r.deleted, created: r.createdDate,
            lastModified: r.lastModifiedDate, fileLastModified: r.fileLastModifiedDate)
    }
}

/// Port of `ExposedOfflineSeriesMetadataRepository` (genres, tags, sharing labels, links and alternate titles live
/// in child tables). Fix: Kotlin inserted the *genres* into the tag table.
struct GRDBSeriesMetadataRepository: OfflineSeriesMetadataRepository {
    let db: Database

    private static let childTables = [
        "SERIES_METADATA_GENRE", "SERIES_METADATA_TAG", "SERIES_METADATA_SHARING", "SERIES_METADATA_LINK",
        "SERIES_METADATA_ALTERNATE_TITLE",
    ]

    func save(_ offline: OfflineSeriesMetadata) throws {
        let m = offline.metadata
        let id = offline.seriesId.rawValue
        try OfflineSeriesMetadataRecord(
            seriesId: id, status: m.status.rawValue, statusLock: m.statusLock, title: m.title, titleLock: m.titleLock,
            titleSort: m.titleSort, titleSortLock: m.titleSortLock, alternateTitlesLock: m.alternateTitlesLock,
            publisher: m.publisher, publisherLock: m.publisherLock, summary: m.summary, summaryLock: m.summaryLock,
            readingDirection: m.readingDirection?.rawValue, readingDirectionLock: m.readingDirectionLock,
            ageRating: m.ageRating, ageRatingLock: m.ageRatingLock, language: m.language,
            languageLock: m.languageLock, genresLock: m.genresLock, tagsLock: m.tagsLock,
            totalBookCount: m.totalBookCount, totalBookCountLock: m.totalBookCountLock,
            sharingLabelsLock: m.sharingLabelsLock, linksLock: m.linksLock
        ).upsert(db)
        try deleteChildren([id])
        for genre in Set(m.genres) {
            try db.execute(literal: "INSERT INTO SERIES_METADATA_GENRE (series_id, genre) VALUES (\(id), \(genre))")
        }
        for tag in Set(m.tags) {
            try db.execute(literal: "INSERT INTO SERIES_METADATA_TAG (series_id, tag) VALUES (\(id), \(tag))")
        }
        for label in Set(m.sharingLabels) {
            try db.execute(literal: "INSERT INTO SERIES_METADATA_SHARING (series_id, label) VALUES (\(id), \(label))")
        }
        for link in m.links {
            try db.execute(literal: """
                INSERT OR IGNORE INTO SERIES_METADATA_LINK (series_id, label, url) VALUES (\(id), \(link.label), \(link.url))
                """)
        }
        for title in m.alternateTitles {
            try db.execute(literal: """
                INSERT OR IGNORE INTO SERIES_METADATA_ALTERNATE_TITLE (series_id, label, title)
                VALUES (\(id), \(title.label), \(title.title))
                """)
        }
    }

    func find(_ id: KomgaSeriesId) throws -> OfflineSeriesMetadata? {
        guard let record = try OfflineSeriesMetadataRecord.fetchOne(db, key: id.rawValue) else { return nil }
        let children = try SeriesMetadataChildren.load(db, seriesIds: [id.rawValue])
        return OfflineSeriesMetadata(seriesId: id, metadata: children.metadata(for: record))
    }

    func delete(_ ids: [KomgaSeriesId]) throws {
        let keys = ids.map(\.rawValue)
        try deleteChildren(keys)
        _ = try OfflineSeriesMetadataRecord.deleteAll(db, keys: keys)
    }

    private func deleteChildren(_ ids: [String]) throws {
        for table in Self.childTables {
            try db.execute(literal: "DELETE FROM \(identifier: table) WHERE series_id IN \(ids)")
        }
    }
}

/// Batch loader of the series metadata child tables (shared by the metadata and DTO repositories).
struct SeriesMetadataChildren {
    var genres: [String: [String]]
    var tags: [String: [String]]
    var sharingLabels: [String: [String]]
    var links: [String: [(String, String)]]
    var alternateTitles: [String: [(String, String)]]

    static func load(_ db: Database, seriesIds ids: [String]) throws -> SeriesMetadataChildren {
        SeriesMetadataChildren(
            genres: try GroupedRows.strings(
                db, "SELECT series_id, genre FROM SERIES_METADATA_GENRE WHERE series_id IN \(ids) ORDER BY genre"),
            tags: try GroupedRows.strings(
                db, "SELECT series_id, tag FROM SERIES_METADATA_TAG WHERE series_id IN \(ids) ORDER BY tag"),
            sharingLabels: try GroupedRows.strings(
                db, "SELECT series_id, label FROM SERIES_METADATA_SHARING WHERE series_id IN \(ids) ORDER BY label"),
            links: try GroupedRows.pairs(
                db, "SELECT series_id, label, url FROM SERIES_METADATA_LINK WHERE series_id IN \(ids)"),
            alternateTitles: try GroupedRows.pairs(
                db, "SELECT series_id, label, title FROM SERIES_METADATA_ALTERNATE_TITLE WHERE series_id IN \(ids)"))
    }

    func metadata(for r: OfflineSeriesMetadataRecord) -> KomgaSeriesMetadata {
        let id = r.seriesId
        return KomgaSeriesMetadata(
            status: KomgaSeriesStatus(rawValue: r.status) ?? .ongoing, statusLock: r.statusLock, title: r.title,
            alternateTitles: (alternateTitles[id] ?? []).map { KomgaAlternativeTitle(label: $0.0, title: $0.1) },
            alternateTitlesLock: r.alternateTitlesLock, titleLock: r.titleLock, titleSort: r.titleSort,
            titleSortLock: r.titleSortLock, summary: r.summary, summaryLock: r.summaryLock,
            readingDirection: r.readingDirection.flatMap(KomgaReadingDirection.init(rawValue:)),
            readingDirectionLock: r.readingDirectionLock, publisher: r.publisher, publisherLock: r.publisherLock,
            ageRating: r.ageRating, ageRatingLock: r.ageRatingLock, language: r.language,
            languageLock: r.languageLock, genres: genres[id] ?? [], genresLock: r.genresLock, tags: tags[id] ?? [],
            tagsLock: r.tagsLock, totalBookCount: r.totalBookCount, totalBookCountLock: r.totalBookCountLock,
            sharingLabels: sharingLabels[id] ?? [], sharingLabelsLock: r.sharingLabelsLock,
            links: (links[id] ?? []).map { KomgaWebLink(label: $0.0, url: $0.1) }, linksLock: r.linksLock)
    }
}

/// Port of `ExposedOfflineThumbnailSeriesRepository`.
struct GRDBThumbnailSeriesRepository: OfflineThumbnailSeriesRepository {
    let db: Database

    func save(_ t: OfflineThumbnailSeries) throws {
        try OfflineThumbnailSeriesRecord(
            id: t.id.rawValue, seriesId: t.seriesId.rawValue, thumbnail: t.thumbnail, url: t.url,
            type: t.type.rawValue, selected: t.selected, mediaType: t.mediaType, fileSize: t.fileSize,
            width: t.width, height: t.height
        ).upsert(db)
    }

    func find(_ id: KomgaThumbnailId) throws -> OfflineThumbnailSeries? {
        try OfflineThumbnailSeriesRecord.fetchOne(db, key: id.rawValue).map(Self.model)
    }

    func findSelectedBySeriesId(_ seriesId: KomgaSeriesId) throws -> OfflineThumbnailSeries? {
        try OfflineThumbnailSeriesRecord
            .filter(Column("series_id") == seriesId.rawValue && Column("selected") == true)
            .fetchOne(db).map(Self.model)
    }

    func findAllBySeriesId(_ seriesId: KomgaSeriesId) throws -> [OfflineThumbnailSeries] {
        try OfflineThumbnailSeriesRecord.filter(Column("series_id") == seriesId.rawValue).fetchAll(db).map(Self.model)
    }

    func deleteBySeriesIds(_ seriesIds: [KomgaSeriesId]) throws {
        _ = try OfflineThumbnailSeriesRecord.filter(seriesIds.map(\.rawValue).contains(Column("series_id")))
            .deleteAll(db)
    }

    private static func model(_ r: OfflineThumbnailSeriesRecord) -> OfflineThumbnailSeries {
        OfflineThumbnailSeries(
            id: KomgaThumbnailId(r.id), seriesId: KomgaSeriesId(r.seriesId),
            type: .init(rawValue: r.type) ?? .sidecar, selected: r.selected, mediaType: r.mediaType,
            fileSize: r.fileSize, width: r.width, height: r.height, url: r.url, thumbnail: r.thumbnail)
    }
}

/// Port of `ExposedOfflineBookMetadataAggregationRepository` (Kotlin's `find` filtered on the tag table's column
/// by mistake; fixed).
struct GRDBBookMetadataAggregationRepository: OfflineBookMetadataAggregationRepository {
    let db: Database

    func save(_ a: OfflineBookMetadataAggregation) throws {
        let id = a.seriesId.rawValue
        try db.execute(literal: """
            INSERT INTO BOOK_METADATA_AGGREGATION (series_id, release_date, summary, summary_number, created_date, last_modified_date)
            VALUES (\(id), \(a.releaseDate?.description), \(a.summary), \(a.summaryNumber), \(a.createdDate), \(a.lastModifiedDate))
            ON CONFLICT (series_id) DO UPDATE SET
                release_date = excluded.release_date, summary = excluded.summary,
                summary_number = excluded.summary_number, created_date = excluded.created_date,
                last_modified_date = excluded.last_modified_date
            """)
        try deleteChildren([id])
        for tag in a.tags {
            try db.execute(literal: "INSERT INTO BOOK_METADATA_AGGREGATION_TAG (series_id, tag) VALUES (\(id), \(tag))")
        }
        for author in a.authors {
            try db.execute(literal: """
                INSERT OR IGNORE INTO BOOK_METADATA_AGGREGATION_AUTHOR (series_id, name, role)
                VALUES (\(id), \(author.name), \(author.role))
                """)
        }
    }

    func find(_ seriesId: KomgaSeriesId) throws -> OfflineBookMetadataAggregation? {
        let id = seriesId.rawValue
        guard
            let row = try Row.fetchOne(
                db, SQLRequest(literal: "SELECT * FROM BOOK_METADATA_AGGREGATION WHERE series_id = \(id)"))
        else { return nil }
        let tags = try String.fetchAll(
            db, SQLRequest(literal: "SELECT tag FROM BOOK_METADATA_AGGREGATION_TAG WHERE series_id = \(id)"))
        let authors = try Row.fetchAll(
            db, SQLRequest(literal: "SELECT name, role FROM BOOK_METADATA_AGGREGATION_AUTHOR WHERE series_id = \(id)")
        ).map { KomgaAuthor(name: $0["name"], role: $0["role"]) }
        return OfflineBookMetadataAggregation(
            seriesId: seriesId, releaseDate: (row["release_date"] as String?).flatMap(KomgaLocalDate.init),
            summary: row["summary"], summaryNumber: row["summary_number"], authors: authors, tags: Set(tags),
            createdDate: row["created_date"], lastModifiedDate: row["last_modified_date"])
    }

    func delete(_ seriesIds: [KomgaSeriesId]) throws {
        let ids = seriesIds.map(\.rawValue)
        try deleteChildren(ids)
        try db.execute(literal: "DELETE FROM BOOK_METADATA_AGGREGATION WHERE series_id IN \(ids)")
    }

    private func deleteChildren(_ ids: [String]) throws {
        try db.execute(literal: "DELETE FROM BOOK_METADATA_AGGREGATION_TAG WHERE series_id IN \(ids)")
        try db.execute(literal: "DELETE FROM BOOK_METADATA_AGGREGATION_AUTHOR WHERE series_id IN \(ids)")
    }
}
