import Foundation
import Synchronization

/// Multi-subscriber fan-out (`MutableSharedFlow` without replay). Generic sibling of `KomgaEventBroadcaster`,
/// used for download events and task-queue wake-ups. Observer pattern.
public final class AsyncBroadcaster<Element: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Element>.Continuation]>([:])
    private let bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy

    public init(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingNewest(1024)) {
        self.bufferingPolicy = bufferingPolicy
    }

    public func emit(_ element: Element) {
        for continuation in continuations.withLock({ Array($0.values) }) { continuation.yield(element) }
    }

    public func subscribe() -> AsyncStream<Element> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
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
