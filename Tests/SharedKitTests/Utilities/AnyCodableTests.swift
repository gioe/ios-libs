import Foundation
import Testing

@testable import SharedKit

@Suite("AnyCodable")
struct AnyCodableTests {

    // MARK: - Round-trip encoding/decoding

    @Test("Round-trips Int")
    func roundTripInt() throws {
        let original = AnyCodable(42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value as? Int == 42)
    }

    @Test("Round-trips Double")
    func roundTripDouble() throws {
        let original = AnyCodable(3.14)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value as? Double == 3.14)
    }

    @Test("Round-trips Bool")
    func roundTripBool() throws {
        let original = AnyCodable(true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value as? Bool == true)
    }

    @Test("Round-trips String")
    func roundTripString() throws {
        let original = AnyCodable("hello")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value as? String == "hello")
    }

    @Test("Round-trips Array")
    func roundTripArray() throws {
        let original = AnyCodable([1, "two", true] as [Any])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let array = try #require(decoded.value as? [Any])
        #expect(array.count == 3)
        #expect(array[0] as? Int == 1)
        #expect(array[1] as? String == "two")
        #expect(array[2] as? Bool == true)
    }

    @Test("Round-trips Dictionary")
    func roundTripDictionary() throws {
        let original = AnyCodable(["key": "value", "count": 5] as [String: Any])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let dict = try #require(decoded.value as? [String: Any])
        #expect(dict["key"] as? String == "value")
        #expect(dict["count"] as? Int == 5)
    }

    @Test("Round-trips nil as NSNull")
    func roundTripNil() throws {
        let original = AnyCodable(NSNull())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value is NSNull)
    }

    // MARK: - Equatable

    @Test("Equal values are equal")
    func equatable() {
        #expect(AnyCodable(42) == AnyCodable(42))
        #expect(AnyCodable("hello") == AnyCodable("hello"))
        #expect(AnyCodable(true) == AnyCodable(true))
        #expect(AnyCodable(3.14) == AnyCodable(3.14))
        #expect(AnyCodable(NSNull()) == AnyCodable(NSNull()))
    }

    @Test("Unequal values are not equal")
    func notEquatable() {
        #expect(AnyCodable(42) != AnyCodable(43))
        #expect(AnyCodable("a") != AnyCodable("b"))
        #expect(AnyCodable(true) != AnyCodable(false))
        #expect(AnyCodable(42) != AnyCodable("42"))
    }

    @Test("Array equality")
    func arrayEquality() {
        let a = AnyCodable([1, 2, 3] as [Any])
        let b = AnyCodable([1, 2, 3] as [Any])
        let c = AnyCodable([1, 2] as [Any])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Dictionary equality")
    func dictionaryEquality() {
        let a = AnyCodable(["k": "v"] as [String: Any])
        let b = AnyCodable(["k": "v"] as [String: Any])
        let c = AnyCodable(["k": "other"] as [String: Any])
        #expect(a == b)
        #expect(a != c)
    }
}
