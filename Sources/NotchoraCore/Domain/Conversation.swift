import Foundation

public struct Conversation: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var providerID: AIProviderID
    public var modelID: String
    public var systemPrompt: String
    public var messages: [ChatMessage]
    public var isPinned: Bool
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerID: AIProviderID,
        modelID: String,
        systemPrompt: String = "",
        messages: [ChatMessage] = [],
        isPinned: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerID = providerID
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.isPinned = isPinned
        self.isArchived = isArchived
    }

    public var selection: ModelSelection {
        get { ModelSelection(providerID: providerID, modelID: modelID) }
        set {
            providerID = newValue.providerID
            modelID = newValue.modelID
        }
    }

    public var lastMessage: ChatMessage? { messages.last }

    public var preview: String {
        PlainText.preview(lastMessage?.content ?? "", limit: 120)
    }

    public var searchableText: String {
        ([title, systemPrompt] + messages.flatMap { [$0.content, $0.attachments.map(\.name).joined(separator: " ")] })
            .joined(separator: "\n")
    }

    public mutating func applyTitleIfNeeded(fromUserText text: String) {
        guard title == "New Chat" || title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return }
        title = String(collapsed.prefix(52))
    }

    public mutating func touch() {
        updatedAt = Date()
    }
}

public enum ConversationSort {
    public static func mostRecent(_ conversations: [Conversation]) -> [Conversation] {
        conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }
}
