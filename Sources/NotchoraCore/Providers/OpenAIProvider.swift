import Foundation

public struct OpenAIProvider: AIProvider {
    public let id: AIProviderID = .openAI
    public let capabilities = ProviderCapabilities(supportsStreaming: true, supportsVision: true, supportsModelListing: true)

    private let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let baseURL: URL

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) {
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.baseURL = baseURL
    }

    public func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.openAI) }

        let body = OpenAIRequestBody(request: request)
        let urlRequest = try HTTPRequestBuilder.json(
            url: baseURL.appendingPathComponent("chat/completions"),
            headers: ["Authorization": "Bearer \(key)"],
            body: body
        )

        return ProviderStreamSupport.makeStream(
            providerID: .openAI,
            request: urlRequest,
            transport: transport,
            retryPolicy: retryPolicy
        ) { event, accumulator in
            guard let payload = event.data.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OpenAIChunk.self, from: payload) else {
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
                } else if let refusal = choice.delta?.refusal, !refusal.isEmpty {
                    accumulator.sawText = true
                    output.append(.textDelta(refusal))
                }
            }
            return output
        }
    }

    public func validateKey(_ apiKey: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    public func listModels(apiKey: String) async throws -> [AIModel] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.openAI) }
        let request = HTTPRequestBuilder.get(
            url: baseURL.appendingPathComponent("models"),
            headers: ["Authorization": "Bearer \(key)"]
        )

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderErrorMapper.map(
                HTTPTransportError.http(status: response.statusCode, body: body),
                provider: .openAI
            )
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["data"] as? [[String: Any]] else {
            throw AIProviderError.decoding("The model list response had an unexpected shape.")
        }

        let excluded = [
            "embedding", "tts", "whisper", "dall-e", "moderation", "realtime",
            "transcribe", "image", "audio", "sora", "babbage", "davinci", "codex-mini"
        ]
        let models = items.compactMap { item -> AIModel? in
            guard let modelID = item["id"] as? String else { return nil }
            let lower = modelID.lowercased()
            if excluded.contains(where: { lower.contains($0) }) { return nil }
            let looksChat = lower.hasPrefix("gpt") || lower.hasPrefix("o1") || lower.hasPrefix("o3")
                || lower.hasPrefix("o4") || lower.hasPrefix("chatgpt") || lower.contains("computer-use")
            guard looksChat else { return nil }
            return AIModel(
                id: modelID,
                providerID: .openAI,
                displayName: ModelHeuristics.displayName(for: modelID, provider: .openAI),
                contextWindow: nil,
                supportsVision: ModelHeuristics.supportsVision(id: modelID, provider: .openAI),
                source: .discovered
            )
        }
        return models.sorted { $0.id < $1.id }
    }
}

private struct OpenAIRequestBody: Encodable {
    let model: String
    let messages: [Message]
    let stream = true
    let streamOptions = StreamOptions(includeUsage: true)
    let temperature: Double?
    let maxCompletionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case streamOptions = "stream_options"
        case maxCompletionTokens = "max_completion_tokens"
    }

    init(request: AIRequest) {
        model = request.model.id
        var messages: [Message] = []
        if let system = request.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !system.isEmpty {
            messages.append(Message(role: "system", content: .text(system)))
        }
        messages.append(contentsOf: request.messages.map { message in
            let images = message.images.map { image in
                ContentPart(
                    type: "image_url",
                    text: nil,
                    imageURL: .init(url: "data:\(image.mimeType);base64,\(image.data.base64EncodedString())")
                )
            }
            if images.isEmpty {
                return Message(role: message.role.rawValue, content: .text(message.text))
            }
            var parts: [ContentPart] = []
            if !message.text.isEmpty {
                parts.append(ContentPart(type: "text", text: message.text, imageURL: nil))
            }
            parts.append(contentsOf: images)
            return Message(role: message.role.rawValue, content: .parts(parts))
        })
        self.messages = messages
        temperature = ModelHeuristics.supportsTemperature(id: request.model.id, provider: .openAI)
            ? request.temperature
            : nil
        maxCompletionTokens = request.maxOutputTokens
    }

    struct StreamOptions: Encodable {
        let includeUsage: Bool
        enum CodingKeys: String, CodingKey { case includeUsage = "include_usage" }
    }

    struct Message: Encodable {
        let role: String
        let content: Content

        enum Content: Encodable {
            case text(String)
            case parts([ContentPart])

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case let .text(text): try container.encode(text)
                case let .parts(parts): try container.encode(parts)
                }
            }
        }
    }

    struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }

        struct ImageURL: Encodable {
            let url: String
        }
    }
}

private struct OpenAIChunk: Decodable {
    var choices: [Choice]
    var usage: Usage?

    struct Choice: Decodable {
        var delta: Delta?
        var finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        var content: String?
        var refusal: String?
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
