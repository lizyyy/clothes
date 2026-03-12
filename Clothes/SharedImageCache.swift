// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedImageCache.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import Foundation
import SwiftUI
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    let cache = NSCache<NSString, UIImage>()
}

struct ImageCacheItem: Sendable {
    let id: UUID
    let data: Data?
}

nonisolated func cachedThumbnail(id: UUID, data: Data?, maxPixel: Int) -> UIImage? {
    guard let data else { return nil }
    let key = thumbnailCacheKey(id: id, data: data, maxPixel: maxPixel)
    
    // NSCache 是线程安全的，可以直接访问
    if let cached = ImageCache.shared.cache.object(forKey: key) {
        return cached
    }
    
    // thumbnailImage 不涉及UI操作，可以在任何线程执行
    guard let image = thumbnailImage(from: data, maxPixel: maxPixel) else { return nil }
    
    // 设置缓存也是线程安全的
    ImageCache.shared.cache.setObject(image, forKey: key)
    return image
}

nonisolated func cachedThumbnailIfAvailable(id: UUID, data: Data?, maxPixel: Int) -> UIImage? {
    guard let data else { return nil }
    let key = thumbnailCacheKey(id: id, data: data, maxPixel: maxPixel)
    return ImageCache.shared.cache.object(forKey: key)
}

nonisolated func prepareThumbnail(id: UUID, data: Data?, maxPixel: Int) async -> UIImage? {
    guard let data else { return nil }
    return await Task.detached(priority: .utility) {
        cachedThumbnail(id: id, data: data, maxPixel: maxPixel)
    }.value
}

nonisolated func thumbnailImage(from data: Data, maxPixel: Int) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
        return nil
    }
    let thumbnailOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

nonisolated func preheatWardrobeCache(items: [ImageCacheItem]) {
    Task.detached(priority: .background) {
        // 分批处理，避免一次性加载太多图片
        let itemsToPreheat = items.prefix(80)
        for (index, item) in itemsToPreheat.enumerated() {
            _ = cachedThumbnail(id: item.id, data: item.data, maxPixel: 320)
            // 每处理 10 个图片后短暂暂停，避免占用过多 CPU
            if (index + 1) % 10 == 0 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
}

nonisolated func preheatOutfitCache(items: [ImageCacheItem]) {
    Task.detached(priority: .background) {
        // 分批处理，避免一次性加载太多图片
        let outfitsToPreheat = items.prefix(40)
        for (index, outfit) in outfitsToPreheat.enumerated() {
            _ = cachedThumbnail(id: outfit.id, data: outfit.data, maxPixel: 360)
            // 每处理 5 个图片后短暂暂停，避免占用过多 CPU
            if (index + 1) % 5 == 0 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
}

nonisolated private func thumbnailCacheKey(id: UUID, data: Data, maxPixel: Int) -> NSString {
    "\(id.uuidString)-\(maxPixel)-\(quickFingerprint(for: data))" as NSString
}

nonisolated private func quickFingerprint(for data: Data) -> String {
    let head = data.prefix(8).map { String(format: "%02x", $0) }.joined()
    let tail = data.suffix(8).map { String(format: "%02x", $0) }.joined()
    return "\(data.count)-\(head)-\(tail)"
}
