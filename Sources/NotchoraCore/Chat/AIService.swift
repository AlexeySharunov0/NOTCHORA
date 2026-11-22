import Foundation

public struct CompletionResult: Sendable, Hashable {
    public var text: String
    public var usage: TokenUsage?
    public var duration: TimeInterval

    public init(text: String, usage: TokenUsage? = nil, duration: TimeInterval = 0) {
        self.text = text
        self.usage = usage
        self.duration = duration
    }
}

public protocol AIServicing: Sendable {
    func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error>
    func complete(_ request: AIRequest) async throws -> CompletionResult
    func validateKey(_ key: String, for provider: AIProviderID) async throws
    func listModels(for provider: AIProviderID, apiKey: String) async throws -> [AIModel]
    func listModels(for provider: AIProviderID) async throws -> [AIModel]
}

public struct AIService: AIServicing, Sendable {
    public let registry: ProviderRegistry
    public let keyStore: any APIKeyStore

    public init(registry: ProviderRegistry, keyStore: any APIKeyStore) {
        self.registry = registry
        self.keyStore = keyStore
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let key: String?
        do {
            key = try keyStore.load(for: request.model.providerID)
        } catch {
            throw AIProviderError.network("The macOS Keychain could not be read. \(error.localizedDescription)")
        }
        guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingAPIKey(request.model.providerID)
        }
        let provider = registry.provider(for: request.model.providerID)
        return try await provider.stream(request: request, apiKey: key)
    }

    public func complete(_ request: AIRequest) async throws -> CompletionResult {
        let start = ContinuousClock.now
        let stream = try await stream(request)
        var text = ""
        var usage: TokenUsage?

        for try await event in stream {
            try Task.checkCancellation()
            switch event {
            case .started, .completed:
                break
            case let .textDelta(delta):
                text += delta
            case let .usage(value):
                usage = value
            }
        }
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIProviderError.emptyResponse }
        return CompletionResult(text: trimmed, usage: usage, duration: seconds)
    }

    public func validateKey(_ key: String, for provider: AIProviderID) async throws {
        do {
            try await registry.provider(for: provider).validateKey(key)
        } catch {
            throw ProviderErrorMapper.map(error, provider: provider)
        }
    }

    public func listModels(for provider: AIProviderID, apiKey: String) async throws -> [AIModel] {
        do {
            return try await registry.provider(for: provider).listModels(apiKey: apiKey)
        } catch {
            throw ProviderErrorMapper.map(error, provider: provider)
        }
    }

    public func listModels(for provider: AIProviderID) async throws -> [AIModel] {
        let key: String?
        do {
            key = try keyStore.load(for: provider)
        } catch {
            throw AIProviderError.network("The macOS Keychain could not be read. \(error.localizedDescription)")
        }
        guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingAPIKey(provider)
        }
        return try await listModels(for: provider, apiKey: key)
    }

    public func hasKey(for provider: AIProviderID) -> Bool {
        keyStore.hasKey(for: provider)
    }
}
