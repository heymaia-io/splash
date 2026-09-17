import KomeliaCore
import KomeliaUI
import KomgaAPI
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

/// Readium-backed implementation of `EpubReaderPresenting` (plan Phase 15; replaces the Kotlin WebView hosting of
/// the vendored komga-webui/ttu readers — [NUEVO]).
@MainActor
public final class ReadiumEpubReaderPresenter: EpubReaderPresenting {
    public init() {}

    public func makeReader(model: EpubReaderModel, onClose: @escaping () -> Void) -> AnyView {
        AnyView(ReadiumEpubReaderView(model: model, onClose: onClose))
    }
}

// MARK: - Opening publications

/// Adds Komga auth headers to every request Readium makes (manifest + every resource the navigator loads).
final class KomgaAuthDelegate: DefaultHTTPClientDelegate, @unchecked Sendable {
    let headers: @Sendable (URL) -> [String: String]
    init(headers: @escaping @Sendable (URL) -> [String: String]) { self.headers = headers }

    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest) async
        -> HTTPResult<HTTPRequestConvertible>
    {
        var request = request
        for (name, value) in headers(request.url.url) { request.headers[name] = value }
        return .success(request)
    }
}

enum EpubOpenError: LocalizedError {
    case invalidURL
    case retrieve(String)
    case open(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "Invalid book location")
        case .retrieve(let message), .open(let message): message
        }
    }
}

@MainActor
enum PublicationLoader {
    /// `DefaultHTTPClient.delegate` is weak: the returned delegate must be retained while the publication is open,
    /// otherwise resource requests lose their auth headers (401).
    static func open(_ source: EpubSource) async throws -> (Publication, AnyObject?) {
        let delegate: KomgaAuthDelegate?
        let url: AbsoluteURL
        switch source {
        case .remote(let manifest, let headers):
            delegate = KomgaAuthDelegate(headers: headers)
            guard let http = HTTPURL(url: manifest) else { throw EpubOpenError.invalidURL }
            url = http
        case .local(let file):
            delegate = nil
            guard let fileURL = FileURL(url: file) else { throw EpubOpenError.invalidURL }
            url = fileURL
        }
        let httpClient = DefaultHTTPClient(delegate: delegate)
        let retriever = AssetRetriever(httpClient: httpClient)
        let opener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient, assetRetriever: retriever, pdfFactory: DefaultPDFDocumentFactory()))

        let hints: FormatHints = if case .remote = source {
            FormatHints(mediaType: MediaType("application/webpub+json"))
        } else {
            FormatHints(mediaType: .epub)
        }
        let asset: Asset
        switch await retriever.retrieve(url: url, hints: hints) {
        case .success(let value): asset = value
        case .failure(let error): throw EpubOpenError.retrieve(String(describing: error))
        }
        var transform: Publication.Builder.Transform = { _, _, _ in }
        if case .remote(let manifest, _) = source {
            let base = manifest.deletingLastPathComponent().appending(path: "resource").absoluteString + "/"
            transform = { manifest, container, _ in
                ManifestRelativizer.apply(to: &manifest, base: base)
                if let baseURL = HTTPURL(string: base) {
                    container = HTTPContainer(client: httpClient, baseURL: baseURL)
                }
            }
        }
        switch await opener.open(asset: asset, allowUserInteraction: false, onCreatePublication: transform) {
        case .success(let publication): return (publication, delegate)
        case .failure(let error): throw EpubOpenError.open(String(describing: error))
        }
    }
}

/// Komga's manifest links are absolute `…/books/{id}/resource/<path>` URLs, and a manifest with an HTTP `self` link
/// makes Readium load resources straight into the web view — without our auth headers (401). Rewriting hrefs
/// relative to the resource base and dropping `self` makes the navigator serve every resource through its
/// `readium://` scheme handler, i.e. through our authenticated `HTTPContainer`. Relative hrefs are also exactly what
/// Komga stores in `R2Progression` (and what a downloaded EPUB uses), so locations are portable.
enum ManifestRelativizer {
    static func apply(to manifest: inout Manifest, base: String) {
        manifest.links.removeAll { $0.rels.contains(.`self`) }
        manifest.readingOrder = manifest.readingOrder.map { relativize($0, base) }
        manifest.resources = manifest.resources.map { relativize($0, base) }
        manifest.subcollections = manifest.subcollections.mapValues { collections in
            collections.map { collection in
                var copy = collection
                copy.links = collection.links.map { relativize($0, base) }
                return copy
            }
        }
    }

    static func relativize(_ link: ReadiumShared.Link, _ base: String) -> ReadiumShared.Link {
        var link = link
        if link.href.hasPrefix(base) { link.href.removeFirst(base.count) }
        link.children = link.children.map { relativize($0, base) }
        link.alternates = link.alternates.map { relativize($0, base) }
        return link
    }
}

// MARK: - Mapping

extension EpubReaderSettings {
    var readiumPreferences: EPUBPreferences {
        EPUBPreferences(
            columnCount: columnCount.readium,
            fontFamily: fontFamily.readium,
            fontSize: fontSize,
            lineHeight: lineHeight,
            pageMargins: pageMargins,
            publisherStyles: publisherStyles,
            scroll: scroll,
            theme: theme.readium)
    }
}

extension EpubReaderSettings.ColumnCount {
    var readium: ReadiumNavigator.ColumnCount? {
        switch self {
        case .auto: .auto
        case .one: .one
        case .two: .two
        }
    }
}

extension EpubReaderSettings.Theme {
    var readium: ReadiumNavigator.Theme {
        switch self {
        case .light: .light
        case .sepia: .sepia
        case .dark: .dark
        }
    }

    var background: SwiftUI.Color {
        switch self {
        case .light: .white
        case .sepia: SwiftUI.Color(red: 0.98, green: 0.94, blue: 0.87)
        case .dark: .black
        }
    }
}

extension EpubReaderSettings.FontFamily {
    var readium: ReadiumNavigator.FontFamily? {
        switch self {
        case .publisher: nil
        case .serif: .serif
        case .sansSerif: .sansSerif
        case .openDyslexic: .openDyslexic
        }
    }
}

extension Locator {
    var epubLocation: EpubLocation {
        EpubLocation(
            href: href.string, type: mediaType.string, progression: locations.progression,
            totalProgression: locations.totalProgression, position: locations.position)
    }

    init?(_ location: EpubLocation) {
        guard let mediaType = MediaType(location.type) ?? MediaType("application/xhtml+xml"),
              let href = AnyURL(string: location.href)
        else { return nil }
        self.init(
            href: href, mediaType: mediaType,
            locations: Locations(
                progression: location.progression, totalProgression: location.totalProgression,
                position: location.position))
    }
}

// MARK: - SwiftUI host

struct ReadiumEpubReaderView: View {
    @State var model: EpubReaderModel
    let onClose: () -> Void
    @State private var publication: Publication?
    @State private var error: Error?
    @State private var showOverlay = false
    @State private var showSettings = false
    @State private var settings: EpubReaderSettings
    @State private var controller: NavigatorController?
    @State private var toc: [ReadiumShared.Link] = []
    @State private var httpDelegate: AnyObject?

    init(model: EpubReaderModel, onClose: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onClose = onClose
        _settings = State(initialValue: model.settings.value)
    }

    var body: some View {
        ZStack {
            settings.theme.background.ignoresSafeArea()
            if let publication {
                EPUBNavigatorRepresentable(
                    publication: publication, initialLocation: model.initialLocation.flatMap(Locator.init),
                    preferences: settings.readiumPreferences,
                    onLocationChange: { model.locationChanged($0.epubLocation) },
                    onTap: { withAnimation { showOverlay.toggle() } },
                    onController: { controller = $0 })
                .ignoresSafeArea()
            } else if let error {
                ContentUnavailableView("Book could not be opened", systemImage: "book.closed",
                                       description: Text(error.localizedDescription))
            } else {
                ProgressView()
            }
            if showOverlay || publication == nil { overlay }
        }
        .statusBarHidden(!showOverlay)
        .task {
            await model.initialize()
            do {
                let (opened, delegate) = try await PublicationLoader.open(model.source)
                httpDelegate = delegate
                publication = opened
                toc = (try? await opened.tableOfContents().get()) ?? opened.readingOrder
            } catch {
                self.error = error
            }
        }
        .sheet(isPresented: $showSettings) {
            EpubSettingsSheet(settings: $settings) { newValue in
                Task { try? await model.settings.update { $0 = newValue } }
            }
            .presentationDetents([.medium])
        }
        .onKeyPress(.leftArrow) { controller?.go(forward: false); return .handled }
        .onKeyPress(.rightArrow) { controller?.go(forward: true); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var overlay: some View {
        VStack {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.headline).padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close reader")
                Text(model.book.metadata.title).font(.headline).lineLimit(1)
                Spacer()
                if publication != nil {
                    Menu {
                        ForEach(Array(toc.enumerated()), id: \.offset) { _, link in
                            Button(link.title ?? link.href) { controller?.go(to: link) }
                        }
                    } label: {
                        Image(systemName: "list.bullet").font(.headline).padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Table of contents")
                    Button { showSettings = true } label: {
                        Image(systemName: "textformat.size").font(.headline).padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Reading settings")
                }
            }
            .padding()
            .background(.regularMaterial)
            Spacer()
            if publication != nil {
                ProgressView(value: model.currentProgress)
                    .padding()
                    .background(.regularMaterial)
            }
        }
    }
}

/// Handle used by SwiftUI to drive the UIKit navigator.
@MainActor
final class NavigatorController {
    weak var navigator: EPUBNavigatorViewController?

    func go(forward: Bool) {
        guard let navigator else { return }
        Task { _ = forward ? await navigator.goForward() : await navigator.goBackward() }
    }

    func go(to link: ReadiumShared.Link) {
        guard let navigator else { return }
        Task { _ = await navigator.go(to: link) }
    }
}

struct EPUBNavigatorRepresentable: UIViewControllerRepresentable {
    let publication: Publication
    let initialLocation: Locator?
    let preferences: EPUBPreferences
    let onLocationChange: (Locator) -> Void
    let onTap: () -> Void
    let onController: (NavigatorController) -> Void

    final class Coordinator: NSObject, EPUBNavigatorDelegate {
        var onLocationChange: (Locator) -> Void = { _ in }
        let controller = NavigatorController()
        var adapter: DirectionalNavigationAdapter?

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            onLocationChange(locator)
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {}
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            let config = EPUBNavigatorViewController.Configuration(preferences: preferences)
            let navigator = try EPUBNavigatorViewController(
                publication: publication, initialLocation: initialLocation, config: config)
            navigator.delegate = context.coordinator
            context.coordinator.onLocationChange = onLocationChange
            context.coordinator.controller.navigator = navigator

            // Edge taps / arrow keys turn pages (Kotlin readers use side tap zones); center tap toggles the UI.
            let adapter = DirectionalNavigationAdapter()
            adapter.bind(to: navigator)
            context.coordinator.adapter = adapter
            let onTap = self.onTap
            _ = navigator.addObserver(.tap { _ in
                onTap()
                return true
            })
            onController(context.coordinator.controller)
            return navigator
        } catch {
            let host = UIHostingController(rootView: ContentUnavailableView(
                "Book could not be opened", systemImage: "book.closed",
                description: Text(error.localizedDescription)))
            return host
        }
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.onLocationChange = onLocationChange
        (controller as? EPUBNavigatorViewController)?.submitPreferences(preferences)
    }
}

/// `settings/epub` — reading preferences.
struct EpubSettingsSheet: View {
    @Binding var settings: EpubReaderSettings
    let onChange: (EpubReaderSettings) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Theme", selection: bind(\.theme)) {
                    Text("Light").tag(EpubReaderSettings.Theme.light)
                    Text("Sepia").tag(EpubReaderSettings.Theme.sepia)
                    Text("Dark").tag(EpubReaderSettings.Theme.dark)
                }
                .pickerStyle(.segmented)
                Picker("Font", selection: bind(\.fontFamily)) {
                    Text("Publisher").tag(EpubReaderSettings.FontFamily.publisher)
                    Text("Serif").tag(EpubReaderSettings.FontFamily.serif)
                    Text("Sans serif").tag(EpubReaderSettings.FontFamily.sansSerif)
                    Text("OpenDyslexic").tag(EpubReaderSettings.FontFamily.openDyslexic)
                }
                LabeledContent("Text size \(Int(settings.fontSize * 100))%") {
                    Slider(value: bind(\.fontSize), in: 0.5...3, step: 0.1)
                }
                LabeledContent("Margins") {
                    Slider(value: bind(\.pageMargins), in: 0.5...2, step: 0.25)
                }
                Picker("Columns", selection: bind(\.columnCount)) {
                    Text("One").tag(EpubReaderSettings.ColumnCount.one)
                    Text("Two").tag(EpubReaderSettings.ColumnCount.two)
                    Text("Automatic").tag(EpubReaderSettings.ColumnCount.auto)
                }
                .disabled(settings.scroll)
                Toggle("Scroll instead of pages", isOn: bind(\.scroll))
                Toggle("Publisher styles", isOn: bind(\.publisherStyles))
            }
            .navigationTitle("Reading settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bind<T>(_ keyPath: WritableKeyPath<EpubReaderSettings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: keyPath] }, set: { value in
            settings[keyPath: keyPath] = value
            onChange(settings)
        })
    }
}
