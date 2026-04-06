import Foundation
import SharedKit

/// Generic HTTP and network error cases for API clients.
///
/// Consumers can extend this enum or wrap it with app-specific error cases
/// (e.g., domain-specific conflict states or cooldown logic).
public enum APIError: Error, LocalizedError, RetryableError, Equatable {
    /// The URL is invalid or malformed
    case invalidURL
    /// The server response is invalid or unexpected
    case invalidResponse
    /// Authentication failed or token expired
    case unauthorized(message: String? = nil)
    /// Access to the resource is forbidden
    case forbidden(message: String? = nil)
    /// The requested resource was not found
    case notFound(message: String? = nil)
    /// Bad request — client error
    case badRequest(message: String? = nil)
    /// Server error occurred
    case serverError(statusCode: Int, message: String? = nil)
    /// Failed to decode the server response
    case decodingError(String)
    /// Network connectivity error
    case networkError(String)
    /// Request timed out
    case timeout
    /// No internet connection available
    case noInternetConnection
    /// Unknown error occurred
    case unknown(message: String? = nil)
    /// Unprocessable entity
    case unprocessableEntity(message: String? = nil)
    /// Rate limit exceeded
    case rateLimitExceeded(message: String? = nil)

    // MARK: - LocalizedError

    /// User-friendly error description
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "There was a problem with the request. Please try again or contact support if the issue persists."
        case .invalidResponse:
            "We received an unexpected response from the server. Please try again."
        case let .unauthorized(message):
            message ?? "Your session has expired. Please log in again to continue."
        case let .forbidden(message):
            message ?? "Access denied. You don't have permission to perform this action."
        case let .notFound(message):
            message ?? "We couldn't find what you're looking for. It may have been removed or is no longer available."
        case let .badRequest(message):
            message ?? "There was a problem with your request. Please check your information and try again."
        case let .serverError(statusCode, message):
            if let message {
                "Server error: \(message). Please try again in a few moments."
            } else {
                "Our servers are experiencing issues (code: \(statusCode)). Please try again in a few moments."
            }
        case let .decodingError(details):
            """
            We couldn't understand the server's response. Please try again or contact support if this continues. \
            Technical details: \(details)
            """
        case let .networkError(details):
            "A network error occurred: \(details). Please check your connection and try again."
        case .timeout:
            "The request took too long to complete. Please check your internet connection and try again."
        case .noInternetConnection:
            "No internet connection detected. Please check your Wi-Fi or cellular data settings and try again."
        case let .rateLimitExceeded(message):
            message ?? "You've made too many requests. Please wait a moment and try again."
        case let .unprocessableEntity(message):
            message ?? "We couldn't process your request. Please check your information and try again."
        case let .unknown(message):
            message ?? "Something unexpected happened. Please try again or contact support if the issue continues."
        }
    }

    // MARK: - RetryableError

    /// Whether this error is retryable (e.g., network errors, timeouts, server errors)
    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .noInternetConnection, .serverError, .rateLimitExceeded:
            true
        case .badRequest, .unprocessableEntity, .unauthorized, .forbidden,
             .invalidURL, .invalidResponse, .notFound, .decodingError, .unknown:
            false
        }
    }
}
