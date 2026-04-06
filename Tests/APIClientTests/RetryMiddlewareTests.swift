@testable import APIClient
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@Suite("RetryMiddleware Tests")
struct RetryMiddlewareTests {
    private let baseURL = URL(string: "https://api.example.com")!
    private let getRequest = HTTPRequest(method: .get, scheme: "https", authority: "api.example.com", path: "/v1/data")

    // MARK: - Pass-through

    @Test("Passes through successful responses without retrying")
    func passThrough() async throws {
        let middleware = RetryMiddleware()
        var callCount = 0

        let (response, _) = try await middleware.intercept(
            getRequest, body: nil, baseURL: baseURL, operationID: "getData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .ok), nil)
        }

        #expect(response.status == .ok)
        #expect(callCount == 1)
    }

    // MARK: - Retry on server errors

    @Test("Retries on 500 up to maxRetries times")
    func retriesOnServerError() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 2, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let (response, _) = try await middleware.intercept(
            getRequest, body: nil, baseURL: baseURL, operationID: "getData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .internalServerError), nil)
        }

        // 1 initial + 2 retries = 3 total
        #expect(callCount == 3)
        #expect(response.status == .internalServerError)
    }

    @Test("Returns immediately on successful retry")
    func returnsOnSuccessfulRetry() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 3, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let (response, _) = try await middleware.intercept(
            getRequest, body: nil, baseURL: baseURL, operationID: "getData"
        ) { _, _, _ in
            callCount += 1
            if callCount < 3 {
                return (HTTPResponse(status: .internalServerError), nil)
            }
            return (HTTPResponse(status: .ok), nil)
        }

        #expect(callCount == 3)
        #expect(response.status == .ok)
    }

    // MARK: - Idempotency

    @Test("Does not retry POST requests by default")
    func doesNotRetryPost() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 3, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let postRequest = HTTPRequest(method: .post, scheme: "https", authority: "api.example.com", path: "/v1/data")
        let (response, _) = try await middleware.intercept(
            postRequest, body: nil, baseURL: baseURL, operationID: "createData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .internalServerError), nil)
        }

        #expect(callCount == 1)
        #expect(response.status == .internalServerError)
    }

    @Test("Retries POST when retryAllMethods is enabled")
    func retriesPostWhenConfigured() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 2, baseDelay: 0.01, jitterEnabled: false, retryAllMethods: true)
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let postRequest = HTTPRequest(method: .post, scheme: "https", authority: "api.example.com", path: "/v1/data")
        let (response, _) = try await middleware.intercept(
            postRequest, body: nil, baseURL: baseURL, operationID: "createData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .internalServerError), nil)
        }

        #expect(callCount == 3)
        #expect(response.status == .internalServerError)
    }

    @Test("Retries idempotent methods: GET, HEAD, PUT, DELETE, OPTIONS")
    func retriesIdempotentMethods() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 1, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)

        for method: HTTPRequest.Method in [.get, .head, .put, .delete, .options] {
            var callCount = 0
            let request = HTTPRequest(method: method, scheme: "https", authority: "api.example.com", path: "/v1/data")

            _ = try await middleware.intercept(
                request, body: nil, baseURL: baseURL, operationID: "op"
            ) { _, _, _ in
                callCount += 1
                return (HTTPResponse(status: .internalServerError), nil)
            }

            #expect(callCount == 2, "Expected \(method.rawValue) to be retried")
        }
    }

    // MARK: - Retry-After header

    @Test("Respects Retry-After header with seconds value")
    func respectsRetryAfterSeconds() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 1, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)

        let delay = middleware.delay(for: 0, responseHeaders: HTTPFields([
            HTTPField(name: HTTPField.Name("Retry-After")!, value: "2")
        ]))

        #expect(delay == 2.0)
    }

    @Test("Caps Retry-After at maxDelay")
    func capsRetryAfterAtMaxDelay() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 1, baseDelay: 0.01, maxDelay: 5, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)

        let delay = middleware.delay(for: 0, responseHeaders: HTTPFields([
            HTTPField(name: HTTPField.Name("Retry-After")!, value: "60")
        ]))

        #expect(delay == 5.0)
    }

    // MARK: - Exponential backoff

    @Test("Applies exponential backoff without jitter")
    func exponentialBackoff() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 3, baseDelay: 1.0, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)

        let delay0 = middleware.delay(for: 0, responseHeaders: HTTPFields())
        let delay1 = middleware.delay(for: 1, responseHeaders: HTTPFields())
        let delay2 = middleware.delay(for: 2, responseHeaders: HTTPFields())

        #expect(delay0 == 1.0)  // 1 * 2^0
        #expect(delay1 == 2.0)  // 1 * 2^1
        #expect(delay2 == 4.0)  // 1 * 2^2
    }

    @Test("Caps delay at maxDelay")
    func capsDelayAtMax() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 10, baseDelay: 1.0, maxDelay: 5.0, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)

        let delay5 = middleware.delay(for: 5, responseHeaders: HTTPFields()) // 1 * 2^5 = 32, capped at 5
        #expect(delay5 == 5.0)
    }

    // MARK: - Non-retryable status codes

    @Test("Does not retry 4xx responses by default")
    func doesNotRetry4xx() async throws {
        let config = RetryMiddleware.Configuration(maxRetries: 3, baseDelay: 0.01, jitterEnabled: false)
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let (response, _) = try await middleware.intercept(
            getRequest, body: nil, baseURL: baseURL, operationID: "getData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .badRequest), nil)
        }

        #expect(callCount == 1)
        #expect(response.status == .badRequest)
    }

    @Test("Retries custom status codes when configured")
    func retriesCustomStatusCodes() async throws {
        let config = RetryMiddleware.Configuration(
            maxRetries: 1, baseDelay: 0.01, jitterEnabled: false,
            retryableStatusCodes: [429, 503]
        )
        let middleware = RetryMiddleware(configuration: config)
        var callCount = 0

        let (response, _) = try await middleware.intercept(
            getRequest, body: nil, baseURL: baseURL, operationID: "getData"
        ) { _, _, _ in
            callCount += 1
            return (HTTPResponse(status: .tooManyRequests), nil)
        }

        #expect(callCount == 2)
        #expect(response.status == .tooManyRequests)
    }
}
