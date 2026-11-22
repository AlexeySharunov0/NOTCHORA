import Foundation

/// Stable identifier for every supported AI vendor.
///
/// The raw values are used for persistence and Keychain accounts. Never change
/// them after a release; add new cases instead.
public enum AIProviderID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case deepSeek = "deepseek"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google Gemini"
        case .deepSeek: "DeepSeek"
        }
    }

    public var shortName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Claude"
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        }
    }

    public var monogram: String {
        switch self {
        case .openAI: "O"
        case .anthropic: "A"
        case .gemini: "G"
        case .deepSeek: "D"
        }
    }

    public var keychainAccount: String { "api-key.\(rawValue)" }

    public var documentationURL: URL {
        switch self {
        case .openAI:
            URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic:
            URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini:
            URL(string: "https://aistudio.google.com/app/apikey")!
        case .deepSeek:
            URL(string: "https://platform.deepseek.com/api_keys")!
        }
    }

    public var keyHint: String {
        switch self {
        case .openAI: "sk-…"
        case .anthropic: "sk-ant-…"
        case .gemini: "AIza…"
        case .deepSeek: "sk-…"
        }
    }

    public var defaultModelID: String {
        switch self {
        case .openAI: "gpt-4.1"
        case .anthropic: "claude-sonnet-4-20250514"
        case .gemini: "gemini-2.5-pro"
        case .deepSeek: "deepseek-v4-pro"
        }
    }
}
