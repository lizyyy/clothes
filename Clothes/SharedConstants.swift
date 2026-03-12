// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedConstants.swift
//  Clothes
//
//  Created by Codex on 2026/1/15.
//

import Foundation

// MARK: - 环境配置协议（解决循环依赖）

/// 环境配置协议 - 允许在 EnvironmentManager 定义前使用
protocol EnvironmentConfigProvider {
    static var shared: Self { get }
    var apiBaseURL: String { get }
    var fileBaseURL: String { get }
    var fileBucket: String { get }
}

enum SharedConstants {
    // TODO: Replace with your actual App Group ID and enable it in both app + share extension targets.
    static let appGroupID = "group.x.Clothes"
    static let sharedImportsKey = "shared_import_items"
    static let sharedImportFolder = "SharedImports"

    // Local data partition key when user is not logged in.
    static let guestOwnerKey = "__guest__"

    // MARK: - 默认配置（向后兼容）

    static let defaultApiHost = "192.168.124.17"
    static let defaultApiPort = 8080
    static let defaultFileHost = "192.168.124.17"
    static let defaultFilePort = 9000
    static let defaultFileBucket = "clothes"

    // Remote image cache TTL (client side). After expiry we revalidate/download again.
    // This is independent of URLCache and works for authenticated Go proxy endpoints.
    static let remoteImageCacheTTLSeconds: TimeInterval = 24 * 60 * 60
    static let avatarImageCacheTTLSeconds: TimeInterval = 6 * 60 * 60

    // MARK: - 图片路径处理

    static func normalizedImagePath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("/") {
            return trimmed
        }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url.path.isEmpty ? "" : url.path
        }
        return "/" + trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// 解析图片 URL（非隔离版本 - 直接传参避免 MainActor 问题）
    static func resolvedImageURL(from raw: String, fileBaseURL: String, fileBucket: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }

        var normalized = normalizedImagePath(trimmed)
        guard !normalized.isEmpty else { return nil }
        // Backward compatible: some older records may store objectKey without bucket prefix.
        if !normalized.hasPrefix("/\(fileBucket)/") {
            if normalized.hasPrefix("/users/") {
                normalized = "/\(fileBucket)" + normalized
            }
        }
        return URL(string: fileBaseURL + normalized)
    }

    /// Build an authenticated Go proxy URL for reading images.
    /// iOS should use this instead of directly calling object storage.
    static func proxiedImageURL(from raw: String, apiBaseURL: String, fileBucket: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If input is an absolute URL, keep only its path to proxy it.
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return proxiedImageURL(from: url.path, apiBaseURL: apiBaseURL, fileBucket: fileBucket)
        }

        var normalized = normalizedImagePath(trimmed)
        guard !normalized.isEmpty else { return nil }

        if !normalized.hasPrefix("/\(fileBucket)/") {
            if normalized.hasPrefix("/users/") {
                normalized = "/\(fileBucket)" + normalized
            }
        }

        var components = URLComponents(string: apiBaseURL + "/files/view")
        components?.queryItems = [URLQueryItem(name: "path", value: normalized)]
        return components?.url
    }
}

// MARK: - 环境配置访问（通过 EnvironmentManager）

extension SharedConstants {
    /// API 基础 URL - 从环境管理器获取（MainActor 隔离）
    @MainActor
    static var apiBaseURL: String {
        EnvironmentManager.shared.apiBaseURL
    }

    /// 文件服务基础 URL - 从环境管理器获取（MainActor 隔离）
    @MainActor
    static var fileBaseURL: String {
        EnvironmentManager.shared.fileBaseURL
    }

    /// 文件存储 bucket（MainActor 隔离）
    @MainActor
    static var fileBucket: String {
        EnvironmentManager.shared.fileBucket
    }

    /// 解析图片 URL（使用当前环境配置）
    @MainActor
    static func resolvedImageURL(from raw: String) -> URL? {
        resolvedImageURL(from: raw, fileBaseURL: apiBaseURL, fileBucket: fileBucket)
    }

    /// Build an authenticated Go proxy URL for reading images.
    @MainActor
    static func proxiedImageURL(from raw: String) -> URL? {
        proxiedImageURL(from: raw, apiBaseURL: apiBaseURL, fileBucket: fileBucket)
    }
}
