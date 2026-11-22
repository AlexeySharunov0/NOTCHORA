import Foundation

public struct GeminiProvider: AIProvider {
    public let id: AIProviderID = .gemini
    public let capabilities = ProviderCapabilities(supportsStreaming: true, supportsVision: true, supportsModelListing: true)

    private let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let baseURL: URL

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    ) {
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.baseURL = baseURL
    }

    public func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.gemini) }

        let modelID = request.model.id.replacingOccurrences(of: "models/", with: "")
        guard let url = URL(string: "\(baseURL.absoluteString)/models/\(modelID):streamGenerateContent?alt=sse") else {
            throw AIProviderError.network("Could not build the Gemini request URL.")
        }

        let body = GeminiRequestBody(request: request)
        let urlRequest = try HTTPRequestBuilder.json(
            url: url,
            headers: ["x-goog-api-key": key],
            body: body
        )

        return ProviderStreamSupport.makeStream(
            providerID: .gemini,
            request: urlRequest,
            transport: transport,
            retryPolicy: retryPolicy
        ) { event, accumulator in
            guard let payload = event.data.data(using: .utf8) else { return [] }
            guard let chunk = try? JSONDecoder().decode(GeminiChunk.self, from: payload) else {
                if let message = ProviderJSON.errorMessage(from: event.data) {
                    throw AIProviderError.stream(message)
                }
                return []
            }

            if let error = chunk.error {
                throw AIProviderError.stream(error.message ?? "Gemini reported a streaming error.")
            }
            if let usage = chunk.usageMetadata {
                accumulator.setUsage(input: usage.promptTokenCount, output: usage.candidatesTokenCount)
            }
            if let block = chunk.promptFeedback?.blockReason {
                throw AIProviderError.stream("Gemini blocked this request (\(block)).")
            }

            var output: [AIStreamEvent] = []
            for candidate in chunk.candidates ?? [] {
                if candidate.finishReason == "SAFETY" && candidate.content?.parts?.isEmpty != false {
                    throw AIProviderError.stream("Gemini stopped the response due to a safety policy.")
                }
                for part in candidate.content?.parts ?? [] {
                    if part.thought == true { continue }
                    if let text = part.text, !text.isEmpty {
                        accumulator.sawText = true
                        output.append(.textDelta(text))
                    }
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
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey(.gemini) }

        var collected: [[String: Any]] = []
        var pageToken: String?
        var page = 0
        repeat {
            var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)
            var items = [URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components?.queryItems = items
            guard let url = components?.url else { throw AIProviderError.network("Invalid model list URL.") }

            let request = HTTPRequestBuilder.get(url: url, headers: ["x-goog-api-key": key])
            let (data, response) = try await transport.data(for: request)
            guard (200...299).contains(response.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ProviderErrorMapper.map(
                    HTTPTransportError.http(status: response.statusCode, body: body),
                    provider: .gemini
                )
            }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AIProviderError.decoding("The model list response was not JSON.")
            }
            collected.append(contentsOf: object["models"] as? [[String: Any]] ?? [])
            pageToken = object["nextPageToken"] as? String
            page += 1
        } while (pageToken?.isEmpty == false) && page < 5

        return collected.compactMap { item -> AIModel? in
            guard let name = item["name"] as? String else { return nil }
            let methods = item["supportedGenerationMethods"] as? [String] ?? []
            guard methods.contains("generateContent") else { return nil }
            let modelID = name.replacingOccurrences(of: "models/", with: "")
            let displayName = (item["displayName"] as? String) ?? ModelHeuristics.displayName(for: modelID, provider: .gemini)
            return AIModel(
                id: modelID,
                providerID: .gemini,
                displayName: displayName,
                contextWindow: item["inputTokenLimit"] as? Int,
                supportsVision: true,
                source: .discovered
            )
        }
        .sorted { $0.id < $1.id }
    }
}


private struct GeminiRequestBody: Encodable {
    let contents: [Content]
    let systemInstruction: SystemInstruction?
    let generationConfig: GenerationConfig?

    init(request: AIRequest) {
        contents = request.messages.map { message in
            var parts: [Part] = []
            if !message.text.isEmpty {
                parts.append(Part(text: message.text, inlineData: nil))
            }
            for image in message.images {
                parts.append(Part(
                    text: nil,
                    inlineData: .init(mimeType: image.mimeType, data: image.data.base64EncodedString())
                ))
            }
            return Content(role: message.role == .assistant ? "model" : "user", parts: parts)
        }
        let system = request.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        systemInstruction = (system?.isEmpty == false)
            ? SystemInstruction(parts: [Part(text: system, inlineData: nil)])
            : nil
        if request.temperature != nil || request.maxOutputTokens != nil {
            generationConfig = GenerationConfig(
                temperature: request.temperature,
                maxOutputTokens: request.maxOutputTokens
            )
        } else {
            generationConfig = nil
        }
    }

    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    struct SystemInstruction: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String?
        let inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inlineData"
        }
    }

    struct InlineData: Encodable {
        let mimeType: String
        let data: String
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?
    }
}

private struct GeminiChunk: Decodable {
    var candidates: [Candidate]?
    var usageMetadata: Usage?
    var promptFeedback: PromptFeedback?
    var error: APIError?

    struct Candidate: Decodable {
        var content: Content?
        var finishReason: String?
    }

    struct Content: Decodable {
        var parts: [Part]?
        var role: String?
    }

    struct Part: Decodable {
        var text: String?
        var thought: Bool?
    }

    struct Usage: Decodable {
        var promptTokenCount: Int?
        var candidatesTokenCount: Int?
        var totalTokenCount: Int?
    }

    struct PromptFeedback: Decodable {
        var blockReason: String?
    }

    struct APIError: Decodable {
        var message: String?
        var status: String?
    }
}
