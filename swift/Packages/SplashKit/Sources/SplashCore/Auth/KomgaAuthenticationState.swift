import Foundation
import KomgaAPI
import Observation

/// Port of `snd.komelia.KomgaAuthenticationState` — the authenticated user + visible libraries shared by
/// every screen.
@MainActor
@Observable
public final class KomgaAuthenticationState {
    public enum DataState: Equatable, Sendable {
        case authenticationRequired
        case loaded
    }

    public private(set) var authenticatedUser: KomgaUser?
    public private(set) var libraries: [KomgaLibrary] = []
    public private(set) var state: DataState = .authenticationRequired

    public init() {}

    public func setStateValues(user: KomgaUser, libraries: [KomgaLibrary]) {
        authenticatedUser = user
        self.libraries = libraries
        state = .loaded
    }

    public func updateLibraries(_ libraries: [KomgaLibrary]) {
        self.libraries = libraries
    }

    public func reset() {
        authenticatedUser = nil
        libraries = []
        state = .authenticationRequired
    }

    /// `tryReloadState()` — best effort, 3s timeout, errors swallowed.
    public func tryReloadState(api: any KomgaApi) async {
        let result = try? await withTimeout(seconds: 3) {
            async let user = api.userApi.getMe()
            async let libraries = api.libraryApi.getLibraries()
            return try await (user, libraries)
        }
        if let (user, libraries) = result { setStateValues(user: user, libraries: libraries) }
    }
}

public struct TimeoutError: Error {}

public func withTimeout<T: Sendable>(seconds: Double, _ operation: @escaping @Sendable () async throws -> T)
    async throws -> T
{
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
