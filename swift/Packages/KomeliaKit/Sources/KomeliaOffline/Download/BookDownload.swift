import Foundation
import KomgaAPI

/// [NUEVO] Persisted state of one book download (`BOOK_DOWNLOAD` table). Kotlin only kept download progress in
/// memory (`MutableSharedFlow<DownloadEvent>`); iOS downloads outlive the process (background `URLSession`) and
/// can fail while the app is suspended, so the state is stored and a failed download can be retried.
public struct BookDownload: Hashable, Sendable, Identifiable {
    public enum Status: String, Hashable, Sendable, CaseIterable {
        case queued = "QUEUED"
        case downloading = "DOWNLOADING"
        case complete = "COMPLETE"
        case failed = "FAILED"
    }

    public var bookId: KomgaBookId
    public var status: Status
    /// Expected size (`Content-Length`, or the book size before the response arrives). 0 = unknown.
    public var totalBytes: Int64
    public var completedBytes: Int64
    public var error: String?
    /// Display data for the downloads screen, filled once the book metadata is known.
    public var bookTitle: String?
    public var seriesId: KomgaSeriesId?
    public var createdDate: Date
    public var lastModifiedDate: Date

    public var id: KomgaBookId { bookId }

    public init(
        bookId: KomgaBookId, status: Status, totalBytes: Int64 = 0, completedBytes: Int64 = 0, error: String? = nil,
        bookTitle: String? = nil, seriesId: KomgaSeriesId? = nil, createdDate: Date = Date(),
        lastModifiedDate: Date = Date()
    ) {
        self.bookId = bookId
        self.status = status
        self.totalBytes = totalBytes
        self.completedBytes = completedBytes
        self.error = error
        self.bookTitle = bookTitle
        self.seriesId = seriesId
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }

    /// 0...1, or nil while the size is unknown.
    public var fractionCompleted: Double? {
        guard totalBytes > 0 else { return nil }
        return min(1, Double(completedBytes) / Double(totalBytes))
    }
}

/// Port of `snd.komelia.offline.sync.model.DownloadEvent`. Events carry the persisted state instead of the
/// `KomgaBook` so the UI can render a row without another lookup.
public enum DownloadEvent: Hashable, Sendable {
    /// `BookDownloadProgress` (also emitted for QUEUED / DOWNLOADING transitions).
    case bookDownloadProgress(BookDownload)
    case bookDownloadCompleted(BookDownload)
    case bookDownloadError(BookDownload)
    /// [NUEVO] Kotlin cancelled the coroutine silently; the UI needs to drop the row.
    case bookDownloadCancelled(KomgaBookId)

    public var bookId: KomgaBookId {
        switch self {
        case .bookDownloadProgress(let d), .bookDownloadCompleted(let d), .bookDownloadError(let d): d.bookId
        case .bookDownloadCancelled(let id): id
        }
    }
}
