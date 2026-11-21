import AppKit

/// Clipboard access is always initiated by an explicit user action. NOTCHORA
/// never polls `NSPasteboard` in the background.
@MainActor
enum ClipboardService {
    static func readText() -> String? {
        let pasteboard = NSPasteboard.general
        guard let string = pasteboard.string(forType: .string) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func hasText() -> Bool {
        NSPasteboard.general.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.string.rawValue])
    }
}
