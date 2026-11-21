import Foundation

/// Keeps token streaming responsive without re-rendering the full Markdown
/// document on every network chunk.
struct RenderThrottle {
    private var lastRender = Date.distantPast
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.045) {
        self.interval = interval
    }

    mutating func shouldRender(force: Bool = false) -> Bool {
        let now = Date()
        guard force || now.timeIntervalSince(lastRender) >= interval else { return false }
        lastRender = now
        return true
    }
}
