import Foundation

public struct ChatGenerationOptions: Hashable, Sendable {
    public var systemPrompt: String
    public var temperature: Double?
    public var maxOutputTokens: Int?

    public init(systemPrompt: String = "", temperature: Double? = nil, maxOutputTokens: Int? = nil) {
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

public enum ChatRequestBuilder {
    public static func request(
        messages: [ChatMessage],
        model: AIModel,
        options: ChatGenerationOptions
    ) throws -> AIRequest {
        let usable = messages.filter { message in
            !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !message.attachments.isEmpty
        }
        guard !usable.isEmpty else { throw AIProviderError.emptyResponse }

        let imageCount = usable.reduce(0) { partial, message in
            partial + (message.role == .user ? message.attachments.filter(\.isImage).count : 0)
        }
        if imageCount > 0 && !model.supportsVision {
            throw AIProviderError.unsupportedContent(
                "\(model.displayName) is not marked as supporting image input. Remove the image or choose a vision-capable model."
            )
        }

        var wireMessages = usable.map { message in
            AIWireMessage(
                message: message,
                includeAttachments: message.role == .user
            )
        }

        // Providers differ in how strictly they enforce alternation. Merging
        // adjacent turns is lossless for context and avoids unnecessary 400s
        // after a failed or cancelled assistant turn.
        var merged: [AIWireMessage] = []
        for message in wireMessages {
            if var last = merged.last, last.role == message.role {
                merged.removeLast()
                if !last.text.isEmpty && !message.text.isEmpty {
                    last.text += "\n\n"
                }
                last.text += message.text
                last.images.append(contentsOf: message.images)
                merged.append(last)
            } else {
                merged.append(message)
            }
        }
        wireMessages = merged

        if wireMessages.first?.role == .assistant {
            wireMessages.insert(
                AIWireMessage(role: .user, text: "Continue the following conversation."),
                at: 0
            )
        }

        return AIRequest(
            model: model,
            messages: wireMessages,
            systemPrompt: options.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            temperature: options.temperature,
            maxOutputTokens: options.maxOutputTokens
        )
    }

    public static func request(
        conversation: Conversation,
        model: AIModel,
        options: ChatGenerationOptions
    ) throws -> AIRequest {
        try request(messages: conversation.messages, model: model, options: options)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public enum ChatTitle {
    public static func from(_ text: String, fallback: String = "New Chat") -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return fallback }
        return String(collapsed.prefix(52))
    }
}
