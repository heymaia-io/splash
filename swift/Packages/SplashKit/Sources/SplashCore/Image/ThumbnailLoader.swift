import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import KomgaAPI

/// Decoded image handed to the UI. `CGImage` is immutable, so sharing it across actors is safe.
public struct DecodedImage: @unchecked Sendable {
    public let cgImage: CGImage
    public var pixelSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }
}

/// Thumbnail pipeline — replaces Coil (memory + disk cache) from `komelia-domain/core/image/coil`.
/// [NUEVO] NSCache with a byte budget + LRU disk cache in `Caches/`, early downsampling via
/// `CGImageSourceCreateThumbnailAtIndex`, and in-flight request coalescing.
public actor ThumbnailLoader {
    public struct Configuration: Sendable {
        public var memoryBudgetBytes: Int = 150 * 1024 * 1024
        public var diskBudgetBytes: Int64 = 300 * 1024 * 1024
        public var directory: URL
        public init(directory: URL) { self.directory = directory }

        public static var `default`: Configuration {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            return Configuration(directory: caches.appending(path: "Thumbnails", directoryHint: .isDirectory))
        }
    }

    private struct MemoryKey: Hashable {
        let request: ThumbnailRequest
        let maxPixelSize: Int
    }

    private let api: @Sendable () -> any KomgaApi
    private let offlineApi: @Sendable () -> (any KomgaApi)?
    private let namespace: @Sendable () -> String
    private let configuration: Configuration
    private let memory = NSCache<NSString, CGImageBox>()
    private var memoryKeys: [String: Set<NSString>] = [:]  // cacheKey -> NSCache keys (for invalidation)
    private var inFlight: [MemoryKey: Task<DecodedImage?, Error>] = [:]
    private var writesSinceTrim = 0

    /// - Parameters:
    ///   - api: current API (remote or offline) — read on every fetch, like `komgaApi: StateFlow<KomgaApi>`.
    ///   - offlineApi: fallback used when the server cannot be reached; serves the thumbnail bytes stored
    ///     alongside downloaded books, so covers of downloaded content keep rendering with no connection.
    ///   - namespace: disk-cache partition (server URL), so two servers never share entries.
    public init(
        api: @escaping @Sendable () -> any KomgaApi,
        offlineApi: @escaping @Sendable () -> (any KomgaApi)? = { nil },
        namespace: @escaping @Sendable () -> String,
        configuration: Configuration = .default
    ) {
        self.api = api
        self.offlineApi = offlineApi
        self.namespace = namespace
        self.configuration = configuration
        memory.totalCostLimit = configuration.memoryBudgetBytes
    }

    /// Returns the thumbnail downsampled to fit `maxPixelSize`, or nil when the server has none (404).
    public func image(for request: ThumbnailRequest, maxPixelSize: Int) async throws -> DecodedImage? {
        let key = MemoryKey(request: request, maxPixelSize: maxPixelSize)
        let memoryKey = "\(request.cacheKey)@\(maxPixelSize)" as NSString
        if let cached = memory.object(forKey: memoryKey) { return DecodedImage(cgImage: cached.image) }
        if let running = inFlight[key] { return try await running.value }

        let task = Task<DecodedImage?, Error> {
            let data = try await self.bytes(for: request)
            guard let data else { return nil }
            return Self.decode(data, maxPixelSize: maxPixelSize)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let result = try await task.value
        if let result {
            memory.setObject(CGImageBox(result.cgImage), forKey: memoryKey,
                             cost: result.cgImage.bytesPerRow * result.cgImage.height)
            memoryKeys[request.cacheKey, default: []].insert(memoryKey)
        }
        return result
    }

    /// Drops memory + disk entries whose key starts with `prefix` (SSE `Thumbnail*` events, Phase 7 hook).
    public func invalidate(prefix: String) {
        for (cacheKey, keys) in memoryKeys where cacheKey.hasPrefix(prefix) {
            keys.forEach { memory.removeObject(forKey: $0) }
            memoryKeys[cacheKey] = nil
        }
        let directory = namespaceDirectory()
        let index = directory.appending(path: "index.plist")
        guard var entries = NSDictionary(contentsOf: index) as? [String: String] else { return }
        for (file, cacheKey) in entries where cacheKey.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
            entries[file] = nil
        }
        (entries as NSDictionary).write(to: index, atomically: true)
    }

    public func clearMemory() {
        memory.removeAllObjects()
        memoryKeys.removeAll()
    }

    // MARK: - Disk cache

    private func bytes(for request: ThumbnailRequest) async throws -> Data? {
        let file = diskURL(for: request)
        if let data = try? Data(contentsOf: file) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            return data
        }
        let data: Data?
        do {
            data = try await request.fetchBytes(from: api())
        } catch let error where error.isServerUnreachable {
            // Unreachable server: the offline store still has the thumbnails of everything downloaded.
            guard let offline = offlineApi() else { throw error }
            data = try await request.fetchBytes(from: offline)
        }
        guard let data else { return nil }
        store(data, at: file, cacheKey: request.cacheKey)
        return data
    }

    private func namespaceDirectory() -> URL {
        let digest = SHA256.hash(data: Data(namespace().utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return configuration.directory.appending(path: digest, directoryHint: .isDirectory)
    }

    private func diskURL(for request: ThumbnailRequest) -> URL {
        let name = SHA256.hash(data: Data(request.cacheKey.utf8)).map { String(format: "%02x", $0) }.joined()
        return namespaceDirectory().appending(path: name)
    }

    private func store(_ data: Data, at file: URL, cacheKey: String) {
        let directory = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        // Small index so prefix invalidation works on hashed file names.
        let index = directory.appending(path: "index.plist")
        var entries = (NSDictionary(contentsOf: index) as? [String: String]) ?? [:]
        entries[file.lastPathComponent] = cacheKey
        (entries as NSDictionary).write(to: index, atomically: true)

        writesSinceTrim += 1
        if writesSinceTrim >= 50 {
            writesSinceTrim = 0
            Self.trim(directory: configuration.directory, budget: configuration.diskBudgetBytes)
        }
    }

    /// LRU by modification date (touched on every hit).
    static func trim(directory: URL, budget: Int64) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys)
        else { return }
        var files: [(url: URL, date: Date, size: Int64)] = []
        for case let url as URL in enumerator where url.lastPathComponent != "index.plist" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            files.append((url, values.contentModificationDate ?? .distantPast, Int64(values.fileSize ?? 0)))
        }
        var total = files.reduce(0) { $0 + $1.size }
        for file in files.sorted(by: { $0.date < $1.date }) where total > budget {
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }

    // MARK: - Decoding

    static func decode(_ data: Data, maxPixelSize: Int) -> DecodedImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,  // decode now, off the main thread
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return DecodedImage(cgImage: image)
    }
}

final class CGImageBox: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
