@testable import APIClient
import Testing

@Suite("APIError Tests")
struct APIErrorTests {
    // MARK: - Error Descriptions

    @Test("invalidURL provides user-friendly description")
    func invalidURLDescription() {
        let error = APIError.invalidURL
        #expect(error.errorDescription?.contains("problem with the request") == true)
    }

    @Test("invalidResponse provides user-friendly description")
    func invalidResponseDescription() {
        let error = APIError.invalidResponse
        #expect(error.errorDescription?.contains("unexpected response") == true)
    }

    @Test("unauthorized uses custom message when provided")
    func unauthorizedCustomMessage() {
        let error = APIError.unauthorized(message: "Token revoked")
        #expect(error.errorDescription == "Token revoked")
    }

    @Test("unauthorized uses default message when nil")
    func unauthorizedDefaultMessage() {
        let error = APIError.unauthorized()
        #expect(error.errorDescription?.contains("session has expired") == true)
    }

    @Test("forbidden uses custom message when provided")
    func forbiddenCustomMessage() {
        let error = APIError.forbidden(message: "Admin only")
        #expect(error.errorDescription == "Admin only")
    }

    @Test("forbidden uses default message when nil")
    func forbiddenDefaultMessage() {
        let error = APIError.forbidden()
        #expect(error.errorDescription?.contains("Access denied") == true)
    }

    @Test("notFound uses custom message when provided")
    func notFoundCustomMessage() {
        let error = APIError.notFound(message: "User not found")
        #expect(error.errorDescription == "User not found")
    }

    @Test("notFound uses default message when nil")
    func notFoundDefaultMessage() {
        let error = APIError.notFound()
        #expect(error.errorDescription?.contains("couldn't find") == true)
    }

    @Test("badRequest uses custom message when provided")
    func badRequestCustomMessage() {
        let error = APIError.badRequest(message: "Missing field")
        #expect(error.errorDescription == "Missing field")
    }

    @Test("serverError includes status code when no message")
    func serverErrorWithStatusCode() {
        let error = APIError.serverError(statusCode: 503, message: nil)
        #expect(error.errorDescription?.contains("503") == true)
    }

    @Test("serverError includes message when provided")
    func serverErrorWithMessage() {
        let error = APIError.serverError(statusCode: 500, message: "Internal failure")
        #expect(error.errorDescription?.contains("Internal failure") == true)
    }

    @Test("decodingError includes technical details")
    func decodingErrorDescription() {
        let error = APIError.decodingError("keyNotFound: id")
        #expect(error.errorDescription?.contains("keyNotFound: id") == true)
    }

    @Test("networkError includes details")
    func networkErrorDescription() {
        let error = APIError.networkError("Connection reset")
        #expect(error.errorDescription?.contains("Connection reset") == true)
    }

    @Test("timeout provides user-friendly description")
    func timeoutDescription() {
        let error = APIError.timeout
        #expect(error.errorDescription?.contains("took too long") == true)
    }

    @Test("noInternetConnection provides user-friendly description")
    func noInternetConnectionDescription() {
        let error = APIError.noInternetConnection
        #expect(error.errorDescription?.contains("No internet connection") == true)
    }

    @Test("rateLimitExceeded uses custom message when provided")
    func rateLimitCustomMessage() {
        let error = APIError.rateLimitExceeded(message: "Retry after 60s")
        #expect(error.errorDescription == "Retry after 60s")
    }

    @Test("rateLimitExceeded uses default message when nil")
    func rateLimitDefaultMessage() {
        let error = APIError.rateLimitExceeded()
        #expect(error.errorDescription?.contains("too many requests") == true)
    }

    @Test("unprocessableEntity uses custom message when provided")
    func unprocessableEntityCustomMessage() {
        let error = APIError.unprocessableEntity(message: "Invalid email format")
        #expect(error.errorDescription == "Invalid email format")
    }

    @Test("unknown uses default message when nil")
    func unknownDefaultMessage() {
        let error = APIError.unknown()
        #expect(error.errorDescription?.contains("unexpected") == true)
    }

    // MARK: - Retryability

    @Test(
        "Retryable errors",
        arguments: [
            APIError.networkError("timeout"),
            APIError.timeout,
            APIError.noInternetConnection,
            APIError.serverError(statusCode: 500, message: nil),
            APIError.rateLimitExceeded(message: nil),
        ]
    )
    func retryableErrors(error: APIError) {
        #expect(error.isRetryable == true)
    }

    @Test(
        "Non-retryable errors",
        arguments: [
            APIError.invalidURL,
            APIError.invalidResponse,
            APIError.unauthorized(message: nil),
            APIError.forbidden(message: nil),
            APIError.notFound(message: nil),
            APIError.badRequest(message: nil),
            APIError.decodingError("test"),
            APIError.unprocessableEntity(message: nil),
            APIError.unknown(message: nil),
        ]
    )
    func nonRetryableErrors(error: APIError) {
        #expect(error.isRetryable == false)
    }

    // MARK: - HTTP Status Code Factory

    @Test("Returns nil for success status codes")
    func fromHTTPStatusSuccess() {
        #expect(APIError.fromHTTPStatus(200) == nil)
        #expect(APIError.fromHTTPStatus(201) == nil)
        #expect(APIError.fromHTTPStatus(204) == nil)
        #expect(APIError.fromHTTPStatus(299) == nil)
    }

    @Test("Maps 400 to badRequest")
    func fromHTTPStatus400() {
        #expect(APIError.fromHTTPStatus(400) == .badRequest(message: nil))
        #expect(APIError.fromHTTPStatus(400, message: "Invalid") == .badRequest(message: "Invalid"))
    }

    @Test("Maps 401 to unauthorized")
    func fromHTTPStatus401() {
        #expect(APIError.fromHTTPStatus(401) == .unauthorized(message: nil))
    }

    @Test("Maps 403 to forbidden")
    func fromHTTPStatus403() {
        #expect(APIError.fromHTTPStatus(403) == .forbidden(message: nil))
    }

    @Test("Maps 404 to notFound")
    func fromHTTPStatus404() {
        #expect(APIError.fromHTTPStatus(404) == .notFound(message: nil))
    }

    @Test("Maps 422 to unprocessableEntity")
    func fromHTTPStatus422() {
        #expect(APIError.fromHTTPStatus(422) == .unprocessableEntity(message: nil))
    }

    @Test("Maps 429 to rateLimitExceeded")
    func fromHTTPStatus429() {
        #expect(APIError.fromHTTPStatus(429) == .rateLimitExceeded(message: nil))
    }

    @Test("Maps 5xx to serverError with status code")
    func fromHTTPStatus5xx() {
        #expect(APIError.fromHTTPStatus(500) == .serverError(statusCode: 500, message: nil))
        #expect(APIError.fromHTTPStatus(502) == .serverError(statusCode: 502, message: nil))
        #expect(APIError.fromHTTPStatus(503, message: "Unavailable") == .serverError(statusCode: 503, message: "Unavailable"))
    }

    @Test("Maps unknown error codes to unknown")
    func fromHTTPStatusUnknown() {
        #expect(APIError.fromHTTPStatus(418) == .unknown(message: nil))
        #expect(APIError.fromHTTPStatus(100) == .unknown(message: nil))
    }

    // MARK: - Equality

    @Test("Equal errors with same cases and values")
    func equalErrors() {
        #expect(APIError.invalidURL == APIError.invalidURL)
        #expect(APIError.timeout == APIError.timeout)
        #expect(APIError.unauthorized(message: "x") == APIError.unauthorized(message: "x"))
        #expect(APIError.serverError(statusCode: 500, message: "err") == APIError.serverError(statusCode: 500, message: "err"))
    }

    @Test("Unequal errors with different cases or values")
    func unequalErrors() {
        #expect(APIError.invalidURL != APIError.invalidResponse)
        #expect(APIError.unauthorized(message: "a") != APIError.unauthorized(message: "b"))
        #expect(APIError.serverError(statusCode: 500, message: nil) != APIError.serverError(statusCode: 503, message: nil))
    }
}
