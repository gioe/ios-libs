import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Cache eviction policy for the image cache
public enum CacheEvictionPolicy: Sendable {
    /// Least recently used items are evicted first (default)
    case lru
    /// Items are evicted after a fixed time-to-live interval
    case ttl(TimeInterval)
}

/// Configuration for `ImageCache`
public struct ImageCacheConfiguration: Sendable {
    /// Maximum number of images to hold in memory
    public var memoryCountLimit: Int
    /// Maximum total bytes for the memory cache (0 = no limit)
    public var memoryBytesLimit: Int
    /// Maximum total bytes for the disk cache (default 100 MB)
    public var diskBytesLimit: Int
    /// Eviction policy
    public var evictionPolicy: CacheEvictionPolicy

    public init(
        memoryCountLimit: Int = 100,
        memoryBytesLimit: Int = 50 * 1024 * 1024,
        diskBytesLimit: Int = 100 * 1024 * 1024,
        evictionPolicy: CacheEvictionPolicy = .lru
    ) {
        self.memoryCountLimit = memoryCountLimit
        self.memoryBytesLimit = memoryBytesLimit
        self.diskBytesLimit = diskBytesLimit
        self.evictionPolicy = evictionPolicy
    }
}

/// Protocol for image caching, enabling test substitution
public protocol ImageCacheProtocol: Sendable {
    func image(for url: URL) async -> PlatformImage?
    func store(_ image: PlatformImage, for url: URL) async
    func remove(for url: URL) async
    func clearMemory() async
    func clearDisk() async
}

/// Thread-safe image cache with in-memory and disk layers
public actor ImageCache: ImageCacheProtocol {
    public static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, PlatformImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let configuration: ImageCacheConfiguration

    // MARK: - Init

    public init(configuration: ImageCacheConfiguration = .init()) {
        self.configuration = configuration
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheURL = caches.appendingPathComponent("SharedKit/ImageCache", isDirectory: true)

        memoryCache.countLimit = configuration.memoryCountLimit
        memoryCache.totalCostLimit = configuration.memoryBytesLimit

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    public func image(for url: URL) async -> PlatformImage? {
        let key = cacheKey(for: url)

        // 1. Memory hit
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Disk hit
        let filePath = diskPath(for: key)
        guard fileManager.fileExists(atPath: filePath.path) else { return nil }

        // TTL check
        if case .ttl(let interval) = configuration.evictionPolicy {
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath.path),
               let modified = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modified) > interval {
                try? fileManager.removeItem(at: filePath)
                return nil
            }
        }

        guard let data = try? Data(contentsOf: filePath),
              let image = PlatformImage(data: data) else {
            return nil
        }

        // Promote to memory
        memoryCache.setObject(image, forKey: key as NSString)
        return image
    }

    public func store(_ image: PlatformImage, for url: URL) async {
        let key = cacheKey(for: url)

        // Memory
        memoryCache.setObject(image, forKey: key as NSString)

        // Disk
        #if canImport(UIKit)
        guard let data = image.pngData() else { return }
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        #endif
        let filePath = diskPath(for: key)
        try? data.write(to: filePath, options: .atomic)

        await evictDiskIfNeeded()
    }

    public func remove(for url: URL) async {
        let key = cacheKey(for: url)
        memoryCache.removeObject(forKey: key as NSString)
        let filePath = diskPath(for: key)
        try? fileManager.removeItem(at: filePath)
    }

    public func clearMemory() async {
        memoryCache.removeAllObjects()
    }

    public func clearDisk() async {
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        // Simple hash — SHA256 via CryptoKit would be nicer but this avoids the import
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    private func diskPath(for key: String) -> URL {
        diskCacheURL.appendingPathComponent(key)
    }

    private func evictDiskIfNeeded() async {
        guard let enumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var files: [(url: URL, date: Date, size: Int)] = []
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { continue }
            files.append((fileURL, date, size))
            totalSize += size
        }

        guard totalSize > configuration.diskBytesLimit else { return }

        // Evict oldest first
        files.sort { $0.date < $1.date }
        for file in files {
            try? fileManager.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= configuration.diskBytesLimit { break }
        }
    }
}
