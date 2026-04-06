import Foundation
@testable import SharedKit
import Testing

@Suite("KeychainStorage")
struct KeychainStorageTests {
    private func freshKeychain() -> KeychainStorage {
        KeychainStorage(serviceName: "test.keychain.\(UUID().uuidString)")
    }

    // MARK: - Save and Retrieve

    @Test("save and retrieve returns the stored value")
    func saveAndRetrieve() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("my_secret", forKey: "token")
        let retrieved = try keychain.retrieve(forKey: "token")
        #expect(retrieved == "my_secret")
    }

    @Test("save overwrites existing value for same key")
    func saveOverwrites() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("first", forKey: "key")
        try keychain.save("second", forKey: "key")
        let retrieved = try keychain.retrieve(forKey: "key")
        #expect(retrieved == "second")
    }

    @Test("save multiple keys stores independently")
    func multipleKeys() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("value_a", forKey: "key_a")
        try keychain.save("value_b", forKey: "key_b")

        #expect(try keychain.retrieve(forKey: "key_a") == "value_a")
        #expect(try keychain.retrieve(forKey: "key_b") == "value_b")
    }

    @Test("save empty string and retrieve it")
    func saveEmptyString() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("", forKey: "empty")
        let retrieved = try keychain.retrieve(forKey: "empty")
        #expect(retrieved == "")
    }

    @Test("save unicode value and retrieve it")
    func saveUnicode() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        let unicodeValue = "héllo wörld 🔐"
        try keychain.save(unicodeValue, forKey: "unicode")
        let retrieved = try keychain.retrieve(forKey: "unicode")
        #expect(retrieved == unicodeValue)
    }

    // MARK: - Retrieve

    @Test("retrieve nonexistent key returns nil")
    func retrieveNonexistent() throws {
        let keychain = freshKeychain()
        let retrieved = try keychain.retrieve(forKey: "nonexistent")
        #expect(retrieved == nil)
    }

    // MARK: - Delete

    @Test("delete removes the stored value")
    func delete() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("value", forKey: "key")
        try keychain.delete(forKey: "key")
        let retrieved = try keychain.retrieve(forKey: "key")
        #expect(retrieved == nil)
    }

    @Test("delete nonexistent key does not throw")
    func deleteNonexistent() throws {
        let keychain = freshKeychain()
        try keychain.delete(forKey: "nonexistent")
    }

    @Test("delete only removes the targeted key")
    func deleteTargeted() throws {
        let keychain = freshKeychain()
        defer { try? keychain.deleteAll() }

        try keychain.save("keep", forKey: "keep_key")
        try keychain.save("remove", forKey: "remove_key")
        try keychain.delete(forKey: "remove_key")

        #expect(try keychain.retrieve(forKey: "keep_key") == "keep")
        #expect(try keychain.retrieve(forKey: "remove_key") == nil)
    }

    // MARK: - Delete All

    @Test("deleteAll removes stored value")
    func deleteAll() throws {
        let keychain = freshKeychain()

        try keychain.save("a", forKey: "key_a")
        try keychain.deleteAll()

        #expect(try keychain.retrieve(forKey: "key_a") == nil)
    }

    @Test("deleteAll on empty keychain does not throw")
    func deleteAllEmpty() throws {
        let keychain = freshKeychain()
        try keychain.deleteAll()
    }

    // MARK: - Service Isolation

    @Test("different service names are isolated")
    func serviceIsolation() throws {
        let keychainA = KeychainStorage(serviceName: "test.service.A.\(UUID().uuidString)")
        let keychainB = KeychainStorage(serviceName: "test.service.B.\(UUID().uuidString)")
        defer {
            try? keychainA.deleteAll()
            try? keychainB.deleteAll()
        }

        try keychainA.save("value_a", forKey: "shared_key")
        try keychainB.save("value_b", forKey: "shared_key")

        #expect(try keychainA.retrieve(forKey: "shared_key") == "value_a")
        #expect(try keychainB.retrieve(forKey: "shared_key") == "value_b")
    }
}
