import Combine
import Foundation

/// Manages authentication token persistence using secure storage.
///
/// `AuthTokenManager` bridges the gap between in-memory token state (used by middleware)
/// and persistent secure storage (Keychain). It publishes authentication state changes
/// so views can reactively update.
///
/// ## Usage
/// ```swift
/// let keychain = KeychainStorage()
/// let tokenManager = AuthTokenManager(secureStorage: keychain)
///
/// // Store tokens after login
/// try tokenManager.storeTokens(accessToken: "eyJ...", refreshToken: "eyJ...")
///
/// // Check auth state
/// if tokenManager.isAuthenticated {
///     // User is signed in
/// }
///
/// // Clear on sign-out
/// try tokenManager.clearTokens()
/// ```
@MainActor
public class AuthTokenManager: ObservableObject {
    // MARK: - Constants

    private enum Keys {
        static let accessToken = "auth_access_token"
        static let refreshToken = "auth_refresh_token"
    }

    // MARK: - Published Properties

    /// Whether the user currently has stored auth tokens
    @Published public private(set) var isAuthenticated: Bool = false

    // MARK: - Dependencies

    private let secureStorage: SecureStorageProtocol

    // MARK: - Initialization

    /// Creates a new token manager backed by the given secure storage.
    /// - Parameter secureStorage: The storage backend for token persistence (typically `KeychainStorage`).
    public init(secureStorage: SecureStorageProtocol) {
        self.secureStorage = secureStorage
        // Check for existing tokens on init
        isAuthenticated = (try? secureStorage.retrieve(forKey: Keys.accessToken)) != nil
    }

    // MARK: - Token Operations

    /// Stores both access and refresh tokens securely.
    /// - Parameters:
    ///   - accessToken: The JWT access token
    ///   - refreshToken: The JWT refresh token
    public func storeTokens(accessToken: String, refreshToken: String) throws {
        try secureStorage.save(accessToken, forKey: Keys.accessToken)
        try secureStorage.save(refreshToken, forKey: Keys.refreshToken)
        isAuthenticated = true
    }

    /// Retrieves the stored access token, if any.
    public func retrieveAccessToken() -> String? {
        try? secureStorage.retrieve(forKey: Keys.accessToken)
    }

    /// Retrieves the stored refresh token, if any.
    public func retrieveRefreshToken() -> String? {
        try? secureStorage.retrieve(forKey: Keys.refreshToken)
    }

    /// Clears all stored auth tokens (sign-out).
    public func clearTokens() throws {
        try secureStorage.delete(forKey: Keys.accessToken)
        try secureStorage.delete(forKey: Keys.refreshToken)
        isAuthenticated = false
    }
}
