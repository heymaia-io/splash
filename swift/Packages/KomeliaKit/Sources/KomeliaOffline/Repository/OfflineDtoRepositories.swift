import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.api.repository.OfflineBookDtoRepository`: rebuilds the wire `KomeliaBook`
/// (with `downloaded = true`) from the offline tables, scoped to the libraries of the user's server.
public protocol OfflineBookDtoRepository {
    func findAll(userId: KomgaUserId, search: KomgaBookSearch, pageRequest: KomgaPageRequest) throws
        -> Page<KomeliaBook>
    func find(bookId: KomgaBookId, userId: KomgaUserId) throws -> KomeliaBook?
    func findPreviousInSeries(bookId: KomgaBookId, userId: KomgaUserId) throws -> KomeliaBook?
    func findNextInSeries(bookId: KomgaBookId, userId: KomgaUserId) throws -> KomeliaBook?
    func findAllOnDeck(userId: KomgaUserId, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest) throws
        -> Page<KomeliaBook>
}

extension OfflineBookDtoRepository {
    public func get(bookId: KomgaBookId, userId: KomgaUserId) throws -> KomeliaBook {
        try find(bookId: bookId, userId: userId).orThrow("Book \(bookId)")
    }
}

/// Port of `OfflineSeriesDtoRepository`: rebuilds `KomgaSeries` from the offline tables.
public protocol OfflineSeriesDtoRepository {
    func find(seriesId: KomgaSeriesId, userId: KomgaUserId) throws -> KomgaSeries?
    func findAll(search: KomgaSeriesSearch, userId: KomgaUserId, pageRequest: KomgaPageRequest) throws
        -> Page<KomgaSeries>
    /// Series whose `lastModified != created`, newest first.
    func findAllRecentlyUpdated(search: KomgaSeriesSearch, userId: KomgaUserId, pageRequest: KomgaPageRequest)
        throws -> Page<KomgaSeries>
}

extension OfflineSeriesDtoRepository {
    public func get(seriesId: KomgaSeriesId, userId: KomgaUserId) throws -> KomgaSeries {
        try find(seriesId: seriesId, userId: userId).orThrow("Series \(seriesId)")
    }
}

/// Port of `OfflineReferentialRepository`. The Kotlin interface has ~40 overloads (by library / collection /
/// series / read list); collections and read lists do not exist offline, so the Swift protocol folds the rest
/// into optional filter parameters (an empty `libraryIds` means "all libraries").
public protocol OfflineReferentialRepository {
    func authors(
        search: String?, role: String?, libraryIds: [KomgaLibraryId], seriesId: KomgaSeriesId?,
        pageRequest: KomgaPageRequest
    ) throws -> Page<KomgaAuthor>
    func authorNames(search: String) throws -> [String]
    func authorRoles() throws -> [String]
    func genres(libraryIds: [KomgaLibraryId]) throws -> [String]
    func sharingLabels(libraryIds: [KomgaLibraryId]) throws -> [String]
    /// Series tags ∪ book tags.
    func seriesAndBookTags(libraryIds: [KomgaLibraryId]) throws -> [String]
    func seriesTags(libraryId: KomgaLibraryId?) throws -> [String]
    func bookTags(seriesId: KomgaSeriesId?, libraryIds: [KomgaLibraryId]) throws -> [String]
    func languages(libraryIds: [KomgaLibraryId]) throws -> [String]
    func publishers(libraryIds: [KomgaLibraryId]) throws -> [String]
    func ageRatings(libraryIds: [KomgaLibraryId]) throws -> [Int?]
    func seriesReleaseDates(libraryIds: [KomgaLibraryId]) throws -> [KomgaLocalDate]
}
