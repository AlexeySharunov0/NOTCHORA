import Foundation

/// DeepSeek exposes an OpenAI-compatible Chat Completions API. The request and
/// stream shape are deliberately implemented separately so DeepSeek-specific
/// fields (`max_tokens`, reasoning deltas) do not leak into the OpenAI client.
public struct DeepSeekProvider: AIProvider {
    public let id: AIProviderID = .deepSeek
    public let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: false,
        supportsModelListing: true
    )

    private let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let baseURL: URL

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) {
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.baseURL = baseURL
    }

    public func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.deepSeek) }
        guard request.messages.allSatisfy({ $0.images.isEmpty }) else {
            throw AIProviderError.unsupportedContent("DeepSeek models do not accept image input.")
        }

        let body = DeepSeekRequestBody(request: request)
        let urlRequest = try HTTPRequestBuilder.json(
            url: baseURL.appendingPathComponent("chat/completions"),
            headers: ["Authorization": "Bearer \(key)"],
            body: body
        )

        return ProviderStreamSupport.makeStream(
            providerID: .deepSeek,
            request: urlRequest,
            transport: transport,
            retryPolicy: retryPolicy
        ) { event, accumulator in
            guard let payload = event.data.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(DeepSeekChunk.self, from: payload) else {
                if let message = ProviderJSON.errorMessage(from: event.data) {
                    throw AIProviderError.stream(message)
                }
                return []
            }
            if let usage = chunk.usage {
                accumulator.setUsage(input: usage.promptTokens, output: usage.completionTokens)
            }
            var output: [AIStreamEvent] = []
            for choice in chunk.choices {
                if let text = choice.delta?.content, !text.isEmpty {
                    accumulator.sawText = true
                    output.append(.textDelta(text))
                }
                // reasoning_content is intentionally not surfaced as chat text;
                // the final answer arrives in content.
            }
            return output
        }
    }

    public func validateKey(_ apiKey: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    public func listModels(apiKey: String) async throws -> [AIModel] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.deepSeek) }
        let request = HTTPRequestBuilder.get(
            url: baseURL.appendingPathComponent("models"),
            headers: ["Authorization": "Bearer \(key)"]
        )
        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderErrorMapper.map(
                HTTPTransportError.http(status: response.statusCode, body: body),
                provider: .deepSeek
            )
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["data"] as? [[String: Any]] else {
            throw AIProviderError.decoding("The DeepSeek model list had an unexpected shape.")
        }
        let models = items.compactMap { item -> AIModel? in
            guard let modelID = item["id"] as? String else { return nil }
            let lower = modelID.lowercased()
            guard lower.hasPrefix("deepseek") else { return nil }
            return AIModel(
                id: modelID,
                providerID: .deepSeek,
                displayName: ModelHeuristics.displayName(for: modelID, provider: .deepSeek),
                contextWindow: nil,
                supportsVision: false,
                source: .discovered
            )
        }
        return models.sorted { $0.id < $1.id }
    }
}

private struct DeepSeekRequestBody: Encodable {
    let model: String
    let messages: [Message]
    let stream = true
    let streamOptions = StreamOptions(includeUsage: true)
    let temperature: Double?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case streamOptions = "stream_options"
        case maxTokens = "max_tokens"
    }

    init(request: AIRequest) {
        model = request.model.id
        var messages: [Message] = []
        if let system = request.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !system.isEmpty {
            messages.append(Message(role: "system", content: system))
        }
        messages.append(contentsOf: request.messages.map {
            Message(role: $0.role.rawValue, content: $0.text)
        })
        self.messages = messages
        temperature = ModelHeuristics.supportsTemperature(id: request.model.id, provider: .deepSeek)
            ? request.temperature
            : nil
        maxTokens = request.maxOutputTokens
    }

    struct StreamOptions: Encodable {
        let includeUsage: Bool
        enum CodingKeys: String, CodingKey { case includeUsage = "include_usage" }
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct DeepSeekChunk: Decodable {
    var choices: [Choice]
    var usage: Usage?

    struct Choice: Decodable {
        var delta: Delta?
    }

    struct Delta: Decodable {
        var content: String?
        var reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
        }
    }

    struct Usage: Decodable {
        var promptTokens: Int?
        var completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
}
