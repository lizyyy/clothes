// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  AuthedCachedRemoteImage.swift
//  Clothes
//
//  Reads images via Go proxy endpoint with Bearer auth, caches on disk with TTL,
//  and revalidates using ETag when expired.
//

import SwiftUI
import UIKit

struct AuthedCachedRemoteImage: View {
    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("auth_username") private var authUsername = ""

    let rawPath: String
    var ttl: TimeInterval = SharedConstants.remoteImageCacheTTLSeconds
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat = 16
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.98))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.70, green: 0.68, blue: 0.64))
            }
        }
        .frame(width: width, height: height)
        .task(id: taskKey) {
            await loadIfNeeded()
        }
    }

    private var taskKey: String {
        // Changing account/token should refresh.
        [rawPath, authUsername, String(Int(ttl))].joined(separator: "|")
    }

    private func loadIfNeeded() async {
        guard !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        let namespace = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = RemoteImageDiskCache.shared.cacheKey(for: rawPath)

        if let entry = RemoteImageDiskCache.shared.load(namespace: namespace, key: cacheKey) {
            if let cached = UIImage(data: entry.data) {
                // Show cached immediately (even if expired) and refresh in background if needed.
                await MainActor.run { self.image = cached }
            }
            if !entry.isExpired {
                return
            }
            await fetchAndUpdate(namespace: namespace, cacheKey: cacheKey, previousETag: entry.metadata?.etag)
            return
        }

        await fetchAndUpdate(namespace: namespace, cacheKey: cacheKey, previousETag: nil)
    }

    private func fetchAndUpdate(namespace: String, cacheKey: String, previousETag: String?) async {
        guard let url = SharedConstants.proxiedImageURL(from: rawPath) else { return }
        let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let previousETag, !previousETag.isEmpty {
            request.setValue("\"\(previousETag)\"", forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 {
                RemoteImageDiskCache.shared.extendExpiry(namespace: namespace, key: cacheKey, ttl: ttl)
                return
            }

            guard (200..<300).contains(http.statusCode), !data.isEmpty else { return }
            guard let decoded = UIImage(data: data) else { return }

            let etag = http.value(forHTTPHeaderField: "ETag")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let contentType = http.value(forHTTPHeaderField: "Content-Type")

            RemoteImageDiskCache.shared.store(
                namespace: namespace,
                key: cacheKey,
                data: data,
                etag: etag,
                contentType: contentType,
                ttl: ttl
            )
            await MainActor.run { self.image = decoded }
        } catch {
            return
        }
    }
}

