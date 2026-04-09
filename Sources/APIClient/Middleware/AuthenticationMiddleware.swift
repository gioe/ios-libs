import Foundation
import HTTPTypes
import OpenAPIRuntime
import SharedKit

/// A middleware that adds authentication tokens to outgoing requests.
///
/// This middleware injects Bearer tokens into request headers for authenticated endpoints.
/// It supports both access tokens (for regular requests) and refresh tokens (for token refresh).
///
/// When initialized with a `SecureStorageProtocol`, tokens are also persisted to secure storage
/// (e.g., Keychain) so they survive app restarts.
///
/// ## Usage
/// ```swift
/// let authMiddleware = AuthenticationMiddleware()
/// let client = Client(
///     serverURL: serverURL,
///     transport: URLSessionTransport(),
///     middlewares: [authMiddleware]
/// )
///
/// // Set the access token after login
/// await authMiddleware.setAccessToken("eyJhbG...")
///
/// // Or use persistent storage:
/// let authMiddleware = AuthenticationMiddleware(secureStorage: KeychainStorage())
/// // Tokens are automatically loaded from storage on init and persisted on set
/// ```
public actor AuthenticationMiddleware: ClientMiddleware {
    /// The current access token, if any
    private var accessToken: String?

    /// The current refresh token, if any (used only for token refresh endpoint)
    private var refreshToken: String?

    /// Optional persistent storage for tokens (e.g., KeychainStorage)
    private let secureStorage: SecureStorageProtocol?

    private enum StorageKeys {
        static let accessToken = "auth_access_token"
        static let refreshToken = "auth_refresh_token"
    }

    /// Creates a new authentication middleware
    /// - Parameters:
    ///   - accessToken: Initial access token (optional)
    ///   - refreshToken: Initial refresh token (optional)
    ///   - secureStorage: Optional persistent storage. When provided, tokens are loaded on init
    ///     and persisted on every set/clear operation.
    public init(
        accessToken: String? = nil,
        refreshToken: String? = nil,
        secureStorage: SecureStorageProtocol? = nil
    ) {
        self.secureStorage = secureStorage
        // Load from storage if available, falling back to provided values
        if let storage = secureStorage {
            self.accessToken = (try? storage.retrieve(forKey: StorageKeys.accessToken)) ?? accessToken
            self.refreshToken = (try? storage.retrieve(forKey: StorageKeys.refreshToken)) ?? refreshToken
        } else {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    /// Sets the access token for authenticated requests
    /// - Parameter token: The JWT access token, or nil to clear
    public func setAccessToken(_ token: String?) {
        accessToken = token
        persistToken(token, forKey: StorageKeys.accessToken)
    }

    /// Sets the refresh token for token refresh operations
    /// - Parameter token: The JWT refresh token, or nil to clear
    public func setRefreshToken(_ token: String?) {
        refreshToken = token
        persistToken(token, forKey: StorageKeys.refreshToken)
    }

    /// Sets both tokens at once (convenience method for login/register responses)
    /// - Parameters:
    ///   - accessToken: The JWT access token
    ///   - refreshToken: The JWT refresh token
    public func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        persistToken(accessToken, forKey: StorageKeys.accessToken)
        persistToken(refreshToken, forKey: StorageKeys.refreshToken)
    }

    /// Clears both tokens (for logout)
    public func clearTokens() {
        accessToken = nil
        refreshToken = nil
        persistToken(nil, forKey: StorageKeys.accessToken)
        persistToken(nil, forKey: StorageKeys.refreshToken)
    }

    /// Whether the middleware has a valid access token
    public var hasAccessToken: Bool {
        accessToken != nil
    }

    /// The current access token (for external access if needed)
    public func getAccessToken() -> String? {
        accessToken
    }

    // MARK: - Private

    private func persistToken(_ token: String?, forKey key: String) {
        guard let storage = secureStorage else { return }
        if let token {
            try? storage.save(token, forKey: key)
        } else {
            try? storage.delete(forKey: key)
        }
    }

    // MARK: - ClientMiddleware

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request

        // Check if this is the token refresh endpoint
        let isRefreshEndpoint = operationID == "refresh_access_token_v1_auth_refresh_post"

        // Add Authorization header based on endpoint type
        if isRefreshEndpoint, let refreshToken {
            modifiedRequest.headerFields[.authorization] = "Bearer \(refreshToken)"
        } else if let accessToken {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }

        return try await next(modifiedRequest, body, baseURL)
    }
}
