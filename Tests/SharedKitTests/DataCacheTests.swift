import Testing
import Foundation
@testable import SharedKit

@Suite("DataCache")
struct DataCacheTests {

    // MARK: - Key type used across tests

    private enum TestKey: Hashable, Sendable {
        case alpha
        case beta
        case gamma
    }

    // MARK: - Caching

    @Test("Set and get returns stored value")
    func setAndGet() async {
        let cache = DataCache<TestKey>()
        await cache.set("hello", forKey: .alpha)

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == "hello")
    }

    @Test("Get returns nil for missing key")
    func getMissReturnsNil() async {
        let cache = DataCache<TestKey>()

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == nil)
    }

    @Test("Get returns nil for wrong type")
    func getWrongTypeReturnsNil() async {
        let cache = DataCache<TestKey>()
        await cache.set(42, forKey: .alpha)

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == nil)
    }

    @Test("Set overwrites previous value")
    func setOverwrites() async {
        let cache = DataCache<TestKey>()
        await cache.set("first", forKey: .alpha)
        await cache.set("second", forKey: .alpha)

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == "second")
    }

    // MARK: - TTL Expiration

    @Test("Entry expires after default TTL")
    func defaultTTLExpiration() async throws {
        let cache = DataCache<TestKey>(configuration: .init(defaultTTL: 0.05))
        await cache.set("value", forKey: .alpha)

        try await Task.sleep(for: .milliseconds(100))

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == nil)
    }

    @Test("Per-entry TTL overrides default")
    func perEntryTTL() async throws {
        let cache = DataCache<TestKey>(configuration: .init(defaultTTL: 10))
        await cache.set("short-lived", forKey: .alpha, ttl: 0.05)

        try await Task.sleep(for: .milliseconds(100))

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == nil)
    }

    @Test("Entry is available before TTL expires")
    func entryAvailableBeforeExpiry() async {
        let cache = DataCache<TestKey>(configuration: .init(defaultTTL: 10))
        await cache.set("value", forKey: .alpha)

        let result: String? = await cache.get(forKey: .alpha)
        #expect(result == "value")
    }

    @Test("Remove expired clears only stale entries")
    func removeExpired() async throws {
        let cache = DataCache<TestKey>(configuration: .init(defaultTTL: 10))
        await cache.set("short", forKey: .alpha, ttl: 0.05)
        await cache.set("long", forKey: .beta)

        try await Task.sleep(for: .milliseconds(100))
        await cache.removeExpired()

        let alpha: String? = await cache.get(forKey: .alpha)
        let beta: String? = await cache.get(forKey: .beta)
        #expect(alpha == nil)
        #expect(beta == "long")
    }

    // MARK: - Removal

    @Test("Remove deletes a single entry")
    func removeSingleEntry() async {
        let cache = DataCache<TestKey>()
        await cache.set("a", forKey: .alpha)
        await cache.set("b", forKey: .beta)

        await cache.remove(forKey: .alpha)

        let alpha: String? = await cache.get(forKey: .alpha)
        let beta: String? = await cache.get(forKey: .beta)
        #expect(alpha == nil)
        #expect(beta == "b")
    }

    @Test("RemoveAll clears entire cache")
    func removeAll() async {
        let cache = DataCache<TestKey>()
        await cache.set("a", forKey: .alpha)
        await cache.set("b", forKey: .beta)
        await cache.set("c", forKey: .gamma)

        await cache.removeAll()

        let alpha: String? = await cache.get(forKey: .alpha)
        let beta: String? = await cache.get(forKey: .beta)
        let gamma: String? = await cache.get(forKey: .gamma)
        #expect(alpha == nil)
        #expect(beta == nil)
        #expect(gamma == nil)
    }

    // MARK: - Configuration

    @Test("Default configuration uses 300s TTL")
    func defaultConfiguration() {
        let config = DataCacheConfiguration()
        #expect(config.defaultTTL == 300)
    }
}
