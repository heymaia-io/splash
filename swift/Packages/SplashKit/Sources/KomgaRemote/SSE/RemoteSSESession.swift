import Foundation
import KomgaAPI

/// Port of `RemoteApi.CombinedSSESession`: server events from `sse/v1/events` (reconnecting every 10s,
/// like ktor's `SSE { reconnectionTime = 10.seconds }`) merged with locally emitted offline events.
/// App lifecycle pausing (background/foreground) is layered on top in Phase 7.
public final class RemoteSSESession: KomgaSSESession {
    public static let reconnectionDelay: Duration = .seconds(10)

    public let incoming: AsyncStream<KomgaEvent>
    private let tasks: [Task<Void, Never>]

    init(http: KomgaHTTPClient, offlineEvents: KomgaEventBroadcaster?, reconnectionDelay: Duration = reconnectionDelay) {
        let (stream, continuation) = AsyncStream.makeStream(of: KomgaEvent.self, bufferingPolicy: .bufferingNewest(256))
        incoming = stream

        let serverTask = Task {
            let decoder = KomgaJSON.makeDecoder()
            while !Task.isCancelled {
                do {
                    var request = http.request(.get, "sse/v1/events", headers: ["Accept": "text/event-stream"])
                    request.timeoutInterval = 24 * 3600  // idle timeout; the stream is long-lived
                    let (bytes, _) = try await http.bytes(for: request)
                    var parser = ServerSentEventParser()
                    for try await byte in bytes {
                        if let message = parser.consume(byte) {
                            continuation.yield(KomgaEvent.decode(event: message.event, data: message.data, decoder: decoder))
                        }
                    }
                } catch is CancellationError {
                    break
                } catch {
                    // Connection refused / dropped / 401: retry after the fixed delay (Kotlin logs and retries).
                }
                try? await Task.sleep(for: reconnectionDelay)
            }
        }

        var tasks = [serverTask]
        if let offlineEvents {
            let events = offlineEvents.subscribe()
            tasks.append(Task {
                for await event in events { continuation.yield(event) }
            })
        }
        self.tasks = tasks
        continuation.onTermination = { [tasks] _ in tasks.forEach { $0.cancel() } }
    }

    public func cancel() {
        tasks.forEach { $0.cancel() }
    }

    deinit { cancel() }
}
