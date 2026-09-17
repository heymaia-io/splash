import Foundation
import KomgaAPI

/// Identity of a reader page (`ReaderImage.PageId`).
public struct PageId: Hashable, Sendable, CustomStringConvertible {
    public let bookId: KomgaBookId
    public let pageNumber: Int

    public init(bookId: KomgaBookId, pageNumber: Int) {
        self.bookId = bookId
        self.pageNumber = pageNumber
    }

    /// Kotlin key format `"${bookId}_$page"`.
    public var description: String { "\(bookId)_\(pageNumber)" }
}

/// Port of `BookImageLoader.kt` — fetches original page bytes through the *protocol* (`getPage`), so the same
/// reader works for remote pages and for pages extracted from a downloaded CBZ by the offline API.
/// Keeps a small LRU of encoded bytes (cheap to hold, avoids refetching on back/forward paging).
public actor PageImageLoader {
    private let api: @Sendable () -> any KomgaApi
    private let maxEntries: Int
    private var cache: [PageId: Data] = [:]
    private var order: [PageId] = []
    private var inFlight: [PageId: Task<Data, Error>] = [:]

    public init(api: @escaping @Sendable () -> any KomgaApi, maxEntries: Int = 16) {
        self.api = api
        self.maxEntries = maxEntries
    }

    public func data(for page: PageId) async throws -> Data {
        if let cached = cache[page] {
            touch(page)
            return cached
        }
        if let running = inFlight[page] { return try await running.value }
        let api = self.api
        let task = Task { try await api().bookApi.getPage(page.bookId, page: page.pageNumber) }
        inFlight[page] = task
        defer { inFlight[page] = nil }
        let data = try await task.value
        insert(data, for: page)
        return data
    }

    /// Fire-and-forget warm-up for neighbouring pages (`enqueueSpreadLoadJob`).
    public func prefetch(_ pages: [PageId]) {
        for page in pages where cache[page] == nil && inFlight[page] == nil {
            Task { _ = try? await self.data(for: page) }
        }
    }

    public func evictAll() {
        cache.removeAll()
        order.removeAll()
    }

    private func insert(_ data: Data, for page: PageId) {
        cache[page] = data
        touch(page)
        while order.count > maxEntries {
            cache[order.removeFirst()] = nil
        }
    }

    private func touch(_ page: PageId) {
        order.removeAll { $0 == page }
        order.append(page)
    }
}
