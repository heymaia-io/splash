import Foundation
import Observation
import Synchronization

/// Load/save of a whole settings row — implemented by KomeliaDB (GRDB), or in memory for tests/previews.
public protocol SettingsStore<Value>: Sendable {
    associatedtype Value: Sendable
    func load() async throws -> Value?
    func save(_ value: Value) async throws
}

/// Port of `SettingsStateWrapper<T>`: in-memory state + write-through persistence + change stream.
/// Repositories (`CommonSettingsRepository`, `ImageReaderSettingsRepository`, …) are thin projections of it,
/// exactly like the Kotlin `*RepositoryWrapper` classes.
public final class SettingsState<Value: Equatable & Sendable>: Sendable {
    private let state: Mutex<Value>
    private let saveValue: @Sendable (Value) async throws -> Void
    private let broadcaster = ValueBroadcaster<Value>()
    private let writeLock = AsyncSerialLock()

    public init(initial: Value, save: @escaping @Sendable (Value) async throws -> Void) {
        state = Mutex(initial)
        saveValue = save
    }

    /// Loads the persisted value or falls back to (and persists) `defaultValue`.
    public static func load<S: SettingsStore>(from store: S, default defaultValue: Value) async throws
        -> SettingsState<Value> where S.Value == Value
    {
        let initial: Value
        if let stored = try await store.load() {
            initial = stored
        } else {
            initial = defaultValue
            try await store.save(defaultValue)
        }
        return SettingsState(initial: initial) { try await store.save($0) }
    }

    public var value: Value { state.withLock { $0 } }

    /// Current value first, then every change (`StateFlow` semantics, deduplicated).
    public func values() -> AsyncStream<Value> {
        broadcaster.subscribe(initial: value)
    }

    /// Projection with `distinctUntilChanged` (`wrapper.state.map { ... }.distinctUntilChanged()`).
    public func values<T: Equatable & Sendable>(_ keyPath: KeyPath<Value, T> & Sendable) -> AsyncStream<T> {
        let upstream = values()
        return AsyncStream { continuation in
            let task = Task {
                var last: T?
                for await value in upstream {
                    let projected = value[keyPath: keyPath]
                    if projected != last {
                        last = projected
                        continuation.yield(projected)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `transform { it.copy(...) }` — persists first, then publishes (same order as Kotlin).
    public func update(_ transform: @escaping @Sendable (inout Value) -> Void) async throws {
        try await writeLock.run {
            var next = self.value
            transform(&next)
            guard next != self.value else { return }
            try await self.saveValue(next)
            self.state.withLock { $0 = next }
            self.broadcaster.emit(next)
        }
    }

    public func set<T: Sendable>(_ keyPath: WritableKeyPath<Value, T> & Sendable, _ newValue: T) async throws {
        try await update { $0[keyPath: keyPath] = newValue }
    }
}

/// Multi-subscriber value fan-out (MutableStateFlow observers).
final class ValueBroadcaster<Value: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Value>.Continuation]>([:])

    func subscribe(initial: Value) -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        continuation.yield(initial)
        continuation.onTermination = { [weak self] _ in
            _ = self?.continuations.withLock { $0.removeValue(forKey: id) }
        }
        continuations.withLock { $0[id] = continuation }
        return stream
    }

    func emit(_ value: Value) {
        for continuation in continuations.withLock({ Array($0.values) }) { continuation.yield(value) }
    }
}

/// Serializes async critical sections (writes must not interleave across suspension points).
public actor AsyncSerialLock {
    private var tail: Task<Void, Never>?

    public init() {}

    public func run<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task<T, Error> {
            await previous?.value
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}

/// In-memory store for previews and tests.
public actor InMemorySettingsStore<Value: Sendable>: SettingsStore {
    private var stored: Value?
    public init(_ value: Value? = nil) { stored = value }
    public func load() async throws -> Value? { stored }
    public func save(_ value: Value) async throws { stored = value }
}
