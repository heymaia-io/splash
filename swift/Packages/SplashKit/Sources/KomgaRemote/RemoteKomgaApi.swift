import Foundation
import KomgaAPI

/// Port of `snd.komelia.api.RemoteApi` — the HTTP conformance of `KomgaApi`.
/// Built by the app's composition root (`AppModule.createRemoteApi`).
public struct RemoteKomgaApi: KomgaApi {
    public let actuatorApi: any KomgaActuatorApi
    public let announcementsApi: any KomgaAnnouncementsApi
    public let bookApi: any KomgaBookApi
    public let collectionsApi: any KomgaCollectionsApi
    public let fileSystemApi: any KomgaFileSystemApi
    public let libraryApi: any KomgaLibraryApi
    public let readListApi: any KomgaReadListApi
    public let referentialApi: any KomgaReferentialApi
    public let seriesApi: any KomgaSeriesApi
    public let settingsApi: any KomgaSettingsApi
    public let tasksApi: any KomgaTaskApi
    public let userApi: any KomgaUserApi

    /// Concrete book API, exposed for the download seam (`bookFileRequest`) only.
    public let remoteBookApi: RemoteBookApi

    public let http: KomgaHTTPClient
    private let offlineEvents: KomgaEventBroadcaster?

    public init(
        http: KomgaHTTPClient,
        offlineBooks: (any OfflineBookStateProvider)? = nil,
        offlineEvents: KomgaEventBroadcaster? = nil
    ) {
        self.http = http
        self.offlineEvents = offlineEvents
        remoteBookApi = RemoteBookApi(http: http, offlineBooks: offlineBooks)
        actuatorApi = RemoteActuatorApi(http: http)
        announcementsApi = RemoteAnnouncementsApi(http: http)
        bookApi = remoteBookApi
        collectionsApi = RemoteCollectionsApi(http: http)
        fileSystemApi = RemoteFileSystemApi(http: http)
        libraryApi = RemoteLibraryApi(http: http)
        readListApi = RemoteReadListApi(http: http, offlineBooks: offlineBooks)
        referentialApi = RemoteReferentialApi(http: http)
        seriesApi = RemoteSeriesApi(http: http)
        settingsApi = RemoteSettingsApi(http: http)
        tasksApi = RemoteTaskApi(http: http)
        userApi = RemoteUserApi(http: http)
    }

    /// `GET api/v1/books/{id}/manifest` — Readium WebPub manifest used by the EPUB reader.
    public func webPubManifestURL(_ bookId: KomgaBookId) -> URL {
        http.url("api/v1/books/\(bookId)/manifest")
    }

    public func createSSESession() async throws -> any KomgaSSESession {
        RemoteSSESession(http: http, offlineEvents: offlineEvents)
    }
}
