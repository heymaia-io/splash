import Foundation
import GRDB
import KomgaAPI

/// Port of `conditions/BookSearchHelper.kt`. Table aliases of `GRDBBookDtoRepository`:
/// `b` BOOK, `bm` BOOK_METADATA, `m` MEDIA, `rp` READ_PROGRESS (joined for the user), `sm` SERIES_METADATA.
/// All joins are always present, so Kotlin's `RequiredJoin` bookkeeping is unnecessary.
enum BookSearchHelper {
    static func condition(_ condition: BookCondition?) -> SQL {
        guard let condition else { return SearchSQL.alwaysTrue }
        switch condition {
        case .allOf(let conditions): return SearchSQL.and(conditions.map(self.condition))
        case .anyOf(let conditions): return SearchSQL.or(conditions.map(self.condition))
        case .libraryId(let op): return SearchSQL.equality(op, "b.library_id", \.rawValue)
        case .seriesId(let op): return SearchSQL.equality(op, "b.series_id", \.rawValue)
        case .readListId(let op):
            // Read lists are not stored offline (Kotlin: TODO → TRUE, which matched every book).
            if case .isEqualTo = op { return SearchSQL.alwaysFalse }
            return SearchSQL.alwaysTrue
        case .title(let op): return SearchSQL.string(op, "bm.title")
        case .deleted(let op): return SearchSQL.boolean(op, "b.deleted")
        case .oneShot(let op): return SearchSQL.boolean(op, "b.oneshot")
        case .releaseDate(let op): return SearchSQL.date(op, "bm.release_date")
        case .numberSort(let op): return SearchSQL.numeric(op, "bm.number_sort")
        case .readStatus(let op): return readStatus(op)
        case .mediaStatus(let op): return SearchSQL.equality(op, "m.status", \.rawValue)
        case .mediaProfile(let op): return SearchSQL.equality(op, "m.media_profile", nullable: true, \.rawValue)
        case .tag(let op):
            return SearchSQL.childValue(op, id: "b.id") { tag in
                if let tag {
                    return "SELECT book_id FROM BOOK_METADATA_TAG WHERE LOWER(tag) = \(tag.lowercased())"
                }
                return "SELECT book_id FROM BOOK_METADATA_TAG"
            }
        case .author(let op):
            return SearchSQL.author(op, id: "b.id", table: "BOOK_METADATA_AUTHOR", key: "book_id")
        case .poster(let op): return poster(op)
        }
    }

    private static func readStatus(_ op: EqualityOp<KomgaReadStatus>) -> SQL {
        switch op {
        case .isEqualTo(.unread): "rp.completed IS NULL"
        case .isEqualTo(.read): "rp.completed = 1"
        case .isEqualTo(.inProgress): "rp.completed = 0"
        case .isNotEqualTo(.unread): "rp.completed IS NOT NULL"
        case .isNotEqualTo(.read): "(rp.completed IS NULL OR rp.completed = 0)"
        case .isNotEqualTo(.inProgress): "(rp.completed IS NULL OR rp.completed = 1)"
        }
    }

    private static func poster(_ op: EqualityOp<PosterMatch>) -> SQL {
        let (match, negated): (PosterMatch, Bool) =
            switch op {
            case .isEqualTo(let m): (m, false)
            case .isNotEqualTo(let m): (m, true)
            }
        guard match.type != nil || match.selected != nil else { return SearchSQL.alwaysTrue }
        var filters: [SQL] = []
        if let type = match.type { filters.append("type = \(type.rawValue)") }
        if let selected = match.selected { filters.append("selected = \(selected)") }
        return SearchSQL.membership(
            "b.id", "SELECT book_id FROM THUMBNAIL_BOOK WHERE \(SearchSQL.and(filters))", negated: negated)
    }
}

/// Port of `conditions/SeriesSearchHelper.kt`. Aliases of `GRDBSeriesDtoRepository`: `s` SERIES,
/// `sm` SERIES_METADATA, `ba` BOOK_METADATA_AGGREGATION, `rps` READ_PROGRESS_SERIES (joined for the user).
enum SeriesSearchHelper {
    static func condition(_ condition: SeriesCondition?) -> SQL {
        guard let condition else { return SearchSQL.alwaysTrue }
        switch condition {
        case .allOf(let conditions): return SearchSQL.and(conditions.map(self.condition))
        case .anyOf(let conditions): return SearchSQL.or(conditions.map(self.condition))
        case .libraryId(let op): return SearchSQL.equality(op, "s.library_id", \.rawValue)
        case .collectionId(let op):
            // Collections are not stored offline (Kotlin: TODO → TRUE).
            if case .isEqualTo = op { return SearchSQL.alwaysFalse }
            return SearchSQL.alwaysTrue
        case .deleted(let op): return SearchSQL.boolean(op, "s.deleted")
        case .complete(let op):
            // Kotlin had both branches inverted; Komga: complete ⇔ total_book_count = books_count.
            switch op {
            case .isTrue: return "(sm.total_book_count IS NOT NULL AND sm.total_book_count = s.books_count)"
            case .isFalse: return "(sm.total_book_count IS NULL OR sm.total_book_count <> s.books_count)"
            }
        case .oneShot(let op): return SearchSQL.boolean(op, "s.oneshot")
        case .title(let op): return SearchSQL.string(op, "sm.title")
        case .titleSort(let op): return SearchSQL.string(op, "sm.title_sort")
        case .releaseDate(let op): return SearchSQL.date(op, "ba.release_date")
        case .tag(let op):
            return SearchSQL.childValue(op, id: "s.id") { tag in
                if let tag {
                    let value = tag.lowercased()
                    return """
                        SELECT series_id FROM SERIES_METADATA_TAG WHERE LOWER(tag) = \(value) \
                        UNION SELECT series_id FROM BOOK_METADATA_AGGREGATION_TAG WHERE LOWER(tag) = \(value)
                        """
                }
                return "SELECT series_id FROM SERIES_METADATA_TAG UNION SELECT series_id FROM BOOK_METADATA_AGGREGATION_TAG"
            }
        case .sharingLabel(let op):
            // Kotlin swapped isNull / isNotNull here.
            return SearchSQL.childValue(op, id: "s.id") { label in
                if let label {
                    return "SELECT series_id FROM SERIES_METADATA_SHARING WHERE LOWER(label) = \(label.lowercased())"
                }
                return "SELECT series_id FROM SERIES_METADATA_SHARING"
            }
        case .genre(let op):
            return SearchSQL.childValue(op, id: "s.id") { genre in
                if let genre {
                    return "SELECT series_id FROM SERIES_METADATA_GENRE WHERE LOWER(genre) = \(genre.lowercased())"
                }
                return "SELECT series_id FROM SERIES_METADATA_GENRE"
            }
        case .publisher(let op): return SearchSQL.equality(op, "sm.publisher", ignoreCase: true)
        case .language(let op): return SearchSQL.equality(op, "sm.language", ignoreCase: true)
        case .ageRating(let op): return SearchSQL.numeric(op, "sm.age_rating")
        case .readStatus(let op): return readStatus(op)
        case .seriesStatus(let op): return SearchSQL.equality(op, "sm.status", \.rawValue)
        case .author(let op):
            return SearchSQL.author(op, id: "s.id", table: "BOOK_METADATA_AGGREGATION_AUTHOR", key: "series_id")
        }
    }

    /// Same semantics as Kotlin / the Komga server (`READ_PROGRESS_SERIES.read_count` vs `SERIES.books_count`).
    private static func readStatus(_ op: EqualityOp<KomgaReadStatus>) -> SQL {
        switch op {
        case .isEqualTo(.unread): "rps.read_count IS NULL"
        case .isEqualTo(.read): "rps.read_count = s.books_count"
        case .isEqualTo(.inProgress): "rps.read_count <> s.books_count"
        case .isNotEqualTo(.unread): "rps.read_count IS NOT NULL"
        case .isNotEqualTo(.read): "(rps.read_count <> s.books_count OR rps.read_count IS NULL)"
        case .isNotEqualTo(.inProgress): "(rps.read_count = s.books_count OR rps.read_count IS NULL)"
        }
    }
}
