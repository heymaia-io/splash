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

/// Without this, `error.localizedDescription` renders as "KomgaAPI.KomgaAPIError error 0" — Foundation's
/// fallback for a plain `Error` enum, naming the case *index*. These strings reach the user directly in
/// screen error views and action banners, so each case says what actually happened; an HTTP failure prefers
/// the server's own `message`, which is the only part that can explain a particular 4xx.
extension KomgaAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code, _):
            if let message = errorResponse?.message, !message.isEmpty { return message }
            switch code {
            case 401: return String(localized: "Your session has expired. Please sign in again.")
            case 403: return String(localized: "Your account is not allowed to do that.")
            case 404: return String(localized: "That content is no longer on the server.")
            case 500...599: return String(localized: "The server had a problem (error \(code)). Please try again.")
            default: return String(localized: "The server rejected the request (error \(code)).")
            }
        case .invalidResponse:
            return String(localized: "The server sent a response Splash could not read.")
        case .decoding(let detail):
            return String(localized: "The server sent unexpected data. (\(detail))")
        case .unsupported(let detail):
            return String(localized: "That is not available right now. (\(detail))")
        }
    }
}

extension Error {
    public var isKomgaNotFound: Bool { (self as? KomgaAPIError)?.isNotFound ?? false }
    public var isKomgaUnauthorized: Bool { (self as? KomgaAPIError)?.isUnauthorized ?? false }

    /// "The server could not be reached" — no network, or a self-hosted Komga that is down, behind a VPN
    /// that is off, or simply not on this network. The UI treats all of these the same: fall back to what
    /// is stored locally. Deliberately broader than a connectivity check on the device, because with a
    /// self-hosted server "online but cannot reach it" is at least as common as "no connection".
    public var isServerUnreachable: Bool {
        guard let error = self as? URLError else { return false }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
             .timedOut, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
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
