import Foundation
import KomeliaCore
import KomgaAPI
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Where the EPUB content comes from.
public enum EpubSource: Sendable {
    /// Komga WebPub manifest; every request must carry the auth headers.
    case remote(manifest: URL, headers: @Sendable (URL) -> [String: String])
    /// Downloaded `.epub` (offline mode).
    case local(file: URL)
}

/// Readium locator in the JSON shape Komga stores (`R2Locator`), independent of the Readium library so this
/// module (and its tests) do not depend on it.
public struct EpubLocation: Hashable, Sendable {
    public var href: String
    public var type: String
    public var progression: Double?
    public var totalProgression: Double?
    public var position: Int?

    public init(href: String, type: String, progression: Double?, totalProgression: Double?, position: Int?) {
        self.href = href
        self.type = type
        self.progression = progression
        self.totalProgression = totalProgression
        self.position = position
    }
}

/// Port of `KomgaEpubReaderState.kt` (minus the WebView bridge): loads/saves Readium progression through the
/// `KomgaApi` protocol, so it works online and offline, and converts hrefs between Komga's book-relative form
/// and the reader's absolute resource URLs (`progressionToWebview` / `progressionFromWebview`).
@MainActor
@Observable
public final class EpubReaderModel: Identifiable {
    public nonisolated let id = UUID()

    public let book: KomeliaBook
    public let source: EpubSource
    public let settings: EpubReaderSettingsRepository
    public private(set) var initialLocation: EpubLocation?
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var currentProgress: Double = 0

    private let api: any KomgaApi
    private let resourceBase: String?
    private let markReadProgress: Bool
    private var pendingSave: Task<Void, Never>?

    public init(
        book: KomeliaBook, source: EpubSource, api: any KomgaApi, settings: EpubReaderSettingsRepository,
        markReadProgress: Bool = true
    ) {
        self.book = book
        self.source = source
        self.api = api
        self.settings = settings
        self.markReadProgress = markReadProgress
        if case .remote(let manifest, _) = source {
            // `.../api/v1/books/{id}/manifest` → `.../api/v1/books/{id}/resource/`
            resourceBase = manifest.deletingLastPathComponent().appending(path: "resource").absoluteString + "/"
        } else {
            resourceBase = nil
        }
    }

    public func initialize() async {
        guard state.isUninitialized else { return }
        state = .loading
        do {
            if let progression = try await api.bookApi.getReadiumProgression(book.id) {
                initialLocation = toReader(progression.locator)
                currentProgress = Double(progression.locator.locations?.totalProgression ?? 0)
            }
            state = .success(())
        } catch {
            // No stored progression is not fatal; start from the beginning.
            state = .success(())
        }
    }

    /// Called on every location change; saves are debounced (page turns can be rapid).
    public func locationChanged(_ location: EpubLocation) {
        currentProgress = location.totalProgression ?? currentProgress
        guard markReadProgress else { return }
        pendingSave?.cancel()
        let progression = R2Progression(
            modified: Date(), device: Self.device, locator: toKomga(location))
        let api = self.api
        let bookId = book.id
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            try? await api.bookApi.updateReadiumProgression(bookId, progression: progression)
        }
    }

    // MARK: href mapping

    /// The Readium host serves remote books with book-relative hrefs (see `ManifestRelativizer`), so Komga's
    /// stored hrefs are used as-is; absolute ones (older clients) are relativized.
    func toReader(_ locator: R2Locator) -> EpubLocation {
        var href = locator.href
        if let resourceBase, href.hasPrefix(resourceBase) { href.removeFirst(resourceBase.count) }
        return EpubLocation(
            href: href, type: locator.type,
            progression: locator.locations?.progression.map(Double.init),
            totalProgression: locator.locations?.totalProgression.map(Double.init),
            position: locator.locations?.position)
    }

    func toKomga(_ location: EpubLocation) -> R2Locator {
        var href = location.href
        if let resourceBase, href.hasPrefix(resourceBase) { href.removeFirst(resourceBase.count) }
        if href.hasPrefix("/") { href.removeFirst() }
        return R2Locator(
            href: href, type: location.type,
            locations: R2Location(
                position: location.position, progression: location.progression.map(Float.init),
                totalProgression: location.totalProgression.map(Float.init)))
    }

    static var device: R2Device {
        #if canImport(UIKit)
        R2Device(id: UIDevice.current.identifierForVendor?.uuidString ?? "komelia-ios", name: "Komelia iOS")
        #else
        R2Device(id: "komelia-macos", name: "Komelia")
        #endif
    }
}

/// Implemented outside this package (Readium lives in `KomeliaEpubKit`, iOS-only) and injected by the app.
@MainActor
public protocol EpubReaderPresenting {
    func makeReader(model: EpubReaderModel, onClose: @escaping () -> Void) -> AnyView
}

extension EnvironmentValues {
    @Entry public var epubReaderPresenter: (any EpubReaderPresenting)?
}
