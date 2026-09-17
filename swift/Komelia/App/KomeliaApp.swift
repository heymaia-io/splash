import KomeliaAppShared
import KomeliaUI
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

    var body: some View {
        Group {
            if let module {
                AppRootView(session: module)
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
                module = try await AppModule.makeDefault()
            } catch {
                self.error = error
            }
        }
    }
}
