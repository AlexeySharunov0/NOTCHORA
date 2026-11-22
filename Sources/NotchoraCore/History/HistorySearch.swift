import Foundation

public struct HistoryFilter: Sendable {
    public var query: String
    public var providerID: AIProviderID?
    public var pinnedOnly: Bool
    public var includeArchived: Bool

    public init(
        query: String = "",
        providerID: AIProviderID? = nil,
        pinnedOnly: Bool = false,
        includeArchived: Bool = false
    ) {
        self.query = query
        self.providerID = providerID
        self.pinnedOnly = pinnedOnly
        self.includeArchived = includeArchived
    }
}

public struct HistoryHit: Identifiable, Sendable {
    public var id: UUID { conversation.id }
    public var conversation: Conversation
    public var excerpt: String?

    public init(conversation: Conversation, excerpt: String? = nil) {
        self.conversation = conversation
        self.excerpt = excerpt
    }
}

public enum HistorySearch {
    public static func hits(in conversations: [Conversation], filter: HistoryFilter) -> [HistoryHit] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)

        return conversations.compactMap { conversation -> HistoryHit? in
            if !filter.includeArchived && conversation.isArchived { return nil }
            if filter.pinnedOnly && !conversation.isPinned { return nil }
            if let provider = filter.providerID, conversation.providerID != provider { return nil }
            guard !query.isEmpty else {
                return HistoryHit(conversation: conversation)
            }
            guard conversation.searchableText.localizedCaseInsensitiveContains(query) else { return nil }
            let excerpt = conversation.messages.reversed().first {
                $0.content.localizedCaseInsensitiveContains(query)
            }.map { message -> String in
                let content = PlainText.preview(message.content, limit: 400)
                guard let range = content.range(of: query, options: .caseInsensitive) else {
                    return String(content.prefix(140))
                }
                let lower = content.index(range.lowerBound, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex
                let upper = content.index(range.upperBound, offsetBy: 90, limitedBy: content.endIndex) ?? content.endIndex
                return "…" + String(content[lower..<upper]) + "…"
            }
            return HistoryHit(conversation: conversation, excerpt: excerpt)
        }
        .sorted {
            if $0.conversation.isPinned != $1.conversation.isPinned {
                return $0.conversation.isPinned
            }
            return $0.conversation.updatedAt > $1.conversation.updatedAt
        }
    }
}
