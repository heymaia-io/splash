import Foundation

/// One dispatched SSE message.
public struct ServerSentEvent: Hashable, Sendable {
    public var event: String?
    public var data: String?
    public var id: String?
}

/// Incremental parser for `text/event-stream` (WHATWG spec subset used by Komga).
/// Byte-oriented on purpose: `AsyncBytes.lines` drops the blank lines that delimit events.
public struct ServerSentEventParser: Sendable {
    private var lineBuffer: [UInt8] = []
    private var lastByteWasCR = false
    private var eventType: String?
    private var dataLines: [String] = []
    private var lastEventId: String?

    public init() {}

    /// Feeds one byte; returns an event when a blank line completes one.
    public mutating func consume(_ byte: UInt8) -> ServerSentEvent? {
        switch byte {
        case UInt8(ascii: "\n"):
            if lastByteWasCR {  // second half of CRLF, line already processed
                lastByteWasCR = false
                return nil
            }
            return finishLine()
        case UInt8(ascii: "\r"):
            lastByteWasCR = true
            return finishLine()
        default:
            lastByteWasCR = false
            lineBuffer.append(byte)
            return nil
        }
    }

    public mutating func consume<S: Sequence>(_ bytes: S) -> [ServerSentEvent] where S.Element == UInt8 {
        bytes.compactMap { consume($0) }
    }

    private mutating func finishLine() -> ServerSentEvent? {
        let line = String(decoding: lineBuffer, as: UTF8.self)
        lineBuffer.removeAll(keepingCapacity: true)
        if line.isEmpty { return dispatch() }
        if line.hasPrefix(":") { return nil }  // comment / heartbeat

        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }

        switch field {
        case "event": eventType = String(value)
        case "data": dataLines.append(String(value))
        case "id": lastEventId = String(value)
        default: break  // `retry` and unknown fields are ignored; reconnection delay is fixed (10s)
        }
        return nil
    }

    private mutating func dispatch() -> ServerSentEvent? {
        defer {
            eventType = nil
            dataLines.removeAll()
        }
        guard !dataLines.isEmpty || eventType != nil else { return nil }
        return ServerSentEvent(
            event: eventType,
            data: dataLines.isEmpty ? nil : dataLines.joined(separator: "\n"),
            id: lastEventId)
    }
}
