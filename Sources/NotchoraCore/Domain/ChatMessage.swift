import Foundation

public struct ChatAttachment: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case image
        case screenCapture
        case text
    }

    public let id: UUID
    public let kind: Kind
    public let name: String
    public let mimeType: String
    public let data: Data
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        name: String,
        mimeType: String,
        data: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.mimeType = mimeType
        self.data = data
        self.createdAt = createdAt
    }

    public var isImage: Bool { kind == .image || kind == .screenCapture }

    public var text: String? {
        guard kind == .text else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public var byteCount: Int { data.count }
}

public enum ChatRole: String, Codable, Hashable, Sendable {
    case user
    case assistant
}

public enum MessageStatus: String, Codable, Hashable, Sendable {
    case streaming
    case complete
    case failed
    case cancelled
}

public struct TokenUsage: Codable, Hashable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int? {
        switch (inputTokens, outputTokens) {
        case let (input?, output?): input + output
        case let (input?, nil): input
        case let (nil, output?): output
        default: nil
        }
    }
}

public struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public var content: String
    public let createdAt: Date
    public var providerID: AIProviderID?
    public var modelID: String?
    public var status: MessageStatus
    public var usage: TokenUsage?
    public var attachments: [ChatAttachment]
    public var errorDescription: String?
    public var duration: TimeInterval?

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: Date = Date(),
        providerID: AIProviderID? = nil,
        modelID: String? = nil,
        status: MessageStatus = .complete,
        usage: TokenUsage? = nil,
        attachments: [ChatAttachment] = [],
        errorDescription: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerID = providerID
        self.modelID = modelID
        self.status = status
        self.usage = usage
        self.attachments = attachments
        self.errorDescription = errorDescription
        self.duration = duration
    }

    public var isStreaming: Bool { status == .streaming }
    public var isEmptyAssistantPlaceholder: Bool {
        role == .assistant && content.isEmpty && status == .streaming
    }
}

public struct AIWireMessage: Hashable, Sendable {
    public enum Role: String, Hashable, Sendable {
        case user
        case assistant
    }

    public struct Image: Hashable, Sendable {
        public let mimeType: String
        public let data: Data

        public init(mimeType: String, data: Data) {
            self.mimeType = mimeType
            self.data = data
        }
    }

    public var role: Role
    public var text: String
    public var images: [Image]

    public init(role: Role, text: String, images: [Image] = []) {
        self.role = role
        self.text = text
        self.images = images
    }

    public init(message: ChatMessage, includeAttachments: Bool = true) {
        self.role = message.role == .user ? .user : .assistant
        var text = message.content
        if includeAttachments {
            for attachment in message.attachments where attachment.kind == .text {
                if let body = attachment.text, !body.isEmpty {
                    text += "\n\n<attachment name=\"\(attachment.name)\">\n\(body)\n</attachment>"
                }
            }
        }
        self.text = text
        self.images = includeAttachments
            ? message.attachments.filter(\.isImage).map {
                Image(mimeType: $0.mimeType, data: $0.data)
            }
            : []
    }
}

public struct AIRequest: Hashable, Sendable {
    public var model: AIModel
    public var messages: [AIWireMessage]
    public var systemPrompt: String?
    public var temperature: Double?
    public var maxOutputTokens: Int?

    public init(
        model: AIModel,
        messages: [AIWireMessage],
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

public enum AIStreamEvent: Hashable, Sendable {
    case started
    case textDelta(String)
    case usage(TokenUsage)
    case completed
}
