import KomeliaAppShared
import KomeliaEpubKit
import KomeliaUI
import KomgaAPI
import SwiftUI
import UIKit

@main
struct KomeliaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            BootstrapView(bootstrap: appDelegate.bootstrap)
        }
    }
}

/// Owns the composition root so UIKit callbacks (background downloads) can reach it.
@MainActor
final class AppBootstrap {
    private(set) var module: AppModule?
    private var pendingBackgroundEvents: [(String, @Sendable () -> Void)] = []

    func load() async throws -> AppModule {
        if let module { return module }
        let created = try await AppModule.makeDefaultWithStore()
        module = created
        for (identifier, completion) in pendingBackgroundEvents {
            created.handleBackgroundURLSessionEvents(identifier: identifier, completion: completion)
        }
        pendingBackgroundEvents.removeAll()
        return created
    }

    func handleBackgroundEvents(identifier: String, completion: @escaping @Sendable () -> Void) {
        if let module {
            module.handleBackgroundURLSessionEvents(identifier: identifier, completion: completion)
        } else {
            // The system can relaunch the app just to deliver download results; build the graph first.
            pendingBackgroundEvents.append((identifier, completion))
            Task { _ = try? await load() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    @MainActor let bootstrap = AppBootstrap()

    func application(
        _ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // UIKit's handler must run on the main thread; wrap it as @Sendable for the download manager.
        nonisolated(unsafe) let handler = completionHandler
        let completion: @Sendable () -> Void = { DispatchQueue.main.async { handler() } }
        MainActor.assumeIsolated {
            bootstrap.handleBackgroundEvents(identifier: identifier, completion: completion)
        }
    }
}

/// Builds the composition root asynchronously (`MainView` shows a loading indicator while
/// `dependencies == null` in the Kotlin app).
struct BootstrapView: View {
    let bootstrap: AppBootstrap
    @State private var module: AppModule?
    @State private var error: Error?
    @State private var initialBook: KomeliaBook?
    private let epubPresenter = ReadiumEpubReaderPresenter()

    var body: some View {
        Group {
            if let module {
                AppRootView(session: module, initialBook: initialBook)
                    .environment(\.epubReaderPresenter, epubPresenter)
            } else if let error {
                ContentUnavailableView(
                    "Komelia failed to start", systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription))
            } else {
                ProgressView()
            }
        }
        .task {
            guard module == nil else { return }
            do {
                let created = try await bootstrap.load()
                #if DEBUG
                initialBook = await created.debugBootstrap(environment: ProcessInfo.processInfo.environment)
                if ProcessInfo.processInfo.environment["KOMELIA_DEBUG_PAYWALL"] == "1" {
                    created.entitlements?.requestUnlock()
                }
                #endif
                module = created
            } catch {
                self.error = error
            }
        }
    }
}
