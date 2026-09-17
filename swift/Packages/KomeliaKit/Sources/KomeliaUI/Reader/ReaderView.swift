import KomeliaCore
import KomeliaImage
import KomgaAPI
import SwiftUI

/// Port of `ImageReaderScreen.kt` / `ReaderContent.kt`: full-screen reader with a toggleable overlay
/// (title, page slider, settings) presented over the main navigator.
public struct ReaderView: View {
    @State private var model: ReaderViewModel
    @State private var paged: PagedReaderModel?
    @State private var continuous: ContinuousReaderModel?
    @State private var showOverlay = false
    @State private var showSettings = false
    @State private var sliderPage: Double = 1
    @State private var stepRequest: ContinuousStripViewStep?
    @State private var flash = false
    let onClose: (Destination?) -> Void

    public init(model: ReaderViewModel, onClose: @escaping (Destination?) -> Void) {
        _model = State(initialValue: model)
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if flash { flashOverlay }
            if showOverlay { overlay }
        }
        .statusBarHiddenCompat(!showOverlay)
        // Hardware keyboard (iPad): arrows/space turn pages, Esc closes (`MainScreen` Alt+← / reader key map).
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { turn(physicalLeft: true); return .handled }
        .onKeyPress(.rightArrow) { turn(physicalLeft: false); return .handled }
        .onKeyPress(.space) { advance(forward: true); return .handled }
        .onKeyPress(.upArrow) { advance(forward: false); return .handled }
        .onKeyPress(.downArrow) { advance(forward: true); return .handled }
        .onKeyPress(.escape) { onClose(nil); return .handled }
        .task {
            await model.initialize()
            setUpModels()
        }
        .onChange(of: model.exitDestination) { _, destination in
            if let destination { onClose(destination) }
        }
        .onChange(of: model.books?.currentBook.id) { _, _ in
            paged?.bookDidChange()
            continuous?.bookDidChange()
        }
        .onChange(of: paged?.pageChangeCounter) { _, _ in triggerFlash() }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(model: model, paged: paged, continuous: continuous)
                .presentationDetents([.medium, .large])
        }
        .alert(model.notice ?? "", isPresented: Binding(
            get: { model.notice != nil }, set: { if !$0 { model.dismissNotice() } })
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private func setUpModels() {
        guard model.state.value != nil else { return }
        let pagedModel = PagedReaderModel(reader: model)
        let continuousModel = ContinuousReaderModel(reader: model)
        pagedModel.bookDidChange()
        continuousModel.bookDidChange()
        paged = pagedModel
        continuous = continuousModel
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch model.state {
        case .error(let error):
            ErrorView(error: error) {}
                .overlay(alignment: .topLeading) { closeButton.padding() }
        case .success:
            if model.readerType == .continuous, let continuous {
                continuousContent(continuous)
            } else if let paged {
                pagedContent(paged)
            }
        default:
            ProgressView().tint(.white)
        }
    }

    @ViewBuilder private func pagedContent(_ paged: PagedReaderModel) -> some View {
        if let transition = paged.transitionPage {
            TransitionPageView(page: transition)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { point in
                    handleTap(paged: paged, x: point.x)
                }
                .overlay { GeometryReader { proxy in Color.clear.preference(key: WidthKey.self, value: proxy.size.width) } }
                .onPreferenceChange(WidthKey.self) { tapWidth = $0 }
        } else {
            #if canImport(UIKit)
            PagedSpreadView(
                pages: paged.currentSpread, scaleType: paged.scaleType,
                stretchToFit: model.settings.value.stretchToFit,
                rightToLeft: paged.readingDirection == .rightToLeft
            ) { point, width in
                tapWidth = width
                handleTap(paged: paged, x: point.x)
            }
            .ignoresSafeArea()
            .overlay { pageErrors(paged.currentSpread) }
            #else
            HStack(spacing: 0) {
                ForEach(paged.currentSpread) { page in
                    MacPageImage(page: page)
                }
            }
            .onTapGesture { showOverlay.toggle() }
            #endif
        }
    }

    @State private var tapWidth: CGFloat = 1

    private func handleTap(paged: PagedReaderModel, x: CGFloat) {
        if paged.handleTap(atX: x, width: tapWidth) {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() }
        } else if showOverlay {
            withAnimation { showOverlay = false }
        }
    }

    @ViewBuilder private func continuousContent(_ continuous: ContinuousReaderModel) -> some View {
        #if canImport(UIKit)
        ContinuousStripView(model: continuous, stepRequest: stepRequest.map {
            .init(id: $0.id, forward: $0.forward)
        }) { point, width in
            let column = Int((point.x / max(width, 1)) * 3)
            switch column {
            case 0: stepRequest = ContinuousStripViewStep(id: (stepRequest?.id ?? 0) + 1, forward: false)
            case 2...: stepRequest = ContinuousStripViewStep(id: (stepRequest?.id ?? 0) + 1, forward: true)
            default: withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() }
            }
        }
        .ignoresSafeArea()
        #else
        ScrollView {
            LazyVStack(spacing: continuous.pageSpacing) {
                ForEach(continuous.pages) { page in
                    Text("Page \(page.pageNumber)").foregroundStyle(.white)
                }
            }
        }
        #endif
    }

    @ViewBuilder private func pageErrors(_ pages: [LoadedPage]) -> some View {
        if let error = pages.compactMap(\.error).first {
            ContentUnavailableView("Page failed to load", systemImage: "exclamationmark.triangle",
                                   description: Text(error.localizedDescription))
                .foregroundStyle(.white)
        } else if pages.contains(where: { $0.image == nil }) {
            ProgressView().tint(.white)
        }
    }

    // MARK: Overlay

    private var closeButton: some View {
        Button { onClose(nil) } label: {
            Image(systemName: "xmark").font(.headline).padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Close reader")
    }

    private var currentPage: Int {
        model.readerType == .continuous ? (continuous?.currentPageNumber ?? 1) : (paged?.currentPageNumber ?? 1)
    }

    private var pageCount: Int { model.books?.currentBookPages.count ?? 0 }

    private var overlay: some View {
        VStack {
            HStack(spacing: 12) {
                closeButton
                VStack(alignment: .leading) {
                    Text(model.currentBook?.metadata.title ?? "").font(.headline).lineLimit(1)
                    Text(model.series?.metadata.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.headline).padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Reader settings")
            }
            .padding()
            .background(.regularMaterial)

            Spacer()

            if pageCount > 1 {
                VStack(spacing: 4) {
                    Slider(value: $sliderPage, in: 1...Double(pageCount), step: 1) { editing in
                        if !editing { jump(to: Int(sliderPage)) }
                    }
                    .environment(\.layoutDirection,
                                 paged?.readingDirection == .rightToLeft && model.readerType == .paged
                                     ? .rightToLeft : .leftToRight)
                    Text("\(Int(sliderPage)) / \(pageCount)").font(.caption.monospacedDigit())
                }
                .padding()
                .background(.regularMaterial)
                .onAppear { sliderPage = Double(currentPage) }
                .onChange(of: currentPage) { _, page in sliderPage = Double(page) }
            }
        }
        .transition(.opacity)
    }

    /// Physical arrow keys follow the paged reading direction.
    private func turn(physicalLeft: Bool) {
        let rtl = paged?.readingDirection == .rightToLeft
        advance(forward: physicalLeft == rtl)
    }

    private func advance(forward: Bool) {
        if model.readerType == .continuous {
            stepRequest = ContinuousStripViewStep(id: (stepRequest?.id ?? 0) + 1, forward: forward)
        } else if forward {
            paged?.nextPage()
        } else {
            paged?.previousPage()
        }
    }

    private func jump(to page: Int) {
        if model.readerType == .continuous {
            continuous?.scroll(toPage: page)
        } else {
            paged?.goTo(pageNumber: page)
        }
    }

    // MARK: Flash (`EInkFlashOverlay`)

    private var flashOverlay: some View {
        let color = model.settings.value.flashWith
        return (color == .white ? Color.white : Color.black).ignoresSafeArea()
    }

    private func triggerFlash() {
        let settings = model.settings.value
        guard settings.flashOnPageChange, let counter = paged?.pageChangeCounter,
              counter % max(settings.flashEveryNPages, 1) == 0 else { return }
        flash = true
        Task {
            try? await Task.sleep(for: .milliseconds(settings.flashDuration))
            flash = false
        }
    }
}

struct ContinuousStripViewStep: Equatable {
    let id: Int
    let forward: Bool
}

private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// `BookStart` / `BookEnd` transition page.
struct TransitionPageView: View {
    let page: TransitionPage

    var body: some View {
        VStack(spacing: 16) {
            switch page {
            case .bookStart(let current, let previous):
                Text("Start of").foregroundStyle(.secondary)
                Text(current.metadata.title).font(.title2.bold())
                if let previous {
                    Text("Previous: \(previous.metadata.title)")
                } else {
                    Text("This is the first book")
                }
            case .bookEnd(let current, let next):
                Text("Finished").foregroundStyle(.secondary)
                Text(current.metadata.title).font(.title2.bold())
                if let next {
                    Text("Next: \(next.metadata.title)")
                } else {
                    Text("There are no more books")
                }
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if !canImport(UIKit)
private struct MacPageImage: View {
    let page: LoadedPage
    @State private var bitmap: PageBitmap?

    var body: some View {
        Group {
            if let bitmap { Image(decorative: bitmap.image, scale: 1).resizable().scaledToFit() } else { ProgressView() }
        }
        .task(id: page.id) { bitmap = await page.image?.bitmap(forDisplayedPixels: CGSize(width: 1600, height: 1600)) }
    }
}
#endif

extension View {
    @ViewBuilder func statusBarHiddenCompat(_ hidden: Bool) -> some View {
        #if os(iOS)
        self.statusBarHidden(hidden).persistentSystemOverlays(hidden ? .hidden : .automatic)
        #else
        self
        #endif
    }
}
