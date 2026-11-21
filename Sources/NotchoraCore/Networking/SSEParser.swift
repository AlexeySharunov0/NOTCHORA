import Foundation

public struct SSEEvent: Hashable, Sendable {
    public var event: String?
    public var data: String

    public init(event: String? = nil, data: String) {
        self.event = event
        self.data = data
    }
}

/// Incremental parser for the `text/event-stream` framing used by all three
/// providers. It intentionally knows nothing about provider JSON.
public struct SSEParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    public init() {}

    public mutating func consume(line rawLine: String) -> SSEEvent? {
        var line = rawLine
        if line.hasSuffix("\r") { line.removeLast() }
        if line.isEmpty {
            return dispatch()
        }
        if line.hasPrefix(":") {
            return nil
        }

        let field: String
        var value: String
        if let separator = line.firstIndex(of: ":") {
            field = String(line[..<separator])
            value = String(line[line.index(after: separator)...])
            if value.hasPrefix(" ") { value.removeFirst() }
        } else {
            field = line
            value = ""
        }

        switch field {
        case "event":
            eventName = value
        case "data":
            dataLines.append(value)
        default:
            break
        }
        return nil
    }

    public mutating func flush() -> SSEEvent? {
        if dataLines.isEmpty && eventName == nil { return nil }
        return dispatch()
    }

    private mutating func dispatch() -> SSEEvent? {
        guard !dataLines.isEmpty || eventName != nil else { return nil }
        let event = SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
        eventName = nil
        dataLines.removeAll(keepingCapacity: true)
        return event
    }
}
