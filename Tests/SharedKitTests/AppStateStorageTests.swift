import Testing
import Foundation
@testable import SharedKit

@Suite("AppStateStorage")
struct AppStateStorageTests {

    // Use a unique suite name to avoid cross-test pollution
    private func makeSUT() -> AppStateStorage {
        let suiteName = "AppStateStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppStateStorage(userDefaults: defaults)
    }

    // MARK: - Protocol Conformance

    @Test("Conforms to AppStateStorageProtocol")
    func protocolConformance() {
        let storage: any AppStateStorageProtocol = makeSUT()
        #expect(storage is AppStateStorage)
    }

    // MARK: - Native Types (stored directly)

    @Test("String value round-trips")
    func stringRoundTrip() {
        let storage = makeSUT()
        storage.setValue("hello", forKey: "key")
        let result = storage.getValue(forKey: "key", as: String.self)
        #expect(result == "hello")
    }

    @Test("Int value round-trips")
    func intRoundTrip() {
        let storage = makeSUT()
        storage.setValue(42, forKey: "key")
        let result = storage.getValue(forKey: "key", as: Int.self)
        #expect(result == 42)
    }

    @Test("Bool value round-trips")
    func boolRoundTrip() {
        let storage = makeSUT()
        storage.setValue(true, forKey: "key")
        let result = storage.getValue(forKey: "key", as: Bool.self)
        #expect(result == true)
    }

    @Test("Double value round-trips")
    func doubleRoundTrip() {
        let storage = makeSUT()
        storage.setValue(3.14, forKey: "key")
        let result = storage.getValue(forKey: "key", as: Double.self)
        #expect(result == 3.14)
    }

    @Test("Data value round-trips")
    func dataRoundTrip() {
        let storage = makeSUT()
        let data = Data([0x01, 0x02, 0x03])
        storage.setValue(data, forKey: "key")
        let result = storage.getValue(forKey: "key", as: Data.self)
        #expect(result == data)
    }

    // MARK: - Complex Codable Types (JSON encoded)

    @Test("Codable struct round-trips via JSON")
    func codableStructRoundTrip() {
        let storage = makeSUT()
        let value = TestCodable(name: "test", count: 5)
        storage.setValue(value, forKey: "key")
        let result = storage.getValue(forKey: "key", as: TestCodable.self)
        #expect(result == value)
    }

    @Test("Array of strings round-trips via JSON")
    func arrayRoundTrip() {
        let storage = makeSUT()
        let value = ["a", "b", "c"]
        storage.setValue(value, forKey: "key")
        let result = storage.getValue(forKey: "key", as: [String].self)
        #expect(result == value)
    }

    // MARK: - Missing / Remove / Has

    @Test("getValue returns nil for missing key")
    func getMissingReturnsNil() {
        let storage = makeSUT()
        let result = storage.getValue(forKey: "nonexistent", as: String.self)
        #expect(result == nil)
    }

    @Test("getValue returns nil for missing Int key")
    func getMissingIntReturnsNil() {
        let storage = makeSUT()
        let result = storage.getValue(forKey: "nonexistent", as: Int.self)
        #expect(result == nil)
    }

    @Test("getValue returns nil for missing Bool key")
    func getMissingBoolReturnsNil() {
        let storage = makeSUT()
        let result = storage.getValue(forKey: "nonexistent", as: Bool.self)
        #expect(result == nil)
    }

    @Test("getValue returns nil for missing Double key")
    func getMissingDoubleReturnsNil() {
        let storage = makeSUT()
        let result = storage.getValue(forKey: "nonexistent", as: Double.self)
        #expect(result == nil)
    }

    @Test("removeValue removes stored value")
    func removeValue() {
        let storage = makeSUT()
        storage.setValue("hello", forKey: "key")
        storage.removeValue(forKey: "key")
        let result = storage.getValue(forKey: "key", as: String.self)
        #expect(result == nil)
    }

    @Test("hasValue returns true for existing key")
    func hasValueTrue() {
        let storage = makeSUT()
        storage.setValue(99, forKey: "key")
        #expect(storage.hasValue(forKey: "key") == true)
    }

    @Test("hasValue returns false for missing key")
    func hasValueFalse() {
        let storage = makeSUT()
        #expect(storage.hasValue(forKey: "key") == false)
    }

    @Test("hasValue returns false after removal")
    func hasValueAfterRemoval() {
        let storage = makeSUT()
        storage.setValue("x", forKey: "key")
        storage.removeValue(forKey: "key")
        #expect(storage.hasValue(forKey: "key") == false)
    }

    // MARK: - Overwrite

    @Test("setValue overwrites previous value")
    func overwrite() {
        let storage = makeSUT()
        storage.setValue("first", forKey: "key")
        storage.setValue("second", forKey: "key")
        let result = storage.getValue(forKey: "key", as: String.self)
        #expect(result == "second")
    }
}

// MARK: - Test Helpers

private struct TestCodable: Codable, Equatable {
    let name: String
    let count: Int
}
