import KomeliaAppShared
import KomeliaUI
import KomgaAPI
import SwiftUI

@main
struct KomeliaApp: App {
    var body: some Scene {
        WindowGroup {
            BootstrapView()
        }
    }
}

/// Builds the composition root asynchronously (`MainView` shows a loading indicator while
/// `dependencies == null` in the Kotlin app).
struct BootstrapView: View {
    @State private var module: AppModule?
    @State private var error: Error?
    @State private var initialBook: KomeliaBook?

    var body: some View {
        Group {
            if let module {
                AppRootView(session: module, initialBook: initialBook)
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
                let created = try await AppModule.makeDefault()
                #if DEBUG
                initialBook = await created.debugBootstrap(environment: ProcessInfo.processInfo.environment)
                #endif
                module = created
            } catch {
                self.error = error
            }
        }
    }
}
