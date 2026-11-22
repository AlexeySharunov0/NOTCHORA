import AppKit
import ApplicationServices

struct SelectedTextResult: Sendable {
    var text: String
    var applicationName: String?
}

enum SelectedTextError: Error, LocalizedError, Sendable {
    case accessibilityDenied
    case noFocusedElement
    case noSelection
    case unsupportedElement
    case axFailure(Int32)

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "Accessibility access is required to read selected text."
        case .noFocusedElement:
            "The frontmost app did not expose a focused text area."
        case .noSelection:
            "No text is selected."
        case .unsupportedElement:
            "The frontmost app does not expose its selection through the Accessibility API."
        case let .axFailure(code):
            "The Accessibility API returned error \(code)."
        }
    }
}

@MainActor
struct SelectedTextService {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func readSelectedText() throws -> SelectedTextResult {
        guard isTrusted else { throw SelectedTextError.accessibilityDenied }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedStatus == .success, let focusedRef else {
            throw SelectedTextError.noFocusedElement
        }
        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            throw SelectedTextError.noFocusedElement
        }
        let element = focusedRef as! AXUIElement

        var selectedRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        )
        if status == .attributeUnsupported || status == .noValue {
            throw SelectedTextError.unsupportedElement
        }
        guard status == .success else {
            throw SelectedTextError.axFailure(status.rawValue)
        }
        guard let text = selectedRef as? String else {
            throw SelectedTextError.unsupportedElement
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SelectedTextError.noSelection }
        return SelectedTextResult(text: trimmed, applicationName: frontmost?.localizedName)
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
