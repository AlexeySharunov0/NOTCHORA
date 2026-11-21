import Foundation

public enum AIModelSource: String, Codable, Hashable, Sendable {
    /// Curated model IDs shipped with NOTCHORA.
    case builtIn
    /// Discovered from the provider's model listing endpoint.
    case discovered
    /// Added by the user in Settings.
    case custom
}

/// A model the app can address. The `id` is the exact identifier sent to the
/// vendor API; display metadata is deliberately separated from transport.
public struct AIModel: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let providerID: AIProviderID
    public let displayName: String
    public let contextWindow: Int?
    public let supportsVision: Bool
    public let source: AIModelSource

    public init(
        id: String,
        providerID: AIProviderID,
        displayName: String? = nil,
        contextWindow: Int? = nil,
        supportsVision: Bool = false,
        source: AIModelSource = .builtIn
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName ?? id
        self.contextWindow = contextWindow
        self.supportsVision = supportsVision
        self.source = source
    }

    public var qualifiedID: String { "\(providerID.rawValue)/\(id)" }
}

public struct ModelSelection: Codable, Hashable, Sendable, Identifiable {
    public var providerID: AIProviderID
    public var modelID: String

    public init(providerID: AIProviderID, modelID: String) {
        self.providerID = providerID
        self.modelID = modelID
    }

    public var id: String { "\(providerID.rawValue)/\(modelID)" }
}

public enum ModelCatalogDefaults {
    public static func models(for provider: AIProviderID) -> [AIModel] {
        switch provider {
        case .openAI:
            [
                AIModel(id: "gpt-4.1", providerID: .openAI, displayName: "GPT-4.1", contextWindow: 1_047_576, supportsVision: true),
                AIModel(id: "gpt-4.1-mini", providerID: .openAI, displayName: "GPT-4.1 mini", contextWindow: 1_047_576, supportsVision: true),
                AIModel(id: "gpt-4o", providerID: .openAI, displayName: "GPT-4o", contextWindow: 128_000, supportsVision: true),
                AIModel(id: "o3", providerID: .openAI, displayName: "o3", contextWindow: 200_000, supportsVision: true)
            ]
        case .anthropic:
            [
                AIModel(id: "claude-sonnet-4-20250514", providerID: .anthropic, displayName: "Claude Sonnet 4", contextWindow: 200_000, supportsVision: true),
                AIModel(id: "claude-3-7-sonnet-latest", providerID: .anthropic, displayName: "Claude 3.7 Sonnet", contextWindow: 200_000, supportsVision: true),
                AIModel(id: "claude-3-5-haiku-latest", providerID: .anthropic, displayName: "Claude 3.5 Haiku", contextWindow: 200_000, supportsVision: true)
            ]
        case .gemini:
            [
                AIModel(id: "gemini-2.5-pro", providerID: .gemini, displayName: "Gemini 2.5 Pro", contextWindow: 1_048_576, supportsVision: true),
                AIModel(id: "gemini-2.5-flash", providerID: .gemini, displayName: "Gemini 2.5 Flash", contextWindow: 1_048_576, supportsVision: true)
            ]
        }
    }

    public static func defaultModel(for provider: AIProviderID) -> AIModel {
        models(for: provider).first
            ?? AIModel(id: provider.defaultModelID, providerID: provider)
    }
}
