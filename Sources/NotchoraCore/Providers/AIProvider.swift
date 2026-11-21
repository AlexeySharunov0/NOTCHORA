import Foundation

public struct ProviderCapabilities: Hashable, Sendable {
    public var supportsStreaming: Bool
    public var supportsVision: Bool
    public var supportsModelListing: Bool

    public init(supportsStreaming: Bool = true, supportsVision: Bool = true, supportsModelListing: Bool = true) {
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsModelListing = supportsModelListing
    }
}

public protocol AIProvider: Sendable {
    var id: AIProviderID { get }
    var capabilities: ProviderCapabilities { get }
    func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error>
    func validateKey(_ apiKey: String) async throws
    func listModels(apiKey: String) async throws -> [AIModel]
}

public struct ProviderRegistry: Sendable {
    private let providers: [AIProviderID: any AIProvider]

    public init(providers: [any AIProvider]) {
        var map: [AIProviderID: any AIProvider] = [:]
        for provider in providers {
            map[provider.id] = provider
        }
        self.providers = map
    }

    public init(transport: any HTTPTransport = URLSessionTransport(), retryPolicy: RetryPolicy = RetryPolicy()) {
        self.init(providers: [
            OpenAIProvider(transport: transport, retryPolicy: retryPolicy),
            AnthropicProvider(transport: transport, retryPolicy: retryPolicy),
            GeminiProvider(transport: transport, retryPolicy: retryPolicy)
        ])
    }

    public func provider(for id: AIProviderID) -> any AIProvider {
        guard let provider = providers[id] else {
            preconditionFailure("No provider registered for \(id.rawValue)")
        }
        return provider
    }

    public var allProviders: [any AIProvider] {
        AIProviderID.allCases.compactMap { providers[$0] }
    }
}

enum ProviderStreamSupport {
    static func makeStream(
        providerID: AIProviderID,
        request: URLRequest,
        transport: any HTTPTransport,
        retryPolicy: RetryPolicy,
        handle: @escaping @Sendable (SSEEvent, inout StreamAccumulator) throws -> [AIStreamEvent]
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let lines = try await retryPolicy.run {
                        do {
                            return try await transport.eventLines(for: request)
                        } catch {
                            throw ProviderErrorMapper.map(error, provider: providerID)
                        }
                    }

                    continuation.yield(.started)
                    var parser = SSEParser()
                    var accumulator = StreamAccumulator()

                    for try await line in lines {
                        if Task.isCancelled { throw AIProviderError.cancelled }
                        guard let event = parser.consume(line: line) else { continue }
                        if event.data.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                            if let usage = accumulator.usage {
                                continuation.yield(.usage(usage))
                            }
                            continuation.yield(.completed)
                            continuation.finish()
                            return
                        }
                        let output = try handle(event, &accumulator)
                        for event in output {
                            continuation.yield(event)
                        }
                    }
                    if let event = parser.flush() {
                        if event.data.trimmingCharacters(in: .whitespacesAndNewlines) != "[DONE]" {
                            let output = try handle(event, &accumulator)
                            for event in output { continuation.yield(event) }
                        }
                    }
                    if let usage = accumulator.usage {
                        continuation.yield(.usage(usage))
                    }
                    continuation.yield(.completed)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: ProviderErrorMapper.map(error, provider: providerID))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct StreamAccumulator: Sendable {
    var inputTokens: Int?
    var outputTokens: Int?
    var sawText = false

    var usage: TokenUsage? {
        guard inputTokens != nil || outputTokens != nil else { return nil }
        return TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)
    }

    mutating func setUsage(input: Int? = nil, output: Int? = nil) {
        if let input { inputTokens = input }
        if let output { outputTokens = output }
    }
}

enum ProviderJSON {
    static func decode<T: Decodable>(_ type: T.Type, from data: String) throws -> T {
        guard let raw = data.data(using: .utf8) else {
            throw AIProviderError.decoding("Invalid UTF-8 in stream.")
        }
        do {
            return try JSONDecoder().decode(T.self, from: raw)
        } catch {
            throw AIProviderError.decoding(String(describing: error))
        }
    }

    static func errorMessage(from data: String) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any] else {
            return nil
        }
        if let error = object["error"] as? [String: Any] {
            if let message = error["message"] as? String { return message }
            if let status = error["status"] as? String { return status }
        }
        if let message = object["message"] as? String { return message }
        return nil
    }

    static func decodeModelIDList(_ data: Data) throws -> [String] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = object["data"] as? [[String: Any]] else {
            return []
        }
        return array.compactMap { $0["id"] as? String }
    }
}

enum ModelHeuristics {
    static func supportsVision(id: String, provider: AIProviderID) -> Bool {
        let lower = id.lowercased()
        switch provider {
        case .openAI:
            return ["gpt-4o", "gpt-4.1", "gpt-5", "o3", "o4", "chatgpt-4o", "computer-use"].contains { lower.contains($0) }
        case .anthropic:
            return lower.contains("claude-3") || lower.contains("claude-4") || lower.contains("claude-sonnet") || lower.contains("claude-opus") || lower.contains("claude-haiku")
        case .gemini:
            return lower.contains("gemini")
        }
    }

    static func supportsTemperature(id: String, provider: AIProviderID) -> Bool {
        guard provider == .openAI else { return true }
        let lower = id.lowercased()
        return !(lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") || lower.hasPrefix("gpt-5"))
    }

    static func displayName(for id: String, provider: AIProviderID) -> String {
        if let known = ModelCatalogDefaults.models(for: provider).first(where: { $0.id == id }) {
            return known.displayName
        }
        return id
            .replacingOccurrences(of: "-latest", with: "")
            .split(separator: "-")
            .enumerated()
            .map { index, part in
                if part.first?.isNumber == true || part.allSatisfy(\.isNumber) {
                    return String(part)
                }
                if part.count <= 4 && part.allSatisfy(\.isUppercase) {
                    return String(part)
                }
                let text = String(part)
                if ["gpt", "api", "ai"].contains(text) { return text.uppercased() }
                return index == 0 ? text.capitalized : text.capitalized
            }
            .joined(separator: " ")
    }
}
