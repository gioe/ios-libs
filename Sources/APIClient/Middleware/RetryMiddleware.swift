import Foundation
import HTTPTypes
import OpenAPIRuntime

/// A middleware that retries failed requests with exponential backoff and jitter.
///
/// By default, only idempotent HTTP methods (GET, HEAD, PUT, DELETE, OPTIONS) are retried.
/// This can be overridden via ``Configuration/retryAllMethods``.
///
/// ## Usage
/// ```swift
/// let retry = RetryMiddleware(configuration: .init(maxRetries: 3))
/// let client = Client(
///     serverURL: serverURL,
///     transport: URLSessionTransport(),
///     middlewares: [retry]
/// )
/// ```
public struct RetryMiddleware: ClientMiddleware, Sendable {

    /// Configuration for retry behavior.
    public struct Configuration: Sendable {
        /// Maximum number of retry attempts (does not count the initial request).
        public var maxRetries: Int

        /// Base delay between retries in seconds. Actual delay doubles on each attempt.
        public var baseDelay: TimeInterval

        /// Maximum delay cap in seconds.
        public var maxDelay: TimeInterval

        /// Whether to add random jitter (0–50% of computed delay) to avoid thundering herd.
        public var jitterEnabled: Bool

        /// When `true`, all HTTP methods are retried. When `false` (default), only
        /// idempotent methods are retried.
        public var retryAllMethods: Bool

        /// HTTP status codes that trigger a retry. Defaults to server errors (500–599).
        public var retryableStatusCodes: Set<Int>

        /// Creates a retry configuration.
        public init(
            maxRetries: Int = 3,
            baseDelay: TimeInterval = 0.5,
            maxDelay: TimeInterval = 30,
            jitterEnabled: Bool = true,
            retryAllMethods: Bool = false,
            retryableStatusCodes: Set<Int> = Set(500...599).union([429])
        ) {
            self.maxRetries = max(0, maxRetries)
            self.baseDelay = max(0, baseDelay)
            self.maxDelay = max(0, maxDelay)
            self.jitterEnabled = jitterEnabled
            self.retryAllMethods = retryAllMethods
            self.retryableStatusCodes = retryableStatusCodes
        }
    }

    private static let idempotentMethods: Set<HTTPRequest.Method> = [
        .get, .head, .put, .delete, .options
    ]

    private let configuration: Configuration

    /// Creates a retry middleware with the given configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard shouldRetry(method: request.method) else {
            return try await next(request, body, baseURL)
        }

        var lastResponse = try await next(request, body, baseURL)

        for attempt in 0..<configuration.maxRetries {
            guard configuration.retryableStatusCodes.contains(lastResponse.0.status.code) else {
                return lastResponse
            }

            let delay = self.delay(for: attempt, responseHeaders: lastResponse.0.headerFields)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            lastResponse = try await next(request, body, baseURL)
        }

        return lastResponse
    }

    // MARK: - Private

    private func shouldRetry(method: HTTPRequest.Method) -> Bool {
        configuration.retryAllMethods || Self.idempotentMethods.contains(method)
    }

    /// Computes the delay for a given attempt, respecting Retry-After headers.
    func delay(for attempt: Int, responseHeaders: HTTPFields) -> TimeInterval {
        // Check Retry-After header first
        if let retryAfter = retryAfterDelay(from: responseHeaders) {
            return min(retryAfter, configuration.maxDelay)
        }

        // Exponential backoff: baseDelay * 2^attempt
        let exponential = configuration.baseDelay * pow(2.0, Double(attempt))
        let capped = min(exponential, configuration.maxDelay)

        if configuration.jitterEnabled {
            // Full jitter: random value in [0, capped] — naturally bounded by maxDelay
            return Double.random(in: 0...capped)
        }

        return capped
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    /// Parses the `Retry-After` header value as either seconds or an HTTP-date.
    private func retryAfterDelay(from headers: HTTPFields) -> TimeInterval? {
        guard let value = headers[HTTPField.Name("Retry-After")!] else { return nil }

        // Try parsing as seconds first
        if let seconds = Double(value), seconds >= 0 {
            return seconds
        }

        // Try parsing as HTTP-date (RFC 7231)
        if let date = Self.httpDateFormatter.date(from: value) {
            let delay = date.timeIntervalSinceNow
            return delay > 0 ? delay : 0
        }

        return nil
    }
}
