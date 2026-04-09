import Foundation
@testable import SharedKit
import Testing

/// In-memory mock of SecureStorageProtocol for testing
final class MockSecureStorage: SecureStorageProtocol, @unchecked Sendable {
    private var store: [String: String] = [:]
    var shouldThrow = false

    func save(_ value: String, forKey key: String) throws {
        if shouldThrow { throw KeychainError.saveFailed(status: -1) }
        store[key] = value
    }

    func retrieve(forKey key: String) throws -> String? {
        if shouldThrow { throw KeychainError.retrievalFailed(status: -1) }
        return store[key]
    }

    func delete(forKey key: String) throws {
        if shouldThrow { throw KeychainError.deletionFailed(status: -1) }
        store.removeValue(forKey: key)
    }

    func deleteAll() throws {
        if shouldThrow { throw KeychainError.deletionFailed(status: -1) }
        store.removeAll()
    }
}

@Suite("AuthTokenManager")
struct AuthTokenManagerTests {

    @Test("storeTokens persists both tokens and sets isAuthenticated")
    @MainActor
    func storeTokensSetsAuthenticated() throws {
        let storage = MockSecureStorage()
        let manager = AuthTokenManager(secureStorage: storage)

        try manager.storeTokens(accessToken: "access123", refreshToken: "refresh456")

        #expect(manager.isAuthenticated == true)
        #expect(manager.retrieveAccessToken() == "access123")
        #expect(manager.retrieveRefreshToken() == "refresh456")
    }

    @Test("clearTokens removes tokens and unsets isAuthenticated")
    @MainActor
    func clearTokensUnsetsAuthenticated() throws {
        let storage = MockSecureStorage()
        let manager = AuthTokenManager(secureStorage: storage)

        try manager.storeTokens(accessToken: "access", refreshToken: "refresh")
        try manager.clearTokens()

        #expect(manager.isAuthenticated == false)
        #expect(manager.retrieveAccessToken() == nil)
        #expect(manager.retrieveRefreshToken() == nil)
    }

    @Test("init with existing tokens sets isAuthenticated true")
    @MainActor
    func initWithExistingTokens() throws {
        let storage = MockSecureStorage()
        try storage.save("existing", forKey: AuthStorageKeys.accessToken)

        let manager = AuthTokenManager(secureStorage: storage)

        #expect(manager.isAuthenticated == true)
    }

    @Test("init without existing tokens sets isAuthenticated false")
    @MainActor
    func initWithoutTokens() {
        let storage = MockSecureStorage()
        let manager = AuthTokenManager(secureStorage: storage)

        #expect(manager.isAuthenticated == false)
    }

    @Test("retrieveAccessToken returns nil when no token stored")
    @MainActor
    func retrieveAccessTokenReturnsNilWhenEmpty() {
        let storage = MockSecureStorage()
        let manager = AuthTokenManager(secureStorage: storage)

        #expect(manager.retrieveAccessToken() == nil)
    }
}
