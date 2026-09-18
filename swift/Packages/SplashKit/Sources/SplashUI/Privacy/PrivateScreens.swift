import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Resolves the hidden ids into real objects.
///
/// The private root cannot query a list endpoint: Komga has no "id is one of" condition for series or
/// books, so there is no search that returns exactly the hidden set. It fetches each id instead, which is
/// fine for a user-curated set of tens to hundreds. Past roughly a thousand items this wants a real index.
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

    init(
        api: any KomgaApi, authState: KomgaAuthenticationState,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter
    ) {
        self.api = api
        self.authState = authState
        self.hiddenFilter = hiddenFilter
    }

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }

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

/// The private area's root: everything the user marked private, and nothing else.
struct PrivateHomeScreen: View {
    @State var model: PrivateCatalogViewModel
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void
    @Environment(\.privacy) private var privacy

    var body: some View {
        Group {
            if model.state.isUninitialized || (model.state.isLoading && model.isEmpty) {
                ProgressView()
            } else if model.isEmpty {
                ContentUnavailableView(
                    "Nothing is private yet", systemImage: "eye.slash",
                    description: Text("Use Hide on a library, a series or a book to keep it here."))
            } else {
                content
            }
        }
        .navigationTitle("Private")
        .task { if model.state.isUninitialized { await model.load() } }
        .refreshable { await model.load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !model.libraries.isEmpty {
                    section("Libraries") {
                        ForEach(model.libraries) { library in
                            Button { navigate(.privateLibrary(library.id)) } label: {
                                Label(library.name, systemImage: "books.vertical")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { HideMenuButton(target: .library(library.id)) }
                        }
                    }
                }
                if !model.series.isEmpty {
                    section("Series") {
                        CardGrid(items: model.series, cardWidth: cardWidth) { item in
                            Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                                SeriesCard(series: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { HideMenuButton(target: .series(item.id)) }
                        }
                    }
                }
                if !model.books.isEmpty {
                    section("Books") {
                        CardGrid(items: model.books, cardWidth: cardWidth) { book in
                            Button { navigate(.book(book.id)) } label: {
                                BookCard(book: book, showSeries: true)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                HideMenuButton(target: .book(book.id, isDownloaded: book.downloaded))
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder private func section(
        _ title: LocalizedStringKey, @ViewBuilder body: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold()).padding(.horizontal)
            body()
        }
    }
}

/// Search scoped to the private set.
///
/// Komga cannot scope a query to a list of ids, so hidden series and books are matched in memory against
/// the resolved catalog. Hidden *libraries* are a real server query, because `.libraryId(.isEqualTo)` does
/// exist — that is why a private library scales and a long list of individually hidden series does not.
struct PrivateSearchScreen: View {
    @State var model: PrivateCatalogViewModel
    let query: String
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void

    private var matchedSeries: [KomgaSeries] {
        model.series.filter { $0.metadata.title.localizedStandardContains(query) || $0.name.localizedStandardContains(query) }
    }

    private var matchedBooks: [SplashBook] {
        model.books.filter {
            $0.metadata.title.localizedStandardContains(query) || $0.seriesTitle.localizedStandardContains(query)
        }
    }

    var body: some View {
        ScrollView {
            if model.state.isLoading {
                ProgressView().padding()
            } else if matchedSeries.isEmpty, matchedBooks.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !matchedSeries.isEmpty {
                        CardGrid(items: matchedSeries, cardWidth: cardWidth) { item in
                            Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                                SeriesCard(series: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !matchedBooks.isEmpty {
                        CardGrid(items: matchedBooks, cardWidth: cardWidth) { book in
                            Button { navigate(.book(book.id)) } label: {
                                BookCard(book: book, showSeries: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Private results")
        .task { if model.state.isUninitialized { await model.load() } }
    }
}
