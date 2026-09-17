import Foundation
import Synchronization

/// Errors surfaced by any `KomgaApi` implementation. UI code matches on these, never on transport types.
public enum KomgaAPIError: Error, Sendable, Equatable {
    /// Non-2xx HTTP status (ktor `expectSuccess = true` -> `ResponseException`).
    case httpStatus(code: Int, body: Data)
    case invalidResponse
    case decoding(String)
    /// Operation not available in the current mode (e.g. admin ops while offline).
    case unsupported(String)

    public var statusCode: Int? {
        if case .httpStatus(let code, _) = self { return code }
        return nil
    }

    public var isNotFound: Bool { statusCode == 404 }
    public var isUnauthorized: Bool { statusCode == 401 }

    /// `ResponseException.toErrorResponse()`
    public var errorResponse: KomgaErrorResponse? {
        guard case .httpStatus(_, let body) = self else { return nil }
        return try? KomgaJSON.makeDecoder().decode(KomgaErrorResponse.self, from: body)
    }
}

extension Error {
    public var isKomgaNotFound: Bool { (self as? KomgaAPIError)?.isNotFound ?? false }
    public var isKomgaUnauthorized: Bool { (self as? KomgaAPIError)?.isUnauthorized ?? false }
}

/// Offline bookkeeping merged into remote books (`OfflineBookRepository.find/findIn` in RemoteBookApi.kt).
/// Declared here (dependency inversion) so the remote module does not depend on the offline module.
public struct OfflineBookState: Hashable, Sendable {
    public var localFileLastModified: Date?
    public var remoteUnavailable: Bool

    public init(localFileLastModified: Date?, remoteUnavailable: Bool) {
        self.localFileLastModified = localFileLastModified
        self.remoteUnavailable = remoteUnavailable
    }
}

public protocol OfflineBookStateProvider: Sendable {
    func offlineStates(for bookIds: [KomgaBookId]) async throws -> [KomgaBookId: OfflineBookState]
}

extension SplashBook {
    public init(book: KomgaBook, offlineState: OfflineBookState?) {
        self.init(
            book: book,
            downloaded: offlineState != nil,
            localFileLastModified: offlineState?.localFileLastModified,
            remoteFileUnavailable: offlineState?.remoteUnavailable ?? false)
    }
}

/// Multi-subscriber event fan-out — the Swift stand-in for Kotlin's `MutableSharedFlow<KomgaEvent>`
/// (AsyncStream alone is single-consumer). Observer pattern.
public final class KomgaEventBroadcaster: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<KomgaEvent>.Continuation]>([:])

    public init() {}

    public func emit(_ event: KomgaEvent) {
        let targets = continuations.withLock { Array($0.values) }
        for continuation in targets { continuation.yield(event) }
    }

    public func subscribe(bufferingPolicy: AsyncStream<KomgaEvent>.Continuation.BufferingPolicy = .bufferingNewest(64))
        -> AsyncStream<KomgaEvent>
    {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: KomgaEvent.self, bufferingPolicy: bufferingPolicy)
        continuation.onTermination = { [weak self] _ in
            _ = self?.continuations.withLock { $0.removeValue(forKey: id) }
        }
        continuations.withLock { $0[id] = continuation }
        return stream
    }

    public func finishAll() {
        let targets = continuations.withLock { dict in
            defer { dict.removeAll() }
            return Array(dict.values)
        }
        for continuation in targets { continuation.finish() }
    }
}
