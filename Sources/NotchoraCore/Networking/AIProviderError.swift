import Foundation

public enum AIProviderError: Error, LocalizedError, Sendable, Equatable {
    case missingAPIKey(AIProviderID)
    case invalidAPIKey(AIProviderID)
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int, message: String)
    case network(String)
    case timedOut
    case cancelled
    case decoding(String)
    case stream(String)
    case unsupportedContent(String)
    case emptyResponse
    case noAvailableModel

    public var errorDescription: String? {
        switch self {
        case let .missingAPIKey(provider):
            "Connect an API key for \(provider.displayName) in Settings → AI Providers."
        case let .invalidAPIKey(provider):
            "\(provider.displayName) rejected this API key. Check it in Settings → AI Providers."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                "The provider is rate limiting requests. Try again in \(Int(retryAfter.rounded(.up))) seconds."
            } else {
                "The provider is rate limiting requests. Try again shortly."
            }
        case let .http(status, message):
            message.isEmpty ? "The provider returned HTTP \(status)." : "The provider returned HTTP \(status): \(message)"
        case let .network(message):
            "Network error: \(message)"
        case .timedOut:
            "The request timed out. Check your connection and try again."
        case .cancelled:
            "Generation was cancelled."
        case let .decoding(message):
            "The provider returned an unreadable response: \(message)"
        case let .stream(message):
            message
        case let .unsupportedContent(message):
            message
        case .emptyResponse:
            "The model returned an empty response."
        case .noAvailableModel:
            "No model is selected. Refresh the model list in Settings → AI Providers."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            "Open Settings → AI Providers to manage credentials. Keys are stored in the macOS Keychain."
        case .rateLimited:
            "Wait briefly, or switch to another model or provider."
        case .timedOut, .network:
            "Verify your internet connection and try again."
        case .unsupportedContent:
            "Choose a model that supports image input, or remove the attachment."
        default:
            nil
        }
    }

    public var isRetryable: Bool {
        switch self {
        case let .http(status, _):
            status == 408 || status == 409 || status == 429 || (500...599).contains(status)
        case .network, .timedOut, .rateLimited:
            true
        default:
            false
        }
    }
}

enum ProviderErrorMapper {
    static func map(_ error: any Error, provider: AIProviderID) -> AIProviderError {
        if let providerError = error as? AIProviderError { return providerError }
        if error is CancellationError { return .cancelled }

        if let transportError = error as? HTTPTransportError {
            switch transportError {
            case let .invalidResponse(message):
                return .network(message)
            case let .http(status, body):
                let message = sanitized(body)
                if status == 401 || status == 403 {
                    return .invalidAPIKey(provider)
                }
                if status == 429 {
                    return .rateLimited(retryAfter: nil)
                }
                return .http(status: status, message: message)
            case .cancelled:
                return .cancelled
            case let .url(message):
                if message.localizedCaseInsensitiveContains("timed out") { return .timedOut }
                return .network(message)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return .timedOut
            case .cancelled: return .cancelled
            default: return .network(urlError.localizedDescription)
            }
        }

        return .network(error.localizedDescription)
    }

    static func sanitized(_ body: String) -> String {
        var text = body
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Avoid reflecting credentials even if a provider echoes request data.
        let patterns = [
            #"sk-[A-Za-z0-9_\-]{8,}"#,
            #"sk-ant-[A-Za-z0-9_\-]{8,}"#,
            #"AIza[A-Za-z0-9_\-]{20,}"#,
            #"Bearer\s+[A-Za-z0-9._\-]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "[redacted]")
            }
        }
        return String(text.prefix(420))
    }
}
