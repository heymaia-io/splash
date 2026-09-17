import SwiftUI

/// Port of `LoginScreen.kt` / `LoginContent.kt` (+ `AutoLoginError`).
public struct LoginView: View {
    @Bindable var model: LoginViewModel
    @State private var showAutoLoginError = true
    @FocusState private var focused: Field?
    @Environment(\.offlineController) private var offline
    @State private var offlineUsers: [OfflineUserChoice] = []

    private enum Field { case url, user, password, apiKey }

    public init(model: LoginViewModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if let error = model.autoLoginError, showAutoLoginError {
                autoLoginErrorView(error)
            } else if model.state == .uninitialized {
                ProgressView()
            } else {
                form
            }
        }
        .task {
            await model.initialize()
            offlineUsers = await offline?.offlineUsers() ?? []
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Server URL", text: $model.url, prompt: Text(verbatim: "https://yourserver.com"))
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .url)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.next)
                    .onSubmit { focused = model.mode == .credentials ? .user : .apiKey }

                Picker("Authentication", selection: $model.mode) {
                    Text("Username").tag(LoginViewModel.Mode.credentials)
                    Text("API Key").tag(LoginViewModel.Mode.apiKey)
                }
                .pickerStyle(.segmented)

                if model.mode == .credentials {
                    TextField("Username", text: $model.user)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .focused($focused, equals: .user)
                        .submitLabel(.next)
                        .onSubmit { focused = .password }
                    SecureField("Password", text: $model.password)
                        .textContentType(.password)
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(model.login)
                } else {
                    SecureField("API Key", text: $model.apiKey)
                        .focused($focused, equals: .apiKey)
                        .submitLabel(.go)
                        .onSubmit(model.login)
                }
            } header: {
                Text("Komga Login")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .padding(.bottom, 8)
            } footer: {
                if let error = model.userLoginError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                if model.state == .loading {
                    HStack {
                        ProgressView()
                        Spacer()
                        Button("Cancel login attempt", role: .cancel, action: model.cancel)
                    }
                } else {
                    Button(action: model.login) {
                        Text("Login").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.url.isEmpty)
                }
            }
            .listRowBackground(Color.clear)

            if let offline, !offlineUsers.isEmpty {
                Section("Offline mode") {
                    ForEach(offlineUsers) { user in
                        Button {
                            Task { await offline.goOffline(as: user.id) }
                        } label: {
                            VStack(alignment: .leading) {
                                Text("Read downloads as \(user.email)")
                                if let server = user.serverURL {
                                    Text(server).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.top, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Self.groupedBackground.ignoresSafeArea())
    }

    #if os(iOS)
    private static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    #else
    private static let groupedBackground = Color(nsColor: .windowBackgroundColor)
    #endif

    private func autoLoginErrorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Login error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            if model.state == .loading {
                ProgressView()
            } else {
                Button("Retry", action: model.retryAutoLogin)
                    .buttonStyle(.borderedProminent)
                if let offline, let user = offlineUsers.first {
                    Button("Go offline") { Task { await offline.goOffline(as: user.id) } }
                }
                Button("Login with another account") { showAutoLoginError = false }
            }
        }
    }
}
