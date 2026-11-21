import Foundation

public struct AnthropicProvider: AIProvider {
    public let id: AIProviderID = .anthropic
    public let capabilities = ProviderCapabilities(supportsStreaming: true, supportsVision: true, supportsModelListing: true)

    private let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let baseURL: URL
    private let anthropicVersion: String

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        anthropicVersion: String = "2023-06-01"
    ) {
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
    }

    public func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.anthropic) }

        let body = AnthropicRequestBody(request: request)
        let urlRequest = try HTTPRequestBuilder.json(
            url: baseURL.appendingPathComponent("messages"),
            headers: [
                "x-api-key": key,
                "anthropic-version": anthropicVersion
            ],
            body: body
        )

        return ProviderStreamSupport.makeStream(
            providerID: .anthropic,
            request: urlRequest,
            transport: transport,
            retryPolicy: retryPolicy
        ) { event, accumulator in
            guard let payload = event.data.data(using: .utf8) else { return [] }
            guard let chunk = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: payload) else {
                if let message = ProviderJSON.errorMessage(from: event.data) {
                    throw AIProviderError.stream(message)
                }
                return []
            }

            if chunk.type == "error" || event.event == "error" {
                throw AIProviderError.stream(chunk.error?.message ?? "Anthropic reported a streaming error.")
            }
            if let usage = chunk.message?.usage {
                accumulator.setUsage(input: usage.inputTokens, output: usage.outputTokens)
            }
            if let usage = chunk.usage {
                accumulator.setUsage(input: usage.inputTokens, output: usage.outputTokens)
            }
            if chunk.type == "content_block_delta",
               chunk.delta?.type == "text_delta",
               let text = chunk.delta?.text,
               !text.isEmpty {
                accumulator.sawText = true
                return [.textDelta(text)]
            }
            return []
        }
    }

    public func validateKey(_ apiKey: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    public func listModels(apiKey: String) async throws -> [AIModel] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.anthropic) }

        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "100")]
        guard let url = components?.url else { throw AIProviderError.network("Invalid model list URL.") }

        let request = HTTPRequestBuilder.get(
            url: url,
            headers: [
                "x-api-key": key,
                "anthropic-version": anthropicVersion
            ]
        )

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderErrorMapper.map(
                HTTPTransportError.http(status: response.statusCode, body: body),
                provider: .anthropic
            )
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["data"] as? [[String: Any]] else {
            throw AIProviderError.decoding("The model list response had an unexpected shape.")
        }

        return items.compactMap { item in
            guard let modelID = item["id"] as? String else { return nil }
            let displayName = item["display_name"] as? String
            return AIModel(
                id: modelID,
                providerID: .anthropic,
                displayName: displayName ?? ModelHeuristics.displayName(for: modelID, provider: .anthropic),
                contextWindow: nil,
                supportsVision: ModelHeuristics.supportsVision(id: modelID, provider: .anthropic),
                source: .discovered
            )
        }
        .sorted { $0.id < $1.id }
    }
}

private struct AnthropicRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [Message]
    let stream = true
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream, temperature
        case maxTokens = "max_tokens"
    }

    init(request: AIRequest) {
        model = request.model.id
        maxTokens = request.maxOutputTokens ?? 4096
        let system = request.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.system = (system?.isEmpty == false) ? system : nil
        temperature = request.temperature
        messages = request.messages.map { message in
            let blocks = message.images.map { image in
                ContentBlock(
                    type: "image",
                    text: nil,
                    source: .init(type: "base64", mediaType: image.mimeType, data: image.data.base64EncodedString())
                )
            }
            if blocks.isEmpty {
                return Message(role: message.role.rawValue, content: .text(message.text))
            }
            var content: [ContentBlock] = []
            if !message.text.isEmpty {
                content.append(ContentBlock(type: "text", text: message.text, source: nil))
            }
            content.append(contentsOf: blocks)
            return Message(role: message.role.rawValue, content: .blocks(content))
        }
    }

    struct Message: Encodable {
        let role: String
        let content: Content

        enum Content: Encodable {
            case text(String)
            case blocks([ContentBlock])

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case let .text(text): try container.encode(text)
                case let .blocks(blocks): try container.encode(blocks)
                }
            }
        }
    }

    struct ContentBlock: Encodable {
        let type: String
        let text: String?
        let source: Source?

        struct Source: Encodable {
            let type: String
            let mediaType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case type, data
                case mediaType = "media_type"
            }
        }
    }
}

private struct AnthropicStreamEvent: Decodable {
    var type: String
    var message: Message?
    var delta: Delta?
    var usage: Usage?
    var error: APIError?

    struct Message: Decodable {
        var usage: Usage?
    }

    struct Delta: Decodable {
        var type: String?
        var text: String?
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case type, text
            case stopReason = "stop_reason"
        }
    }

    struct Usage: Decodable {
        var inputTokens: Int?
        var outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    struct APIError: Decodable {
        var type: String?
        var message: String?
    }
}
