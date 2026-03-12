// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  MallCatalogService.swift
//  Clothes
//
//  Created by Codex on 2026/2/7.
//

import Foundation

struct MallProduct: Codable, Identifiable {
    let id: Int64
    let sourceSite: String
    let sourceProductID: String
    let name: String
    let gender: String
    let category: String
    let subCategory: String
    let brand: String
    let price: Double
    let imageURL: String
    let productURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case sourceSite = "source_site"
        case sourceProductID = "source_product_id"
        case name
        case gender
        case category
        case subCategory = "sub_category"
        case brand
        case price
        case imageURL = "image_url"
        case productURL = "product_url"
    }
}

@MainActor
struct MallCatalogService {
    /// 动态获取 baseURL，支持环境切换
    private var baseURL: URL {
        URL(string: APIConfig.baseURL)!
    }

    func fetchProducts(gender: String?, subCategory: String?, keyword: String?, limit: Int = 300) async throws -> [MallProduct] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/mall-products"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(max(1, min(limit, 500)))")]
        if let gender, !gender.isEmpty {
            queryItems.append(URLQueryItem(name: "gender", value: gender))
        }
        if let subCategory, !subCategory.isEmpty {
            queryItems.append(URLQueryItem(name: "sub_category", value: subCategory))
        }
        if let keyword, !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "获取商城数据失败"
            throw ServiceError(errno: http.statusCode, message: message)
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<[MallProduct]>.self, from: data)
        guard envelope.errno == 0 else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return envelope.data ?? []
    }
}
