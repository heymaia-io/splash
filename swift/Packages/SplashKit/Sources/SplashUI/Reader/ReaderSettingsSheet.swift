import SplashCore
import SwiftUI

/// Port of `BottomSheetSettingsOverlay.kt` — two tabs: "Reading mode" and "Image settings".
struct ReaderSettingsSheet: View {
    let model: ReaderViewModel
    let paged: PagedReaderModel?
    let continuous: ContinuousReaderModel?
    @State private var tab = 0
    @State private var settings: ImageReaderSettings

    init(model: ReaderViewModel, paged: PagedReaderModel?, continuous: ContinuousReaderModel?) {
        self.model = model
        self.paged = paged
        self.continuous = continuous
        _settings = State(initialValue: model.settings.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Section", selection: $tab) {
                    Text("Reading mode").tag(0)
                    Text("Image settings").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if tab == 0 { readingMode } else { imageSettings }
            }
            .navigationTitle("Reader settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    @ViewBuilder private var readingMode: some View {
        Section {
            Picker("Reader", selection: Binding(get: { model.readerType }, set: { model.setReaderType($0) })) {
                Text("Paged").tag(ReaderType.paged)
                Text("Continuous").tag(ReaderType.continuous)
            }
            .pickerStyle(.segmented)
        } footer: {
            if model.series?.metadata.readingDirection != nil {
                Text("The series reading direction chooses the reader when the book is opened.")
            }
        }

        if model.readerType == .paged, let paged {
            Section("Paged") {
                Picker("Scale", selection: Binding(get: { paged.scaleType }, set: { paged.setScaleType($0) })) {
                    Text("Fit screen").tag(LayoutScaleType.screen)
                    Text("Fit width").tag(LayoutScaleType.fitWidth)
                    Text("Fit height").tag(LayoutScaleType.fitHeight)
                    Text("Original").tag(LayoutScaleType.original)
                }
                Picker("Direction", selection: Binding(get: { paged.readingDirection }, set: { paged.setReadingDirection($0) })) {
                    Text("Left to right").tag(PagedReadingDirection.leftToRight)
                    Text("Right to left").tag(PagedReadingDirection.rightToLeft)
                }
                Picker("Layout", selection: Binding(get: { paged.layout }, set: { paged.setLayout($0) })) {
                    Text("Single page").tag(PageDisplayLayout.singlePage)
                    Text("Double pages").tag(PageDisplayLayout.doublePages)
                    Text("Double pages (no cover)").tag(PageDisplayLayout.doublePagesNoCover)
                }
                if paged.layout != .singlePage {
                    Button("Offset pages by one", action: paged.toggleLayoutOffset)
                }
            }
        }

        if model.readerType == .continuous, let continuous {
            Section("Continuous") {
                Picker("Direction", selection: Binding(
                    get: { continuous.readingDirection }, set: { continuous.setReadingDirection($0) })
                ) {
                    Text("Top to bottom").tag(ContinuousReadingDirection.topToBottom)
                    Text("Left to right").tag(ContinuousReadingDirection.leftToRight)
                    Text("Right to left").tag(ContinuousReadingDirection.rightToLeft)
                }
                LabeledContent("Side padding \(Int(continuous.sidePaddingFraction * 100))%") {
                    Slider(value: Binding(get: { continuous.sidePaddingFraction }, set: { continuous.setSidePadding($0) }),
                           in: 0...0.45, step: 0.05)
                }
                LabeledContent("Page spacing \(Int(continuous.pageSpacing))") {
                    Slider(value: Binding(get: { continuous.pageSpacing }, set: { continuous.setPageSpacing($0) }),
                           in: 0...200, step: 5)
                }
            }
        }
    }

    @ViewBuilder private var imageSettings: some View {
        Section {
            Toggle("Stretch small images to fit", isOn: bind(\.stretchToFit) { _ in paged?.reloadImages() })
            Toggle("Crop borders", isOn: bind(\.cropBorders) { _ in
                paged?.reloadImages()
                continuous?.reloadImages()
            })
        }
        Section("Page change flash") {
            Toggle("Flash on page change", isOn: bind(\.flashOnPageChange))
            if settings.flashOnPageChange {
                Stepper("Every \(settings.flashEveryNPages) pages", value: bind(\.flashEveryNPages), in: 1...20)
                Stepper("Duration \(settings.flashDuration) ms", value: bind(\.flashDuration), in: 50...1000, step: 50)
                Picker("Color", selection: bind(\.flashWith)) {
                    Text("Black").tag(ReaderFlashColor.black)
                    Text("White").tag(ReaderFlashColor.white)
                    Text("White and black").tag(ReaderFlashColor.whiteAndBlack)
                }
            }
        }
    }

    /// Two-way binding that persists through the settings repository.
    private func bind<T: Sendable & Equatable>(
        _ keyPath: WritableKeyPath<ImageReaderSettings, T> & Sendable,
        onChange: ((T) -> Void)? = nil
    ) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                Task {
                    try? await model.settings.set(keyPath, newValue)
                    onChange?(newValue)
                }
            })
    }
}
