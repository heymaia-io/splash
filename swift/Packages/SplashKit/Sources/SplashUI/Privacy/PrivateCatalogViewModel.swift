import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Resolves the hidden ids into real objects, for Settings → Private.
///
/// It cannot query a list endpoint: Komga has no "id is one of" condition for series or books, so there
/// is no search that returns exactly the hidden set. It fetches each id instead, which is fine for a
/// user-curated set of tens to hundreds. Past roughly a thousand items this wants a real index.
///
/// Since the Private *tab* was removed, this is the only place that can answer "what have I hidden?" —
/// unlocking now reveals content in place rather than gathering it into a screen of its own.
@MainActor
@Observable
public final class PrivateCatalogViewModel {
    public private(set) var libraries: [KomgaLibrary] = []
    public private(set) var series: [KomgaSeries] = []
    public private(set) var books: [SplashBook] = []
    public private(set) var state: LoadState<Void> = .uninitialized

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: () -> AsyncStream<HiddenContent>
    private var hiddenTask: Task<Void, Never>?

    init(
        api: any KomgaApi, authState: KomgaAuthenticationState,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter,
        hiddenChanges: @escaping () -> AsyncStream<HiddenContent>
    ) {
        self.api = api
        self.authState = authState
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }

    /// Watches the stored set so unhiding something from this very screen removes the card straight away,
    /// instead of leaving it there until the tab is rebuilt.
    public func start() {
        guard hiddenTask == nil else { return }
        hiddenTask = Task { [weak self] in
            var isFirst = true  // `values()` replays the current value
            for await hidden in self?.hiddenChanges() ?? .init(unfolding: { nil }) {
                if isFirst { isFirst = false; continue }
                await self?.apply(hidden)
            }
        }
    }

    public func stop() {
        hiddenTask?.cancel()
        hiddenTask = nil
    }

    /// Drops what is no longer private without a round trip — the card disappears on the same frame as the
    /// tap — and only goes back to the server when something newly private needs resolving.
    private func apply(_ hidden: HiddenContent) async {
        libraries.removeAll { !hidden.libraries.contains($0.id) }
        series.removeAll { !hidden.series.contains($0.id) }
        books.removeAll { !hidden.books.contains($0.id) }

        let needsSeries = !hidden.series.subtracting(series.map(\.id)).isEmpty
        let needsBooks = !hidden.books.subtracting(books.map(\.id)).isEmpty
        let needsLibraries = libraries.count != hidden.libraries.count
        guard needsSeries || needsBooks || needsLibraries else { return }
        await load()
    }

    public func load() async {
        let hidden = hiddenFilter().hidden
        state = .loading
        libraries = authState.libraries.filter { hidden.libraries.contains($0.id) }
        async let series = Self.resolve(hidden.series, concurrency: 6) { [api] in
            try await api.seriesApi.getOneSeries($0)
        }
        async let books = Self.resolve(hidden.books, concurrency: 6) { [api] in
            try await api.bookApi.getOne($0)
        }
        self.series = await series.sorted { $0.metadata.titleSort < $1.metadata.titleSort }
        self.books = await books.sorted { $0.metadata.title < $1.metadata.title }
        state = .success(())
    }

    /// Ids that fail to resolve (deleted on the server, or simply unreachable) are dropped from the
    /// display but deliberately left in the stored set: a server hiccup must never silently unhide
    /// something, and a re-added series must come back still hidden.
    private nonisolated static func resolve<ID: Sendable & Hashable, Value: Sendable>(
        _ ids: Set<ID>, concurrency: Int, fetch: @escaping @Sendable (ID) async throws -> Value
    ) async -> [Value] {
        await withTaskGroup(of: Value?.self) { group in
            var pending = Array(ids)
            var running = 0
            var results: [Value] = []
            while !pending.isEmpty || running > 0 {
                while running < concurrency, let id = pending.popLast() {
                    group.addTask { try? await fetch(id) }
                    running += 1
                }
                if let value = await group.next() {
                    running -= 1
                    if let value { results.append(value) }
                }
            }
            return results
        }
    }
}
