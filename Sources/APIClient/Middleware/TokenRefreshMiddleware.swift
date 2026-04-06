import Foundation
import HTTPTypes
import OpenAPIRuntime

/// A middleware that intercepts 401 responses, refreshes the token, and retries the original request.
///
/// Place this **before** `AuthenticationMiddleware` in the middleware chain so that retried
/// requests pick up the freshly-stored token.
///
/// ## Usage
/// ```swift
/// let refreshMiddleware = TokenRefreshMiddleware(
///     authMiddleware: factory.authMiddleware
/// ) { authMiddleware in
///     // Call your refresh endpoint, parse the response, and return new tokens.
///     let response = try await client.refreshAccessTokenV1AuthRefreshPost()
///     guard case .ok(let ok) = response, case .json(let body) = ok.body else {
///         throw TokenRefreshError.refreshFailed
///     }
///     return TokenRefreshMiddleware.Tokens(
///         accessToken: body.accessToken,
///         refreshToken: body.refreshToken
///     )
/// }
/// let client = factory.makeClient(tokenRefreshMiddleware: refreshMiddleware)
/// ```
public actor TokenRefreshMiddleware: ClientMiddleware {
    /// Token pair returned by the refresh closure.
    public struct Tokens: Sendable {
        public let accessToken: String
        public let refreshToken: String

        public init(accessToken: String, refreshToken: String) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    /// Closure the caller provides to perform the actual token refresh.
    /// Receives the `AuthenticationMiddleware` so it can read the current refresh token if needed.
    public typealias RefreshHandler = @Sendable (AuthenticationMiddleware) async throws -> Tokens

    private let authMiddleware: AuthenticationMiddleware
    private let refreshHandler: RefreshHandler

    /// In-flight refresh task, used to coalesce concurrent 401 responses into a single refresh.
    private var activeRefresh: Task<Tokens, Error>?

    /// Creates a new token refresh middleware.
    /// - Parameters:
    ///   - authMiddleware: The authentication middleware whose tokens will be updated on refresh.
    ///   - refreshHandler: A closure that performs the token refresh and returns new tokens.
    public init(
        authMiddleware: AuthenticationMiddleware,
        refreshHandler: @escaping RefreshHandler
    ) {
        self.authMiddleware = authMiddleware
        self.refreshHandler = refreshHandler
    }

    // MARK: - ClientMiddleware

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)

        // Don't attempt refresh for the refresh endpoint itself (avoid infinite loop)
        // or for non-401 responses
        guard response.status == .unauthorized,
              operationID != "refresh_access_token_v1_auth_refresh_post"
        else {
            return (response, responseBody)
        }

        // Refresh the token (coalescing concurrent requests)
        let tokens = try await refreshTokenCoalesced()

        // Update the auth middleware with new tokens
        await authMiddleware.setTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )

        // Retry the original request — AuthenticationMiddleware (downstream) will inject the new token
        return try await next(request, body, baseURL)
    }

    // MARK: - Private

    /// Coalesces concurrent refresh attempts into a single network call.
    private func refreshTokenCoalesced() async throws -> Tokens {
        if let existing = activeRefresh {
            return try await existing.value
        }

        let task = Task { [authMiddleware, refreshHandler] in
            try await refreshHandler(authMiddleware)
        }
        activeRefresh = task

        do {
            let tokens = try await task.value
            activeRefresh = nil
            return tokens
        } catch {
            activeRefresh = nil
            throw error
        }
    }
}
