import Foundation

public enum HTTPTransportError: Error, LocalizedError, Sendable {
    case invalidResponse(String)
    case http(status: Int, body: String)
    case url(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .invalidResponse(message): message
        case let .http(status, body): "HTTP \(status): \(body)"
        case let .url(message): message
        case .cancelled: "Cancelled"
        }
    }
}

public protocol HTTPTransport: Sendable {
    /// Returns the response body as server-sent-event lines. Connection-level
    /// failures (including non-2xx status) are thrown before returning.
    func eventLines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error>
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 900
            configuration.waitsForConnectivity = false
            configuration.httpShouldSetCookies = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    public func eventLines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch is CancellationError {
            throw HTTPTransportError.cancelled
        } catch let error as URLError {
            if error.code == .cancelled { throw HTTPTransportError.cancelled }
            throw HTTPTransportError.url(error.localizedDescription)
        } catch {
            throw HTTPTransportError.url(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HTTPTransportError.invalidResponse("The provider did not return an HTTP response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = await Self.readLimitedBody(bytes)
            throw HTTPTransportError.http(status: http.statusCode, body: body)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled { throw CancellationError() }
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: HTTPTransportError.cancelled)
                } catch {
                    continuation.finish(throwing: HTTPTransportError.url(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPTransportError.invalidResponse("The provider did not return an HTTP response.")
            }
            return (data, http)
        } catch let error as HTTPTransportError {
            throw error
        } catch is CancellationError {
            throw HTTPTransportError.cancelled
        } catch let error as URLError {
            if error.code == .cancelled { throw HTTPTransportError.cancelled }
            throw HTTPTransportError.url(error.localizedDescription)
        } catch {
            throw HTTPTransportError.url(error.localizedDescription)
        }
    }

    private static func readLimitedBody(_ bytes: URLSession.AsyncBytes) async -> String {
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 16_384 { break }
            }
        } catch {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 0.7) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    public func run<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await operation()
            } catch {
                let providerError = error as? AIProviderError
                let retryable = providerError?.isRetryable ?? false
                guard retryable, attempt < maxAttempts else { throw error }
                let delay = baseDelay * pow(2, Double(attempt - 1))
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }
}

public enum HTTPRequestBuilder {
    public static func json(
        url: URL,
        method: String = "POST",
        headers: [String: String],
        body: some Encodable
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        request.httpBody = try encoder.encode(body)
        return request
    }

    public static func get(url: URL, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}
