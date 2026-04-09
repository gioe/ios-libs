import Foundation

/// Token pair returned by authentication operations.
public struct AuthTokens: Sendable {
    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// Protocol defining the authentication API contract.
///
/// Consumer apps implement this protocol to connect auth views to their backend.
/// The protocol is intentionally transport-agnostic — implementations may use
/// `APIClient`, `URLSession`, or any other networking layer.
///
/// ## Usage
/// ```swift
/// class MyAuthService: AuthServiceProtocol {
///     func signIn(email: String, password: String) async throws -> AuthTokens {
///         let response = try await client.loginUserV1AuthLoginPost(
///             body: .json(.init(email: email, password: password))
///         )
///         // Parse response and return tokens
///     }
///
///     func signUp(name: String, email: String, password: String) async throws -> AuthTokens {
///         // Call registration endpoint
///     }
/// }
/// ```
public protocol AuthServiceProtocol: Sendable {
    /// Signs in with email and password credentials.
    /// - Returns: Token pair on success
    /// - Throws: On network or authentication failure
    func signIn(email: String, password: String) async throws -> AuthTokens

    /// Registers a new account and returns tokens.
    /// - Returns: Token pair on success
    /// - Throws: On network or registration failure
    func signUp(name: String, email: String, password: String) async throws -> AuthTokens
}
