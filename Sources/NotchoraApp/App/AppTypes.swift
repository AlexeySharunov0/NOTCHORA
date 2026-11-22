import Foundation
import NotchoraCore
import SwiftUI

enum PanelPresentation: String, CaseIterable, Hashable, Sendable {
    case hidden
    case compact
    case expanded
    case workspace
}

enum AppRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case chat
    case history
    case tasks
    case apps
    case workflows
    case multiAI
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .history: "History"
        case .tasks: "Tasks"
        case .apps: "Apps"
        case .workflows: "Workflows"
        case .multiAI: "Multi-AI"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .history: "clock.arrow.circlepath"
        case .tasks: "checklist"
        case .apps: "square.grid.2x2"
        case .workflows: "point.3.connected.trianglepath.dotted"
        case .multiAI: "square.split.2x2"
        case .settings: "gearshape"
        }
    }
}

struct ToastMessage: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case info
        case success
        case warning
        case error
    }

    var id = UUID()
    var kind: Kind
    var title: String
    var detail: String?
    var actionTitle: String?
    var action: (@MainActor @Sendable () -> Void)?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }

    static func info(_ title: String, detail: String? = nil) -> ToastMessage {
        ToastMessage(kind: .info, title: title, detail: detail)
    }

    static func success(_ title: String, detail: String? = nil) -> ToastMessage {
        ToastMessage(kind: .success, title: title, detail: detail)
    }

    static func warning(_ title: String, detail: String? = nil) -> ToastMessage {
        ToastMessage(kind: .warning, title: title, detail: detail)
    }

    static func error(_ title: String, detail: String? = nil) -> ToastMessage {
        ToastMessage(kind: .error, title: title, detail: detail)
    }
}

enum ContextSource: String, Hashable, Sendable {
    case selectedText
    case clipboard
    case screenshot
    case manual
}


enum SelectionAction: String, CaseIterable, Identifiable, Sendable {
    case explain
    case summarize
    case translate
    case improve
    case rewrite
    case ask
    case reply

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explain: "Explain"
        case .summarize: "Summarize"
        case .translate: "Translate"
        case .improve: "Improve"
        case .rewrite: "Rewrite"
        case .ask: "Ask AI"
        case .reply: "Generate Reply"
        }
    }

    var symbolName: String {
        switch self {
        case .explain: "lightbulb"
        case .summarize: "text.append"
        case .translate: "character.book.closed"
        case .improve: "wand.and.stars"
        case .rewrite: "arrow.triangle.2.circlepath"
        case .ask: "questionmark.bubble"
        case .reply: "arrowshape.turn.up.left"
        }
    }

    var instruction: String? {
        switch self {
        case .explain:
            return "Explain the selected text clearly. Define unfamiliar terms and preserve technical accuracy."
        case .summarize:
            return "Summarize the selected text. Keep the essential meaning, decisions, and numbers. Be concise."
        case .translate:
            return "Translate the selected text into the language most useful to me. If the text is already in Russian, translate to English; otherwise translate to Russian. Preserve tone and formatting."
        case .improve:
            return "Improve the selected text. Make it clearer, tighter, and more natural without changing its meaning or voice. Return the improved text, then a short list of what changed."
        case .rewrite:
            return "Rewrite the selected text in a fresh, natural voice while preserving its meaning. Return the rewrite only."
        case .ask:
            return nil
        case .reply:
            return "Write a reply to the selected message. Match the relationship and tone, keep it concise, and do not add commitments that are not clearly supported."
        }
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum SettingsTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case general
    case providers
    case shortcuts
    case appearance
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "AI Providers"
        case .shortcuts: "Shortcuts"
        case .appearance: "Appearance"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .providers: "point.3.filled.connected.trianglepath.dotted"
        case .shortcuts: "command"
        case .appearance: "circle.lefthalf.filled"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}

struct ContextDraft: Identifiable, Sendable {
    var id = UUID()
    var source: ContextSource
    var title: String
    var text: String
    var attachment: ChatAttachment?
    var sourceApplication: String?

    var summary: String {
        if let attachment {
            return "\(attachment.kind == .text ? "Text" : "Image") · \(attachment.name)"
        }
        return text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SelectionFailure: Identifiable, Sendable {
    enum Reason: String, Sendable {
        case accessibilityDenied
        case noSelection
        case unavailable
    }

    var id = UUID()
    var reason: Reason
    var title: String
    var message: String
    var sourceApplication: String?

    var canRequestAccessibility: Bool { reason == .accessibilityDenied }
}

struct SelectedTextOffer: Identifiable, Sendable {
    var id = UUID()
    var text: String
    var sourceApplication: String?
    var isEditable: Bool
}

struct MultiAIModelState: Identifiable, Sendable {
    var id = UUID()
    var selection: ModelSelection
    var model: AIModel
    var text = ""
    var status: MultiAIStatus = .idle
    var errorDescription: String?
    var usage: TokenUsage?
    var taskID: UUID?

    var isRunning: Bool { status == .streaming || status == .waiting }
}

enum ScreenCaptureMode: String, CaseIterable, Hashable, Identifiable, Sendable {
    case fullScreen
    case currentWindow
    case selectedArea

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen: "Full Screen"
        case .currentWindow: "Current Window"
        case .selectedArea: "Selected Area"
        }
    }

    var symbolName: String {
        switch self {
        case .fullScreen: "display"
        case .currentWindow: "macwindow"
        case .selectedArea: "rectangle.dashed"
        }
    }

    var detail: String {
        switch self {
        case .fullScreen: "Share the entire active display."
        case .currentWindow: "Share the frontmost app window."
        case .selectedArea: "Drag a rectangle over the content to share."
        }
    }
}

enum MultiAIStatus: String, Hashable, Sendable {
    case idle
    case waiting
    case streaming
    case completed
    case failed
    case cancelled

    var label: String {
        switch self {
        case .idle: "Ready"
        case .waiting: "Connecting"
        case .streaming: "Generating"
        case .completed: "Complete"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}

struct ComparisonState: Identifiable, Sendable {
    var id = UUID()
    var selection: ModelSelection
    var text = ""
    var status: MultiAIStatus = .idle
    var errorDescription: String?
    var taskID: UUID?
}

struct MultiAISession: Identifiable, Sendable {
    var id = UUID()
    var prompt: String
    var createdAt = Date()
    var models: [MultiAIModelState]
    var comparison: ComparisonState?
    var savedConversationID: UUID?

    var completedModels: [MultiAIModelState] {
        models.filter { $0.status == .completed && !$0.text.isEmpty }
    }

    var isRunning: Bool {
        models.contains(where: \.isRunning) || comparison?.status == .streaming
    }
}

struct WorkflowRunDisplay: Identifiable, Sendable {
    var id = UUID()
    var workflowID: UUID
    var workflowName: String
    var input: String
    var currentStep: String
    var completedSteps: [WorkflowStepResult]
    var status: MultiAIStatus
    var taskID: UUID?
    var errorDescription: String?
}
