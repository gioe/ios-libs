import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import SharedKit

@Suite("ImageCache")
struct ImageCacheTests {

    // MARK: - Helpers

    private func makeCache(
        memoryCountLimit: Int = 10,
        diskBytesLimit: Int = 1024 * 1024,
        evictionPolicy: CacheEvictionPolicy = .lru
    ) -> ImageCache {
        let uniqueDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageCacheTests/\(UUID().uuidString)", isDirectory: true)
        return ImageCache(configuration: .init(
            memoryCountLimit: memoryCountLimit,
            memoryBytesLimit: 0,
            diskBytesLimit: diskBytesLimit,
            evictionPolicy: evictionPolicy,
            diskCacheURL: uniqueDir
        ))
    }

    private func makeTestImage() -> PlatformImage {
        #if canImport(UIKit)
        // 1x1 red pixel
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        return image
        #endif
    }

    // MARK: - Tests

    @Test("Store and retrieve from cache")
    func storeAndRetrieve() async {
        let cache = makeCache()
        let url = URL(string: "https://example.com/image.png")!
        let image = makeTestImage()

        await cache.store(image, for: url)
        let retrieved = await cache.image(for: url)

        #expect(retrieved != nil)
        await cache.clearDisk()
    }

    @Test("Returns nil for uncached URL")
    func missReturnsNil() async {
        let cache = makeCache()
        let url = URL(string: "https://example.com/missing.png")!

        let result = await cache.image(for: url)

        #expect(result == nil)
        await cache.clearDisk()
    }

    @Test("Remove evicts from cache")
    func removeEvicts() async {
        let cache = makeCache()
        let url = URL(string: "https://example.com/remove.png")!

        await cache.store(makeTestImage(), for: url)
        await cache.remove(for: url)
        let result = await cache.image(for: url)

        #expect(result == nil)
        await cache.clearDisk()
    }

    @Test("Clear memory preserves disk")
    func clearMemoryKeepsDisk() async {
        let cache = makeCache()
        let url = URL(string: "https://example.com/persist.png")!

        await cache.store(makeTestImage(), for: url)
        await cache.clearMemory()

        // Should still be found on disk
        let result = await cache.image(for: url)
        #expect(result != nil)

        // Clean up
        await cache.clearDisk()
    }

    @Test("Clear disk removes all cached files")
    func clearDisk() async {
        let cache = makeCache()
        let url = URL(string: "https://example.com/diskonly.png")!

        await cache.store(makeTestImage(), for: url)
        await cache.clearMemory()
        await cache.clearDisk()

        let result = await cache.image(for: url)
        #expect(result == nil)
    }

    @Test("TTL eviction removes expired entries")
    func ttlEviction() async throws {
        let cache = makeCache(evictionPolicy: .ttl(0.1))
        let url = URL(string: "https://example.com/ttl.png")!

        await cache.store(makeTestImage(), for: url)
        await cache.clearMemory()

        // Wait for TTL to expire
        try await Task.sleep(for: .milliseconds(200))

        let result = await cache.image(for: url)
        #expect(result == nil)

        await cache.clearDisk()
    }

    @Test("Default configuration has sensible values")
    func defaultConfiguration() {
        let config = ImageCacheConfiguration()
        #expect(config.memoryCountLimit == 100)
        #expect(config.memoryBytesLimit == 50 * 1024 * 1024)
        #expect(config.diskBytesLimit == 100 * 1024 * 1024)
    }
}
