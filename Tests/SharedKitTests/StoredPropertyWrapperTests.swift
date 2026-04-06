import Testing
import Foundation
@testable import SharedKit

@Suite("Stored Property Wrapper")
struct StoredPropertyWrapperTests {

    // MARK: - Helpers

    private func freshDefaults() -> UserDefaults {
        let suiteName = "test.stored.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
    }

    private func freshKeychain() -> KeychainStorage {
        KeychainStorage(serviceName: "test.stored.\(UUID().uuidString)")
    }

    // MARK: - UserDefaults (non-secure) tests

    @Test("Stores and retrieves a simple value via UserDefaults")
    func userDefaultsRoundTrip() {
        let defaults = freshDefaults()
        let key = "test_bool_\(UUID().uuidString)"

        @Stored(wrappedValue: false, key, defaults: defaults)
        var flag: Bool

        #expect(flag == false)
        flag = true
        #expect(flag == true)
    }

    @Test("Returns default value when key is absent")
    func userDefaultsDefaultValue() {
        let defaults = freshDefaults()
        let key = "missing_\(UUID().uuidString)"

        @Stored(wrappedValue: 42, key, defaults: defaults)
        var number: Int

        #expect(number == 42)
    }

    @Test("Stores and retrieves a Codable struct via UserDefaults")
    func userDefaultsCodableStruct() {
        let defaults = freshDefaults()
        let key = "prefs_\(UUID().uuidString)"

        struct Prefs: Codable, Equatable {
            var theme: String
            var fontSize: Int
        }

        @Stored(wrappedValue: Prefs(theme: "light", fontSize: 14), key, defaults: defaults)
        var prefs: Prefs

        #expect(prefs == Prefs(theme: "light", fontSize: 14))
        prefs = Prefs(theme: "dark", fontSize: 18)
        #expect(prefs == Prefs(theme: "dark", fontSize: 18))
    }

    @Test("Handles optional values with nil default")
    func userDefaultsOptional() {
        let defaults = freshDefaults()
        let key = "opt_\(UUID().uuidString)"

        @Stored(key, defaults: defaults)
        var name: String?

        #expect(name == nil)
        name = "Alice"
        #expect(name == "Alice")
        name = nil
        #expect(name == nil)
    }

    // MARK: - Keychain (secure) tests

    @Test("Stores and retrieves a value via Keychain")
    func keychainRoundTrip() throws {
        let keychain = freshKeychain()
        let key = "token_\(UUID().uuidString)"

        @Stored(wrappedValue: "", key, secure: true, secureStorage: keychain)
        var token: String

        #expect(token == "")
        token = "abc123"
        #expect(token == "abc123")

        // Clean up
        try keychain.deleteAll()
    }

    @Test("Handles optional Keychain values")
    func keychainOptional() throws {
        let keychain = freshKeychain()
        let key = "secret_\(UUID().uuidString)"

        @Stored(key, secure: true, secureStorage: keychain)
        var secret: String?

        #expect(secret == nil)
        secret = "s3cr3t"
        #expect(secret == "s3cr3t")
        secret = nil
        #expect(secret == nil)

        // Clean up
        try keychain.deleteAll()
    }

    @Test("Stores Codable struct in Keychain")
    func keychainCodableStruct() throws {
        let keychain = freshKeychain()
        let key = "creds_\(UUID().uuidString)"

        struct Credentials: Codable, Equatable {
            var username: String
            var apiKey: String
        }

        @Stored(
            wrappedValue: Credentials(username: "", apiKey: ""),
            key,
            secure: true,
            secureStorage: keychain
        )
        var creds: Credentials

        creds = Credentials(username: "user1", apiKey: "key-xyz")
        #expect(creds == Credentials(username: "user1", apiKey: "key-xyz"))

        // Clean up
        try keychain.deleteAll()
    }
}
