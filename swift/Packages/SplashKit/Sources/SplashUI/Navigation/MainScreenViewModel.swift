import Foundation
import SplashCore
import KomgaAPI
import Observation

/// Port of `snd.komelia.ui.MainScreenViewModel` (search bar/notifications/offline switch arrive in later phases).
@MainActor
@Observable
public final class MainScreenViewModel {
    public let navigator: MainNavigator
    public private(set) var taskQueueStatus: KomgaEvent.TaskQueueStatusPayload?
    /// Text in the global search field. It lives on the shell rather than on a screen so the same field
    /// follows the user across every tab and every pushed screen.
    public var searchQuery = ""

    private let authState: KomgaAuthenticationState
    private var eventTask: Task<Void, Never>?

    public init(navigator: MainNavigator = MainNavigator(), authState: KomgaAuthenticationState) {
        self.navigator = navigator
        self.authState = authState
    }

    public var libraries: [KomgaLibrary] { authState.libraries }

    /// `startEventListener()` — call with the shared event stream (Phase 7 wires the live SSE session).
    public func startListening(to events: AsyncStream<KomgaEvent>) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    public func stopListening() {
        eventTask?.cancel()
        eventTask = nil
    }

    /// Delete events arrive bottom-up (book → series → library), so screens unwind in the right order.
    public func handle(_ event: KomgaEvent) {
        switch event {
        case .taskQueueStatus(let status):
            taskQueueStatus = status
        case .bookDeleted(let payload):
            if navigator.lastItem == .book(payload.bookId) {
                navigator.replaceAll(.series(payload.seriesId))
            }
        case .seriesDeleted(let payload):
            // Kotlin: `last is SeriesScreen || last is OneshotScreen && id == ...` — operator precedence made
            // *any* series screen navigate away. Fixed: both cases compare the id.
            if navigator.lastItem == .series(payload.seriesId) || navigator.lastItem == .oneshot(payload.seriesId) {
                navigator.replaceAll(.library(payload.libraryId))
            }
        case .libraryDeleted(let payload):
            if navigator.lastItem == .library(payload.libraryId) {
                navigator.replaceAll(.home)
            }
        case .collectionDeleted(let payload):
            if navigator.lastItem == .collection(payload.collectionId) { unwindToLibraryOrHome() }
        case .readListDeleted(let payload):
            if navigator.lastItem == .readList(payload.readListId) { unwindToLibraryOrHome() }
        default:
            break
        }
    }

    private func unwindToLibraryOrHome() {
        let found = navigator.popUntil { if case .library = $0 { true } else { false } }
        if !found { navigator.replaceAll(.home) }
    }
}
