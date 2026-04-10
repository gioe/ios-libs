import Testing
import Foundation

// MARK: - Mirror of consumer-defined types (LaughTrack)

/// Operation types that can be queued for offline execution.
private enum LaughTrackOfflineOperation: String, Codable, Hashable, Sendable {
    case toggleFavorite
}

/// Payload for the toggleFavorite operation.
private struct ToggleFavoritePayload: Codable, Sendable, Equatable {
    let comedianId: String
    let isFavorite: Bool
}

// MARK: - Tests

@Suite("Offline Operation Types")
struct OfflineOperationTypesTests {

    // MARK: - LaughTrackOfflineOperation raw values

    @Test("toggleFavorite raw value matches expected string")
    func toggleFavoriteRawValue() {
        #expect(LaughTrackOfflineOperation.toggleFavorite.rawValue == "toggleFavorite")
    }

    @Test("LaughTrackOfflineOperation initializes from valid raw value")
    func initFromRawValue() {
        let op = LaughTrackOfflineOperation(rawValue: "toggleFavorite")
        #expect(op == .toggleFavorite)
    }

    @Test("LaughTrackOfflineOperation returns nil for invalid raw value")
    func initFromInvalidRawValue() {
        let op = LaughTrackOfflineOperation(rawValue: "nonExistent")
        #expect(op == nil)
    }

    @Test("LaughTrackOfflineOperation encodes to its raw value string")
    func operationEncodesToRawValue() throws {
        let encoded = try JSONEncoder().encode(LaughTrackOfflineOperation.toggleFavorite)
        let jsonString = String(data: encoded, encoding: .utf8)
        #expect(jsonString == "\"toggleFavorite\"")
    }

    @Test("LaughTrackOfflineOperation decodes from raw value string")
    func operationDecodesFromRawValue() throws {
        let json = Data("\"toggleFavorite\"".utf8)
        let decoded = try JSONDecoder().decode(LaughTrackOfflineOperation.self, from: json)
        #expect(decoded == .toggleFavorite)
    }

    // MARK: - ToggleFavoritePayload Codable round-trip

    @Test("ToggleFavoritePayload round-trip with isFavorite true")
    func roundTripFavoriteTrue() throws {
        let payload = ToggleFavoritePayload(comedianId: "comedian-123", isFavorite: true)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ToggleFavoritePayload.self, from: data)
        #expect(decoded == payload)
    }

    @Test("ToggleFavoritePayload round-trip with isFavorite false")
    func roundTripFavoriteFalse() throws {
        let payload = ToggleFavoritePayload(comedianId: "comedian-456", isFavorite: false)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ToggleFavoritePayload.self, from: data)
        #expect(decoded == payload)
    }

    @Test("ToggleFavoritePayload JSON keys match expected names")
    func jsonKeyNames() throws {
        let payload = ToggleFavoritePayload(comedianId: "abc", isFavorite: true)
        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["comedianId"] as? String == "abc")
        #expect(dict?["isFavorite"] as? Bool == true)
    }

    // MARK: - Edge cases

    @Test("ToggleFavoritePayload with empty comedianId")
    func emptyComedianId() throws {
        let payload = ToggleFavoritePayload(comedianId: "", isFavorite: true)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ToggleFavoritePayload.self, from: data)
        #expect(decoded == payload)
        #expect(decoded.comedianId == "")
    }

    @Test("ToggleFavoritePayload with special characters in comedianId")
    func specialCharactersInComedianId() throws {
        let specialIds = [
            "comedian/with/slashes",
            "comedian with spaces",
            "comedian@#$%^&*()",
            "comedian\"with\"quotes",
            "comedian\\backslash",
            "comedian\nnewline",
            "comedian\ttab",
            "🎭comedian-emoji",
            "日本語comedian",
        ]

        for id in specialIds {
            let payload = ToggleFavoritePayload(comedianId: id, isFavorite: true)
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(ToggleFavoritePayload.self, from: data)
            #expect(decoded.comedianId == id, "Round-trip failed for comedianId: \(id)")
        }
    }

    @Test("ToggleFavoritePayload with very long comedianId")
    func longComedianId() throws {
        let longId = String(repeating: "a", count: 10_000)
        let payload = ToggleFavoritePayload(comedianId: longId, isFavorite: false)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ToggleFavoritePayload.self, from: data)
        #expect(decoded == payload)
    }
}
