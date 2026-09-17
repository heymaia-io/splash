import KomeliaCore
import KomgaAPI
import SwiftUI

/// Port of `SettingsScreenContainer` + `settings/navigation` (Desktop/Mobile variants collapse into one
/// NavigationStack; iPad shows it as a large sheet).
/// Out of scope (plan): updates, Komf, ONNX, EPUB settings.
public struct SettingsView: View {
    let session: any AppSession
    let extraSections: AnyView?
    let onLoggedOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(session: any AppSession, extraSections: AnyView? = nil, onLoggedOut: @escaping () -> Void) {
        self.session = session
        self.extraSections = extraSections
        self.onLoggedOut = onLoggedOut
    }

    private var isAdmin: Bool { session.authState.authenticatedUser?.isAdmin ?? false }
    private var api: any KomgaApi { session.viewModelFactory.apiProvider() }

    public var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    NavigationLink { AppearanceSettingsView(settings: session.settings) } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    NavigationLink { ImageReaderSettingsView(settings: session.viewModelFactory.imageReaderSettings) } label: {
                        Label("Image reader", systemImage: "book")
                    }
                    if let extraSections { extraSections }
                }
                Section("Account") {
                    NavigationLink { AccountSettingsView(session: session, onLoggedOut: onLoggedOut) } label: {
                        Label("My account", systemImage: "person.crop.circle")
                    }
                    NavigationLink { AuthenticationActivityView(api: api, all: false) } label: {
                        Label("My authentication activity", systemImage: "clock.arrow.circlepath")
                    }
                }
                if isAdmin {
                    Section("Server") {
                        NavigationLink { ServerSettingsView(api: api, libraries: session.authState.libraries) } label: {
                            Label("Server settings", systemImage: "server.rack")
                        }
                        NavigationLink { UsersView(api: api) } label: {
                            Label("Users", systemImage: "person.2")
                        }
                        NavigationLink { AuthenticationActivityView(api: api, all: true) } label: {
                            Label("Authentication activity", systemImage: "list.bullet.rectangle")
                        }
                        NavigationLink { MediaAnalysisView(api: api) } label: {
                            Label("Media analysis", systemImage: "exclamationmark.triangle")
                        }
                        NavigationLink { AnnouncementsView(api: api) } label: {
                            Label("Announcements", systemImage: "megaphone")
                        }
                    }
                }
                Section {
                    NavigationLink { AboutView() } label: { Label("About", systemImage: "info.circle") }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Appearance (`AppSettingsViewModel`)

struct AppearanceSettingsView: View {
    let settings: CommonSettingsRepository
    @State private var value: AppSettings

    init(settings: CommonSettingsRepository) {
        self.settings = settings
        _value = State(initialValue: settings.value)
    }

    var body: some View {
        Form {
            Picker("Theme", selection: persisted(\.appTheme)) {
                Text("Dark").tag(AppTheme.dark)
                Text("Darker").tag(AppTheme.darker)
                Text("Light").tag(AppTheme.light)
            }
            Section("Library") {
                LabeledContent("Card width \(value.cardWidth) pt") {
                    Slider(value: Binding(
                        get: { Double(value.cardWidth) }, set: { persisted(\.cardWidth).wrappedValue = Int($0) }),
                           in: 120...300, step: 10)
                }
                Stepper("Series per page: \(value.seriesPageLoadSize)", value: persisted(\.seriesPageLoadSize),
                        in: 10...200, step: 10)
                Stepper("Books per page: \(value.bookPageLoadSize)", value: persisted(\.bookPageLoadSize),
                        in: 10...200, step: 10)
            }
            Section("Preview") {
                SeriesCardPreview(width: CGFloat(value.cardWidth))
            }
        }
        .navigationTitle("Appearance")
    }

    private func persisted<T: Sendable & Equatable>(_ keyPath: WritableKeyPath<AppSettings, T> & Sendable) -> Binding<T> {
        Binding(get: { value[keyPath: keyPath] }, set: { newValue in
            value[keyPath: keyPath] = newValue
            Task { try? await settings.set(keyPath, newValue) }
        })
    }
}

private struct SeriesCardPreview: View {
    let width: CGFloat
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6).fill(.tint.opacity(0.3))
                .frame(width: width, height: width / 0.703)
            Text("Series title").font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image reader defaults (`settings/imagereader`)

struct ImageReaderSettingsView: View {
    let settings: ImageReaderSettingsRepository
    @State private var value: ImageReaderSettings

    init(settings: ImageReaderSettingsRepository) {
        self.settings = settings
        _value = State(initialValue: settings.value)
    }

    var body: some View {
        Form {
            Section {
                Picker("Default reader", selection: persisted(\.readerType)) {
                    Text("Paged").tag(ReaderType.paged)
                    Text("Continuous").tag(ReaderType.continuous)
                }
                Toggle("Stretch small images to fit", isOn: persisted(\.stretchToFit))
                Toggle("Crop borders", isOn: persisted(\.cropBorders))
                Toggle("Load page thumbnail previews", isOn: persisted(\.loadThumbnailPreviews))
            } footer: {
                Text("Series with a reading direction set in Komga override the default reader.")
            }
            Section("Paged") {
                Picker("Scale", selection: persisted(\.pagedScaleType)) {
                    Text("Fit screen").tag(LayoutScaleType.screen)
                    Text("Fit width").tag(LayoutScaleType.fitWidth)
                    Text("Fit height").tag(LayoutScaleType.fitHeight)
                    Text("Original").tag(LayoutScaleType.original)
                }
                Picker("Direction", selection: persisted(\.pagedReadingDirection)) {
                    Text("Left to right").tag(PagedReadingDirection.leftToRight)
                    Text("Right to left").tag(PagedReadingDirection.rightToLeft)
                }
                Picker("Layout", selection: persisted(\.pagedPageLayout)) {
                    Text("Single page").tag(PageDisplayLayout.singlePage)
                    Text("Double pages").tag(PageDisplayLayout.doublePages)
                    Text("Double pages (no cover)").tag(PageDisplayLayout.doublePagesNoCover)
                }
            }
            Section("Continuous") {
                Picker("Direction", selection: persisted(\.continuousReadingDirection)) {
                    Text("Top to bottom").tag(ContinuousReadingDirection.topToBottom)
                    Text("Left to right").tag(ContinuousReadingDirection.leftToRight)
                    Text("Right to left").tag(ContinuousReadingDirection.rightToLeft)
                }
                Stepper("Page spacing: \(value.continuousPageSpacing)", value: persisted(\.continuousPageSpacing),
                        in: 0...200, step: 5)
            }
            Section("Page change flash") {
                Toggle("Flash on page change", isOn: persisted(\.flashOnPageChange))
                Stepper("Every \(value.flashEveryNPages) pages", value: persisted(\.flashEveryNPages), in: 1...20)
                Stepper("Duration \(value.flashDuration) ms", value: persisted(\.flashDuration), in: 50...1000, step: 50)
            }
        }
        .navigationTitle("Image reader")
    }

    private func persisted<T: Sendable & Equatable>(
        _ keyPath: WritableKeyPath<ImageReaderSettings, T> & Sendable
    ) -> Binding<T> {
        Binding(get: { value[keyPath: keyPath] }, set: { newValue in
            value[keyPath: keyPath] = newValue
            Task { try? await settings.set(keyPath, newValue) }
        })
    }
}

// MARK: - Account (`AccountSettingsViewModel`)

struct AccountSettingsView: View {
    let session: any AppSession
    let onLoggedOut: () -> Void
    @State private var newPassword = ""
    @State private var message: String?

    var body: some View {
        Form {
            if let user = session.authState.authenticatedUser {
                Section {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Server", value: session.settings.value.serverUrl)
                    LabeledContent("Roles", value: user.roles.sorted().joined(separator: ", "))
                }
            }
            Section("Change password") {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                Button("Update password") {
                    Task {
                        do {
                            try await session.viewModelFactory.apiProvider().userApi.updateMyPassword(newPassword)
                            newPassword = ""
                            message = String(localized: "Password updated")
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                }
                .disabled(newPassword.count < 1)
                if let message { Text(message).font(.footnote) }
            }
            Section {
                Button("Log out", role: .destructive) {
                    Task {
                        await session.logout()
                        onLoggedOut()
                    }
                }
            }
        }
        .navigationTitle("My account")
    }
}

// MARK: - Generic remote list screen

/// Small helper for the read-only admin lists (users, activity, analysis, announcements).
struct RemoteListView<Item: Identifiable, Row: View>: View {
    let title: LocalizedStringKey
    let load: () async throws -> [Item]
    @ViewBuilder let row: (Item) -> Row
    @State private var items: [Item] = []
    @State private var error: Error?
    @State private var loaded = false

    var body: some View {
        List(items) { row($0) }
            .overlay {
                if let error {
                    ErrorView(error: error) { Task { await reload() } }
                } else if !loaded {
                    ProgressView()
                } else if items.isEmpty {
                    ContentUnavailableView("Nothing here", systemImage: "tray")
                }
            }
            .navigationTitle(title)
            .task { await reload() }
            .refreshable { await reload() }
    }

    private func reload() async {
        do {
            items = try await load()
            error = nil
        } catch {
            self.error = error
        }
        loaded = true
    }
}

struct UsersView: View {
    let api: any KomgaApi
    var body: some View {
        RemoteListView(title: "Users", load: { try await api.userApi.getAllUsers() }) { user in
            VStack(alignment: .leading) {
                Text(user.email)
                Text(user.roles.sorted().joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ActivityRow: Identifiable {
    let id = UUID()
    let activity: KomgaAuthenticationActivity
}

struct AuthenticationActivityView: View {
    let api: any KomgaApi
    let all: Bool
    var body: some View {
        RemoteListView(title: all ? "Authentication activity" : "My authentication activity", load: {
            let request = KomgaPageRequest(size: 100, sort: KomgaUserSort.byDateTime(.desc))
            let page = all
                ? try await api.userApi.getAuthenticationActivity(pageRequest: request, unpaged: false)
                : try await api.userApi.getMeAuthenticationActivity(pageRequest: request, unpaged: false)
            return page.content.map { ActivityRow(activity: $0) }
        }) { row in
            let a = row.activity
            HStack {
                Image(systemName: a.success ? "checkmark.circle" : "xmark.octagon")
                    .foregroundStyle(a.success ? .green : .red)
                VStack(alignment: .leading) {
                    Text(a.email ?? "—")
                    Text("\(a.dateTime.formatted()) · \(a.source) · \(a.ip ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let agent = a.userAgent { Text(agent).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        }
    }
}

/// `MediaAnalysisViewModel` — books whose media is in ERROR/UNSUPPORTED state.
struct MediaAnalysisView: View {
    let api: any KomgaApi
    var body: some View {
        RemoteListView(title: "Media analysis", load: {
            try await api.bookApi.getBookList(
                condition: .anyOfBooks(.mediaStatus(.isEqualTo(.error)), .mediaStatus(.isEqualTo(.unsupported))),
                pageRequest: KomgaPageRequest(size: 500)
            ).content
        }) { book in
            VStack(alignment: .leading) {
                Text(book.name)
                Text(book.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text("\(book.media.status.rawValue) \(book.media.comment)").font(.caption).foregroundStyle(.red)
            }
        }
    }
}

struct AnnouncementsView: View {
    let api: any KomgaApi
    var body: some View {
        RemoteListView(title: "Announcements", load: { try await api.announcementsApi.getAnnouncements().items }) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "").font(.headline)
                if let date = item.dateModified { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption) }
                if let summary = item.summary { Text(summary).font(.subheadline) }
                if let link = item.url.flatMap(URL.init(string:)) { Link("Read more", destination: link) }
            }
        }
    }
}

// MARK: - Server (`ServerSettingsViewModel`, admin)

struct ServerSettingsView: View {
    let api: any KomgaApi
    let libraries: [KomgaLibrary]
    @State private var settings: KomgaSettings?
    @State private var message: String?

    var body: some View {
        Form {
            if let settings {
                Section("Server") {
                    Toggle("Delete empty collections", isOn: binding(settings.deleteEmptyCollections) {
                        $0.deleteEmptyCollections = .some($1)
                    })
                    Toggle("Delete empty read lists", isOn: binding(settings.deleteEmptyReadLists) {
                        $0.deleteEmptyReadLists = .some($1)
                    })
                    LabeledContent("Remember me (days)", value: "\(settings.rememberMeDurationDays)")
                    LabeledContent("Thumbnail size", value: settings.thumbnailSize.rawValue.capitalized)
                    LabeledContent("Task threads", value: "\(settings.taskPoolSize)")
                }
            }
            Section("Libraries") {
                ForEach(libraries) { library in
                    Menu {
                        Button("Scan library files") { run { try await api.libraryApi.scan(library.id, deep: false) } }
                        Button("Scan (deep)") { run { try await api.libraryApi.scan(library.id, deep: true) } }
                        Button("Analyze") { run { try await api.libraryApi.analyze(library.id) } }
                        Button("Refresh metadata") { run { try await api.libraryApi.refreshMetadata(library.id) } }
                        Button("Empty trash") { run { try await api.libraryApi.emptyTrash(library.id) } }
                    } label: {
                        LabeledContent(library.name, value: library.root)
                    }
                }
            }
            Section {
                Button("Empty task queue") {
                    run {
                        let count = try await api.tasksApi.emptyTaskQueue()
                        message = String(localized: "\(count) tasks removed")
                    }
                }
            }
            if let message { Text(message).font(.footnote) }
        }
        .navigationTitle("Server settings")
        .task { settings = try? await api.settingsApi.getSettings() }
    }

    private func binding(
        _ current: Bool, apply: @escaping (inout KomgaSettingsUpdateRequest, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(get: { current }, set: { newValue in
            run {
                var request = KomgaSettingsUpdateRequest()
                apply(&request, newValue)
                try await api.settingsApi.updateSettings(request)
                settings = try await api.settingsApi.getSettings()
            }
        })
    }

    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                if message == nil { message = String(localized: "Done") }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        Form {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            Section {
                Text("A client for Komga servers. Reading online is free and unlimited; offline reading is a one-time purchase.")
                Text("Privacy: the app collects no data. Everything stays on your device and your Komga server.")
                NavigationLink("Third-party licenses") { LicensesView() }
            }
            Section {
                Link("Komelia on GitHub", destination: URL(string: "https://github.com/Snd-R/Komelia")!)
                Link("Komga", destination: URL(string: "https://komga.org")!)
            }
        }
        .navigationTitle("About")
    }
}

// MARK: - Theme (`Theme.kt`)

extension AppTheme {
    var colorScheme: ColorScheme {
        self == .light ? .light : .dark
    }
}
