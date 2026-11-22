import Foundation
@testable import NotchoraCore

final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _lines: [String] = []
    private var _data = Data()
    private var _status = 200
    private var _httpError: HTTPTransportError?
    private var _lastRequest: URLRequest?

    var lastRequest: URLRequest? {
        lock.withLock { _lastRequest }
    }

    init(lines: [String] = [], data: Data = Data(), status: Int = 200) {
        _lines = lines
        _data = data
        _status = status
    }

    func configure(lines: [String] = [], data: Data = Data(), status: Int = 200, error: HTTPTransportError? = nil) {
        lock.withLock {
            _lines = lines
            _data = data
            _status = status
            _httpError = error
        }
    }

    func eventLines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        let (lines, error) = lock.withLock {
            _lastRequest = request
            return (_lines, _httpError)
        }

        if let error { throw error }
        return AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, status, error) = lock.withLock {
            _lastRequest = request
            return (_data, _status, _httpError)
        }

        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}

final class MockProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID
    let capabilities = ProviderCapabilities()
    private let lock = NSLock()
    private var _lastRequest: AIRequest?
    private var _lastAPIKey: String?
    private var _models: [AIModel]
    private var _error: AIProviderError?
    private var _chunks: [String]
    private var _usage: TokenUsage?

    init(
        id: AIProviderID,
        chunks: [String] = ["mock"],
        usage: TokenUsage? = TokenUsage(inputTokens: 1, outputTokens: 2),
        models: [AIModel] = [],
        error: AIProviderError? = nil
    ) {
        self.id = id
        self._chunks = chunks
        self._usage = usage
        self._models = models
        self._error = error
    }

    var lastRequest: AIRequest? {
        lock.withLock { _lastRequest }
    }

    var lastAPIKey: String? {
        lock.withLock { _lastAPIKey }
    }

    func stream(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let (error, chunks, usage) = lock.withLock {
            _lastRequest = request
            _lastAPIKey = apiKey
            return (_error, _chunks, _usage)
        }

        if let error { throw error }
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            for chunk in chunks {
                continuation.yield(.textDelta(chunk))
            }
            if let usage { continuation.yield(.usage(usage)) }
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func validateKey(_ apiKey: String) async throws {
        if apiKey == "bad" { throw AIProviderError.invalidAPIKey(id) }
        if apiKey.isEmpty { throw AIProviderError.missingAPIKey(id) }
    }

    func listModels(apiKey: String) async throws -> [AIModel] {
        if apiKey == "bad" { throw AIProviderError.invalidAPIKey(id) }
        return lock.withLock { _models }
    }
}

final class StubAIService: AIServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [AIRequest] = []
    private var _outputs: [String]
    private var _failure: AIProviderError?

    init(outputs: [String] = [], failure: AIProviderError? = nil) {
        self._outputs = outputs
        self._failure = failure
    }

    var requests: [AIRequest] {
        lock.withLock { _requests }
    }

    func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        let (output, failure) = lock.withLock {
            _requests.append(request)
            let output = _outputs.isEmpty ? "ok" : _outputs.removeFirst()
            return (output, _failure)
        }
        if let failure { throw failure }
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.textDelta(output))
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func complete(_ request: AIRequest) async throws -> CompletionResult {
        let (output, failure) = lock.withLock {
            _requests.append(request)
            let output = _outputs.isEmpty ? "Step result" : _outputs.removeFirst()
            return (output, _failure)
        }
        if let failure { throw failure }
        return CompletionResult(text: output)
    }

    func validateKey(_ key: String, for provider: AIProviderID) async throws {}

    func listModels(for provider: AIProviderID, apiKey: String) async throws -> [AIModel] { [] }

    func listModels(for provider: AIProviderID) async throws -> [AIModel] { [] }
}

enum TestFixtures {
    static func model(_ provider: AIProviderID = .openAI, id: String = "gpt-4.1", vision: Bool = true) -> AIModel {
        AIModel(id: id, providerID: provider, displayName: id, supportsVision: vision)
    }

    static func request(
        provider: AIProviderID = .openAI,
        modelID: String = "gpt-4.1",
        systemPrompt: String? = "Be concise.",
        messages: [AIWireMessage] = [AIWireMessage(role: .user, text: "Hello")]
    ) -> AIRequest {
        AIRequest(
            model: model(provider, id: modelID),
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: 0.4,
            maxOutputTokens: 128
        )
    }

    static func conversation(
        provider: AIProviderID = .openAI,
        title: String = "Test Chat"
    ) -> Conversation {
        var conversation = Conversation(
            title: title,
            providerID: provider,
            modelID: provider.defaultModelID
        )
        conversation.messages = [
            ChatMessage(role: .user, content: "First question"),
            ChatMessage(
                role: .assistant,
                content: "First answer",
                providerID: provider,
                modelID: provider.defaultModelID,
                status: .complete
            ),
            ChatMessage(role: .user, content: "Second question"),
            ChatMessage(
                role: .assistant,
                content: "Second answer with **markdown**",
                providerID: provider,
                modelID: provider.defaultModelID,
                status: .complete
            )
        ]
        return conversation
    }

    static func temporaryDirectory() -> URL {
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/test-tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
