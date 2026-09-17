import KomgaAPI
import SwiftUI

/// Placeholder root. Replaced by the login -> main shell flow in Phases 2/4 (MainView.kt).
struct RootView: View {
    var body: some View {
        ContentUnavailableView("Komelia", systemImage: "books.vertical", description: Text("Komga client — work in progress"))
    }
}

#Preview {
    RootView()
}
