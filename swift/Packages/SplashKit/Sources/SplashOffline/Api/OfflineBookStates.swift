import Foundation
import KomgaAPI

/// `OfflineBookStateProvider` over the offline database: `RemoteBookApi` asks it which of the listed books are
/// downloaded (Kotlin: `OfflineBookRepository.findIn` inside `RemoteBookApi.getKomeliaBookPage`).
public struct DatabaseOfflineBookStateProvider: OfflineBookStateProvider {
    private let store: any OfflineDataStore

    public init(store: any OfflineDataStore) { self.store = store }

    public func offlineStates(for bookIds: [KomgaBookId]) async throws -> [KomgaBookId: OfflineBookState] {
        guard !bookIds.isEmpty else { return [:] }
        let books = try await store.read { try $0.books.findIn(bookIds) }
        return Dictionary(
            books.map {
                ($0.id, OfflineBookState(localFileLastModified: $0.localFileLastModified, remoteUnavailable: $0.remoteUnavailable))
            },
            uniquingKeysWith: { first, _ in first })
    }
}
