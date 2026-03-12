// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ExploreService.swift
//  Clothes
//
//  Created by Codex on 2026/2/7.
//  Updated by Codex on 2026/3/5: 修复 follow/like 请求缺少 /api/v1 前缀导致 404。
//

import Foundation

struct ExploreFeedResponse: Codable {
    let creators: [ExploreCreatorDTO]
}

struct ExploreUserListResponse: Codable {
    let users: [ExploreCreatorDTO]
}

struct ExploreCreatorDTO: Codable, Identifiable {
    let userID: Int64
    let name: String
    let handle: String
    var followersCount: Int64
    let followingCount: Int64
    var isFollowing: Bool
    let isSelf: Bool
    var outfits: [ExploreOutfitDTO]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name
        case handle
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case isFollowing = "is_following"
        case isSelf = "is_self"
        case outfits
    }

    var id: Int64 { userID }
}

struct ExploreOutfitDTO: Codable, Identifiable {
    let id: Int64
    let userID: Int64
    let title: String
    let imageURL: String
    let createdAt: String
    let shared: Bool
    let itemImages: [String]?
    var likeCount: Int64
    var isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case imageURL = "image_url"
        case createdAt = "created_at"
        case shared
        case itemImages = "item_images"
        case likeCount = "like_count"
        case isLiked = "is_liked"
    }
}

@MainActor
struct ExploreService {
    /// 动态获取 baseURL，支持环境切换
    private var baseURL: URL {
        URL(string: APIConfig.baseURL)!
    }

    func fetchFeed(token: String, mode: String, keyword: String) async throws -> ExploreFeedResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/explore/feed"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "keyword", value: keyword)
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(request, as: ExploreFeedResponse.self)
    }

    func follow(token: String, userID: Int64, isFollowing: Bool) async throws {
        let endpoint = "api/v1/explore/users/\(userID)/follow"
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = isFollowing ? "POST" : "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await send(request, as: ExploreFollowActionResponse.self)
    }

    func like(token: String, outfitID: Int64, isLiked: Bool) async throws {
        let endpoint = "api/v1/explore/outfits/\(outfitID)/like"
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = isLiked ? "POST" : "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await send(request, as: ExploreLikeActionResponse.self)
    }

    func fetchFollowing(token: String, userID: Int64) async throws -> [ExploreCreatorDTO] {
        let endpoint = "api/v1/explore/users/\(userID)/following"
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response = try await send(request, as: ExploreUserListResponse.self)
        return response.users
    }

    func fetchFollowers(token: String, userID: Int64) async throws -> [ExploreCreatorDTO] {
        let endpoint = "api/v1/explore/users/\(userID)/followers"
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response = try await send(request, as: ExploreUserListResponse.self)
        return response.users
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            let text = String(data: data, encoding: .utf8) ?? "请求失败"
            throw ServiceError(errno: http.statusCode, message: text)
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }
}

private struct ExploreFollowActionResponse: Codable {
    let userID: Int64?
    let isFollowing: Bool?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case isFollowing = "is_following"
    }
}

private struct ExploreLikeActionResponse: Codable {
    let outfitID: Int64?
    let isLiked: Bool?

    enum CodingKeys: String, CodingKey {
        case outfitID = "outfit_id"
        case isLiked = "is_liked"
    }
}
