// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  RemoteImageDiskCache.swift
//  Clothes
//
//  Stores authenticated remote images on disk with an explicit TTL.
//

import CryptoKit
import Foundation

struct RemoteImageCacheMetadata: Codable {
    var expiresAt: Date
    var etag: String?
    var contentType: String?
}

struct RemoteImageCacheEntry {
    var data: Data
    var isExpired: Bool
    var metadata: RemoteImageCacheMetadata?
}

final class RemoteImageDiskCache {
    static let shared = RemoteImageDiskCache()

    private let fm = FileManager.default
    private let baseDir: URL

    private init() {
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            baseDir = caches.appendingPathComponent("clothes-remote-images", isDirectory: true)
        } else {
            baseDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clothes-remote-images", isDirectory: true)
        }
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }

    func load(namespace: String, key: String) -> RemoteImageCacheEntry? {
        let fileURL = dataURL(namespace: namespace, key: key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let metaURL = metadataURL(namespace: namespace, key: key)
        let metadata: RemoteImageCacheMetadata?
        if let metaData = try? Data(contentsOf: metaURL) {
            metadata = try? JSONDecoder().decode(RemoteImageCacheMetadata.self, from: metaData)
        } else {
            metadata = nil
        }

        let now = Date()
        let isExpired = (metadata?.expiresAt ?? .distantPast) <= now
        return RemoteImageCacheEntry(data: data, isExpired: isExpired, metadata: metadata)
    }

    func store(namespace: String, key: String, data: Data, etag: String?, contentType: String?, ttl: TimeInterval) {
        let dir = namespaceDir(namespace: namespace)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let meta = RemoteImageCacheMetadata(
            expiresAt: Date().addingTimeInterval(max(5, ttl)),
            etag: etag?.trimmingCharacters(in: .whitespacesAndNewlines),
            contentType: contentType?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let fileURL = dataURL(namespace: namespace, key: key)
        let metaURL = metadataURL(namespace: namespace, key: key)

        do {
            try data.write(to: fileURL, options: [.atomic])
            let encoded = try JSONEncoder().encode(meta)
            try encoded.write(to: metaURL, options: [.atomic])
        } catch {
            // Best-effort cache; ignore persistence failures.
        }
    }

    func extendExpiry(namespace: String, key: String, ttl: TimeInterval) {
        let metaURL = metadataURL(namespace: namespace, key: key)
        guard let metaData = try? Data(contentsOf: metaURL),
              var meta = try? JSONDecoder().decode(RemoteImageCacheMetadata.self, from: metaData) else {
            return
        }
        meta.expiresAt = Date().addingTimeInterval(max(5, ttl))
        if let encoded = try? JSONEncoder().encode(meta) {
            try? encoded.write(to: metaURL, options: [.atomic])
        }
    }

    func cacheKey(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(trimmed.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func namespaceDir(namespace: String) -> URL {
        let safe = namespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "guest" : sanitize(namespace)
        return baseDir.appendingPathComponent(safe, isDirectory: true)
    }

    private func dataURL(namespace: String, key: String) -> URL {
        namespaceDir(namespace: namespace).appendingPathComponent(key + ".bin")
    }

    private func metadataURL(namespace: String, key: String) -> URL {
        namespaceDir(namespace: namespace).appendingPathComponent(key + ".json")
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce(into: "") { $0.append($1) }
    }
}

