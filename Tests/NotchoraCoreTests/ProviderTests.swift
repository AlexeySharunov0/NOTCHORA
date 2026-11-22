import XCTest
@testable import NotchoraCore

final class ProviderTests: XCTestCase {
    func testOpenAIStreamsTextAndUsage() async throws {
        let transport = MockTransport(lines: [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}],\"usage\":{\"prompt_tokens\":7,\"completion_tokens\":2}}",
            "",
            "data: [DONE]",
            ""
        ])
        let provider = OpenAIProvider(transport: transport)
        let stream = try await provider.stream(
            request: TestFixtures.request(),
            apiKey: "sk-test-secret"
        )

        var text = ""
        var usage: TokenUsage?
        var started = false
        var completed = false
        for try await event in stream {
            switch event {
            case .started:
                started = true
            case let .textDelta(delta):
                text += delta
            case let .usage(value):
                usage = value
            case .completed:
                completed = true
            }
        }

        XCTAssertTrue(started)
        XCTAssertTrue(completed)
        XCTAssertEqual(text, "Hello world")
        XCTAssertEqual(usage, TokenUsage(inputTokens: 7, outputTokens: 2))

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-secret")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4.1")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["temperature"] as? Double, 0.4)
        XCTAssertEqual(json["max_completion_tokens"] as? Int, 128)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertEqual(messages.first?["content"] as? String, "Be concise.")
    }

    func testOpenAIReasoningModelOmitsTemperature() async throws {
        let transport = MockTransport(lines: ["data: [DONE]", ""])
        let provider = OpenAIProvider(transport: transport)
        let stream = try await provider.stream(
            request: TestFixtures.request(modelID: "o3"),
            apiKey: "sk-test"
        )
        _ = try await collect(stream)

        let request = try XCTUnwrap(transport.lastRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["temperature"])
    }

    func testAnthropicStreamsTextAndUsage() async throws {
        let transport = MockTransport(lines: [
            "event: message_start",
            "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":5}}}",
            "",
            "event: content_block_delta",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Bonjour\"}}",
            "",
            "event: message_delta",
            "data: {\"type\":\"message_delta\",\"usage\":{\"output_tokens\":2}}",
            "",
            "event: message_stop",
            "data: {\"type\":\"message_stop\"}",
            ""
        ])
        let provider = AnthropicProvider(transport: transport)
        let stream = try await provider.stream(
            request: TestFixtures.request(provider: .anthropic, modelID: "claude-sonnet-4-20250514"),
            apiKey: "sk-ant-secret"
        )
        let result = try await collect(stream)

        XCTAssertEqual(result.text, "Bonjour")
        XCTAssertEqual(result.usage, TokenUsage(inputTokens: 5, outputTokens: 2))
        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-20250514")
        XCTAssertEqual(json["max_tokens"] as? Int, 128)
        XCTAssertEqual(json["system"] as? String, "Be concise.")
    }

    func testGeminiStreamsTextAndUsage() async throws {
        let transport = MockTransport(lines: [
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hallo\"}]}}]}",
            "",
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" Welt\"}]}}],\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":2}}",
            ""
        ])
        let provider = GeminiProvider(transport: transport)
        let stream = try await provider.stream(
            request: TestFixtures.request(provider: .gemini, modelID: "gemini-2.5-pro"),
            apiKey: "AIza-test"
        )
        let result = try await collect(stream)

        XCTAssertEqual(result.text, "Hallo Welt")
        XCTAssertEqual(result.usage, TokenUsage(inputTokens: 3, outputTokens: 2))
        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "AIza-test")
        XCTAssertTrue(request.url?.absoluteString.contains("streamGenerateContent?alt=sse") == true)
    }

    func testOpenAIInvalidKeyMapping() async throws {
        let transport = MockTransport()
        transport.configure(error: .http(status: 401, body: "{\"error\":{\"message\":\"bad key\"}}"))
        let provider = OpenAIProvider(transport: transport)
        let stream = try await provider.stream(request: TestFixtures.request(), apiKey: "sk-bad")

        do {
            _ = try await collect(stream)
            XCTFail("Expected invalid key")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .invalidAPIKey(.openAI))
            XCTAssertFalse(error.localizedDescription.contains("sk-bad"))
        }
    }

    func testAnthropicRateLimitMapping() async throws {
        let transport = MockTransport()
        transport.configure(error: .http(status: 429, body: "Too many requests"))
        let provider = AnthropicProvider(transport: transport)
        let stream = try await provider.stream(
            request: TestFixtures.request(provider: .anthropic, modelID: "claude-sonnet-4-20250514"),
            apiKey: "sk-ant"
        )
        do {
            _ = try await collect(stream)
            XCTFail("Expected rate limit")
        } catch let error as AIProviderError {
            if case .rateLimited = error {
                // Expected.
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMissingAPIKeyFailsBeforeNetwork() async {
        let provider = OpenAIProvider(transport: MockTransport())
        do {
            _ = try await provider.stream(request: TestFixtures.request(), apiKey: "  ")
            XCTFail("Expected missing key")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingAPIKey(.openAI))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOpenAIModelListingFiltersNonChatModels() async throws {
        let data = Data("""
        {"data":[
          {"id":"gpt-4.1"},
          {"id":"o3"},
          {"id":"text-embedding-3-small"},
          {"id":"whisper-1"},
          {"id":"dall-e-3"}
        ]}
        """.utf8)
        let transport = MockTransport(data: data)
        let provider = OpenAIProvider(transport: transport)
        let models = try await provider.listModels(apiKey: "sk-test")

        XCTAssertEqual(models.map(\.id).sorted(), ["gpt-4.1", "o3"])
        XCTAssertTrue(models.allSatisfy { $0.providerID == .openAI })
    }

    func testAnthropicModelListing() async throws {
        let data = Data("""
        {"data":[{"id":"claude-sonnet-4-20250514","display_name":"Claude Sonnet 4"}]}
        """.utf8)
        let transport = MockTransport(data: data)
        let provider = AnthropicProvider(transport: transport)
        let models = try await provider.listModels(apiKey: "sk-ant")

        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].id, "claude-sonnet-4-20250514")
        XCTAssertEqual(models[0].displayName, "Claude Sonnet 4")
    }

    func testGeminiModelListingStripsPrefix() async throws {
        let data = Data("""
        {"models":[
          {"name":"models/gemini-2.5-pro","displayName":"Gemini 2.5 Pro","inputTokenLimit":1048576,"supportedGenerationMethods":["generateContent"]},
          {"name":"models/text-embedding-004","supportedGenerationMethods":["embedContent"]}
        ]}
        """.utf8)
        let transport = MockTransport(data: data)
        let provider = GeminiProvider(transport: transport)
        let models = try await provider.listModels(apiKey: "AIza-test")

        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].id, "gemini-2.5-pro")
        XCTAssertEqual(models[0].contextWindow, 1_048_576)
    }

    func testSSEErrorPayloadBecomesStreamError() async throws {
        let transport = MockTransport(lines: [
            "data: {\"error\":{\"message\":\"The model is overloaded\"}}",
            ""
        ])
        let provider = OpenAIProvider(transport: transport)
        let stream = try await provider.stream(request: TestFixtures.request(), apiKey: "sk-test")
        do {
            _ = try await collect(stream)
            XCTFail("Expected stream error")
        } catch let error as AIProviderError {
            guard case let .stream(message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message.contains("overloaded"))
        }
    }

    private func collect(_ stream: AsyncThrowingStream<AIStreamEvent, Error>) async throws -> (text: String, usage: TokenUsage?) {
        var text = ""
        var usage: TokenUsage?
        for try await event in stream {
            switch event {
            case let .textDelta(delta): text += delta
            case let .usage(value): usage = value
            default: break
            }
        }
        return (text, usage)
    }
}
