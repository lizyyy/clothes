// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ClothesAPIService.swift
//  Clothes
//
//  Created by lzy on 2026/1/15.
//  Updated by Codex on 2026/3/6: 关闭草稿箱失败提示并增加后台冷却后自动重试。
//

import Foundation
import SwiftData
import CryptoKit

// MARK: - API 服务

@MainActor
final class ClothesAPIService {
    static let shared = ClothesAPIService()

    private var authToken: String?
    private let isoFormatter = ISO8601DateFormatter()

    private init() {
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// 动态获取 baseURL，支持环境切换
    private var baseURL: String {
        EnvironmentManager.shared.apiBaseURL
    }

    // MARK: - 认证

    /// 设置认证 Token
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// 注册用户
    func register(username: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/auth/register")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RegisterRequest(username: username, password: password))
        return try await send(request, as: AuthResponse.self, needsAuth: false)
    }

    /// 登录
    func login(username: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/auth/login")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        let auth = try await send(request, as: AuthResponse.self, needsAuth: false)
        setAuthToken(auth.token)
        return auth
    }

    // MARK: - 文件服务

    /// 上传文件到 MinIO/S3
    func uploadFile(data: Data, fileName: String, scope: String) async throws -> FileUploadResponse {
        guard let token = authToken, !token.isEmpty else {
            throw APIError.unauthorized
        }

        // Client-side dedupe: skip upload when the same payload has been uploaded before.
        // Avoid using this for short-lived presigned URL flows (ai-tryon / ai-model).
        if scope != "ai-tryon" && scope != "ai-model" {
            let hash = sha256Hex(data)
            if let cached = loadUploadCache(scope: scope, hash: hash) {
                return cached
            }
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/upload/image")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"scope\"\r\n\r\n")
        body.append("\(scope)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let uploaded = try await send(request, as: FileUploadResponse.self, needsAuth: false)
        if scope != "ai-tryon" && scope != "ai-model" {
            let hash = sha256Hex(data)
            saveUploadCache(scope: scope, hash: hash, response: uploaded)
        }
        return uploaded
    }

    // MARK: - 衣物管理

    func createClothingItem(_ requestBody: ClothingItemUpsertRequest) async throws -> CreateResourceResponse {
        var request = try authorizedJSONRequest(path: "/clothes", method: "POST")
        request.httpBody = try JSONEncoder().encode(requestBody)
        return try await send(request, as: CreateResourceResponse.self, needsAuth: false)
    }

    func updateClothingItem(id: Int64, requestBody: ClothingItemUpsertRequest) async throws {
        var request = try authorizedJSONRequest(path: "/clothes/\(id)", method: "PUT")
        request.httpBody = try JSONEncoder().encode(requestBody)
        _ = try await send(request, as: [String: String].self, needsAuth: false)
    }

    func getMyClothingItems() async throws -> [ClothingItemResponse] {
        let request = try authorizedJSONRequest(path: "/clothes", method: "GET")
        return try await send(request, as: [ClothingItemResponse].self, needsAuth: false)
    }

    // MARK: - 穿搭管理

    /// 创建穿搭
    func createOutfit(
        title: String,
        items: [OutfitItem],
        imageURL: String?,
        shared: Bool,
        legacyClothingIDs: [Int64] = []
    ) async throws -> CreateOutfitResponse {
        let normalizedImageURL = SharedConstants.normalizedImagePath(imageURL ?? "")
        do {
            var request = try authorizedJSONRequest(path: "/outfits", method: "POST")
            request.httpBody = try JSONEncoder().encode(
                CreateOutfitRequest(title: title, items: items, image_url: normalizedImageURL, shared: shared)
            )
            return try await send(request, as: CreateOutfitResponse.self, needsAuth: false)
        } catch {
            guard shouldUseLegacyOutfitPayload(error) else { throw error }
            let ids = Array(Set(legacyClothingIDs.filter { $0 > 0 }))
            guard !ids.isEmpty else {
                throw APIError.server("当前服务端需要 clothing_ids，至少同步一件衣物后再公开穿搭。")
            }
            return try await createOutfitLegacy(
                title: title,
                imageURL: normalizedImageURL,
                shared: shared,
                clothingIDs: ids
            )
        }
    }

    /// 更新穿搭
    func updateOutfit(
        id: Int64,
        title: String,
        items: [OutfitItem],
        imageURL: String?,
        shared: Bool,
        legacyClothingIDs: [Int64] = []
    ) async throws {
        let normalizedImageURL = SharedConstants.normalizedImagePath(imageURL ?? "")
        do {
            var request = try authorizedJSONRequest(path: "/outfits/\(id)", method: "PUT")
            request.httpBody = try JSONEncoder().encode(
                CreateOutfitRequest(title: title, items: items, image_url: normalizedImageURL, shared: shared)
            )
            _ = try await send(request, as: OutfitVisibilityResponse.self, needsAuth: false)
        } catch {
            guard shouldUseLegacyOutfitPayload(error) else { throw error }
            let ids = Array(Set(legacyClothingIDs.filter { $0 > 0 }))
            guard !ids.isEmpty else {
                throw APIError.server("当前服务端需要 clothing_ids，至少同步一件衣物后再公开穿搭。")
            }
            try await updateOutfitLegacy(
                id: id,
                title: title,
                imageURL: normalizedImageURL,
                shared: shared,
                clothingIDs: ids
            )
        }
    }

    /// 获取我的穿搭列表
    func getMyOutfits() async throws -> [OutfitResponse] {
        let request = try authorizedJSONRequest(path: "/outfits", method: "GET")
        return try await send(request, as: [OutfitResponse].self, needsAuth: false)
    }

    /// 获取公开穿搭列表
    func getPublicOutfits() async throws -> [OutfitResponse] {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/outfits/public")!)
        request.httpMethod = "GET"
        return try await send(request, as: [OutfitResponse].self, needsAuth: false)
    }

    /// 获取单个穿搭
    func getOutfit(id: Int64) async throws -> OutfitResponse {
        let request = try authorizedJSONRequest(path: "/outfits/\(id)", method: "GET")
        return try await send(request, as: OutfitResponse.self, needsAuth: false)
    }

    /// 分享穿搭
    func shareOutfit(id: Int64) async throws {
        let request = try authorizedJSONRequest(path: "/outfits/\(id)/share", method: "POST")
        _ = try await send(request, as: [String: String].self, needsAuth: false)
    }

    /// 设置穿搭公开状态
    func setOutfitVisibility(id: Int64, shared: Bool) async throws {
        do {
            var request = try authorizedJSONRequest(path: "/outfits/\(id)/visibility", method: "PUT")
            request.httpBody = try JSONEncoder().encode(["shared": shared])
            _ = try await send(request, as: OutfitVisibilityResponse.self, needsAuth: false)
            return
        } catch {
            guard isEndpointNotFound(error) else { throw error }
        }

        if shared {
            do {
                try await shareOutfit(id: id)
                return
            } catch {
                guard isEndpointNotFound(error) else { throw error }
            }
        }

        throw APIError.server("当前服务器暂不支持切换公开状态，请升级服务端后重试。")
    }

    private func createOutfitLegacy(
        title: String,
        imageURL: String,
        shared: Bool,
        clothingIDs: [Int64]
    ) async throws -> CreateOutfitResponse {
        var request = try authorizedJSONRequest(path: "/outfits", method: "POST")
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmed.isEmpty ? "我的搭配" : trimmed
        request.httpBody = try JSONEncoder().encode(
            LegacyOutfitRequest(
                title: resolvedTitle,
                name: resolvedTitle,
                description: resolvedTitle,
                season: "春",
                occasion: "通勤",
                cover_image: imageURL,
                is_public: shared ? 1 : 0,
                clothing_ids: clothingIDs
            )
        )
        return try await send(request, as: CreateOutfitResponse.self, needsAuth: false)
    }

    private func updateOutfitLegacy(
        id: Int64,
        title: String,
        imageURL: String,
        shared: Bool,
        clothingIDs: [Int64]
    ) async throws {
        var request = try authorizedJSONRequest(path: "/outfits/\(id)", method: "PUT")
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmed.isEmpty ? "我的搭配" : trimmed
        request.httpBody = try JSONEncoder().encode(
            LegacyOutfitRequest(
                title: resolvedTitle,
                name: resolvedTitle,
                description: resolvedTitle,
                season: "春",
                occasion: "通勤",
                cover_image: imageURL,
                is_public: shared ? 1 : 0,
                clothing_ids: clothingIDs
            )
        )
        _ = try await send(request, as: OutfitVisibilityResponse.self, needsAuth: false)
    }

    /// 健康检查
    func healthCheck() async throws -> Bool {
        var request = URLRequest(url: URL(string: "\(baseURL)/health")!)
        request.httpMethod = "GET"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(httpResponse.statusCode)
    }

    // MARK: - 基础请求

    private func authorizedJSONRequest(path: String, method: String) throws -> URLRequest {
        guard let token = authToken, !token.isEmpty else {
            throw APIError.unauthorized
        }
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1\(path)")!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type, needsAuth: Bool) async throws -> T {
        if needsAuth, (authToken ?? "").isEmpty {
            throw APIError.unauthorized
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorEnvelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw APIError.server(errorEnvelope.errmsg)
            }
            let rawText = String(data: data, encoding: .utf8) ?? "服务器返回错误"
            throw APIError.server(rawText)
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw APIError.server(envelope.errmsg)
        }
        return payload
    }

    private func isEndpointNotFound(_ error: Error) -> Bool {
        let lowered = error.localizedDescription.lowercased()
        return lowered.contains("404") || lowered.contains("not found") || lowered.contains("no route")
    }

    private func shouldUseLegacyOutfitPayload(_ error: Error) -> Bool {
        let lowered = error.localizedDescription.lowercased()
        return lowered.contains("outfitrequest.name")
            || lowered.contains("outfitrequest.clothingids")
            || lowered.contains("name' failed on the 'required'")
            || lowered.contains("clothingids' failed on the 'required'")
            || lowered.contains("clothing_ids")
    }

    fileprivate func parseISODate(_ value: String) -> Date? {
        if let date = isoFormatter.date(from: value) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}

// MARK: - 同步服务（本地优先 + 异步重试）

@MainActor
final class WardrobeSyncService {
    static let shared = WardrobeSyncService()

    // Failed records are revived automatically after cooldown so users no longer need manual draftbox retry.
    private let failedRetryCooldown: TimeInterval = 6 * 60 * 60
    private let maxAutoRetryCount = 3
    private let retryBackoffNanoseconds: UInt64 = 1_000_000_000
    private var isSyncing = false

    private init() {}

    func scheduleSync(modelContext: ModelContext) {
        Task {
            await syncNow(modelContext: modelContext)
        }
    }

    func syncNow(modelContext: ModelContext) async {
        // UI tests should run against deterministic local state. Background sync can introduce flakiness
        // (network, retries, latency) and has caused XCTest to kill the runner on slow environments.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return
        }
        guard !isSyncing else { return }
        let token = UserDefaults.standard.string(forKey: "auth_token")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let owner = UserDefaults.standard.string(forKey: "auth_username")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty, !owner.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        let api = ClothesAPIService.shared
        api.setAuthToken(token)

        // Move guest/legacy items into the current account partition so they can be synced up.
        claimGuestAndLegacyData(modelContext: modelContext, owner: owner)
        reviveFailedRecordsForAutoRetry(modelContext: modelContext, owner: owner)

        await syncPendingClothing(modelContext: modelContext, api: api)
        await syncPendingOutfits(modelContext: modelContext, api: api)
        await pullServerChanges(modelContext: modelContext, api: api)
    }

    func markItemPending(_ item: ClothingItem) {
        item.updatedAt = Date()
        item.syncStatus = .pending
        item.syncErrorMessage = ""
        if item.syncRetryCount >= maxAutoRetryCount {
            item.syncRetryCount = 0
        }
    }

    func markOutfitPending(_ outfit: OutfitRecord) {
        outfit.updatedAt = Date()
        outfit.syncStatus = .pending
        outfit.syncErrorMessage = ""
        if outfit.syncRetryCount >= maxAutoRetryCount {
            outfit.syncRetryCount = 0
        }
    }

    func syncOutfitNow(_ outfit: OutfitRecord, modelContext: ModelContext) async throws {
        let token = UserDefaults.standard.string(forKey: "auth_token")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else { throw APIError.unauthorized }
        let api = ClothesAPIService.shared
        api.setAuthToken(token)
        try await syncSingleOutfit(outfit, modelContext: modelContext, api: api)
    }

    private func syncPendingClothing(modelContext: ModelContext, api: ClothesAPIService) async {
        let owner = UserDefaults.standard.string(forKey: "auth_username")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !owner.isEmpty else { return }
        let items = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        let candidates = items.filter {
            $0.ownerUsername == owner
                && $0.deletedAt == nil
                && ($0.syncStatus == .pending || $0.syncStatus == .syncing)
        }

        for item in candidates {
            await syncSingleClothingWithRetry(item, api: api)
        }
    }

    private func syncPendingOutfits(modelContext: ModelContext, api: ClothesAPIService) async {
        let owner = UserDefaults.standard.string(forKey: "auth_username")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !owner.isEmpty else { return }
        let outfits = (try? modelContext.fetch(FetchDescriptor<OutfitRecord>())) ?? []
        let candidates = outfits.filter {
            $0.ownerUsername == owner
                && $0.deletedAt == nil
                && ($0.syncStatus == .pending || $0.syncStatus == .syncing)
        }

        for outfit in candidates {
            await syncSingleOutfitWithRetry(outfit, modelContext: modelContext, api: api)
        }
    }

    private func syncSingleClothingWithRetry(_ item: ClothingItem, api: ClothesAPIService) async {
        while item.syncRetryCount < maxAutoRetryCount {
            do {
                try await syncSingleClothing(item, api: api)
                return
            } catch {
                markClothingFailure(item, message: error.localizedDescription)
                guard item.syncStatus != .failed else { return }
                try? await Task.sleep(nanoseconds: retryBackoffNanoseconds)
            }
        }
    }

    private func syncSingleOutfitWithRetry(_ outfit: OutfitRecord, modelContext: ModelContext, api: ClothesAPIService) async {
        while outfit.syncRetryCount < maxAutoRetryCount {
            do {
                try await syncSingleOutfit(outfit, modelContext: modelContext, api: api)
                return
            } catch {
                markOutfitFailure(outfit, message: error.localizedDescription)
                guard outfit.syncStatus != .failed else { return }
                try? await Task.sleep(nanoseconds: retryBackoffNanoseconds)
            }
        }
    }

    private func syncSingleClothing(_ item: ClothingItem, api: ClothesAPIService) async throws {
        item.syncStatus = .syncing

        var imageURL = item.remoteImageURL
        if let imageData = item.imageData,
           imageURL.isEmpty || isRemoteImageStale(localUpdatedAt: item.updatedAt, remoteUpdatedAt: item.lastRemoteUpdatedAt) {
            let uploaded = try await api.uploadFile(
                data: imageData,
                fileName: "clothing-\(item.id.uuidString).jpg",
                scope: "clothing"
            )
            imageURL = SharedConstants.normalizedImagePath(uploaded.url)
        }

        let req = ClothingItemUpsertRequest(
            name: item.name,
            category: item.category,
            sub_category: item.subCategory,
            brand: item.brand,
            color: item.color,
            material: item.material,
            pattern: item.pattern,
            fit: item.fit,
            formality: item.formality,
            seasons: item.seasons,
            occasions: item.occasions,
            style_tags: item.styleTags,
            image_url: SharedConstants.normalizedImagePath(imageURL),
            source_url: "",
            source_site: "ios",
            source_product_id: item.id.uuidString
        )

        if let serverID = item.serverItemID {
            try await api.updateClothingItem(id: serverID, requestBody: req)
        } else {
            let created = try await api.createClothingItem(req)
            item.serverItemID = created.id
        }

        item.remoteImageURL = SharedConstants.normalizedImagePath(imageURL)
        item.lastRemoteUpdatedAt = Date()
        item.syncStatus = .synced
        item.syncRetryCount = 0
        item.syncErrorMessage = ""
    }

    private func syncSingleOutfit(_ outfit: OutfitRecord, modelContext: ModelContext, api: ClothesAPIService) async throws {
        outfit.syncStatus = .syncing

        let clothing = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        let itemLookup = Dictionary(uniqueKeysWithValues: clothing.map { ($0.id, $0) })

        var imageURL = outfit.remoteImageURL
        if let imageData = outfit.imageData,
           imageURL.isEmpty || isRemoteImageStale(localUpdatedAt: outfit.updatedAt, remoteUpdatedAt: outfit.lastRemoteUpdatedAt) {
            let uploaded = try await api.uploadFile(
                data: imageData,
                fileName: "outfit-\(outfit.id.uuidString).jpg",
                scope: "outfits"
            )
            imageURL = SharedConstants.normalizedImagePath(uploaded.url)
        }

        var items = outfit.itemIDs.compactMap { itemLookup[$0] }.map {
            OutfitItem(
                name: $0.name,
                category: $0.category,
                image_url: SharedConstants.normalizedImagePath($0.remoteImageURL)
            )
        }
        let legacyClothingIDs = outfit.itemIDs.compactMap { itemLookup[$0]?.serverItemID }
        if items.isEmpty {
            let fallbackName = outfit.itemNames.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = fallbackName.isEmpty ? "未命名单品" : fallbackName
            items = [OutfitItem(name: title, category: "上衣", image_url: "")]
        }

        let title = outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "我的搭配" : outfit.title

        if let serverID = outfit.serverOutfitID {
            try await api.updateOutfit(
                id: serverID,
                title: title,
                items: items,
                imageURL: SharedConstants.normalizedImagePath(imageURL),
                shared: outfit.isShared,
                legacyClothingIDs: legacyClothingIDs
            )
        } else {
            let created = try await api.createOutfit(
                title: title,
                items: items,
                imageURL: SharedConstants.normalizedImagePath(imageURL),
                shared: outfit.isShared,
                legacyClothingIDs: legacyClothingIDs
            )
            outfit.serverOutfitID = created.id
        }

        outfit.remoteImageURL = SharedConstants.normalizedImagePath(imageURL)
        outfit.lastRemoteUpdatedAt = Date()
        outfit.syncStatus = .synced
        outfit.syncRetryCount = 0
        outfit.syncErrorMessage = ""
    }

    private func pullServerChanges(modelContext: ModelContext, api: ClothesAPIService) async {
        let owner = UserDefaults.standard.string(forKey: "auth_username")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !owner.isEmpty else { return }
        do {
            let remoteClothing = try await api.getMyClothingItems()
            await mergeRemoteClothing(remoteClothing, owner: owner, modelContext: modelContext, api: api)
        } catch {
            // 忽略拉取失败，避免阻断本地操作
        }

        do {
            let remoteOutfits = try await api.getMyOutfits()
            await mergeRemoteOutfits(remoteOutfits, owner: owner, modelContext: modelContext, api: api)
        } catch {
            // 忽略拉取失败，避免阻断本地操作
        }
    }

    private func mergeRemoteClothing(_ remoteItems: [ClothingItemResponse], owner: String, modelContext: ModelContext, api: ClothesAPIService) async {
        let localItems = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        var localByServerID: [Int64: ClothingItem] = [:]
        for item in localItems {
            guard item.ownerUsername == owner else { continue }
            if let serverID = item.serverItemID {
                localByServerID[serverID] = item
            }
        }

        for remote in remoteItems {
            let remoteUpdatedAt = api.parseISODate(remote.updated_at) ?? Date()
            if let local = localByServerID[remote.id] {
                if local.syncStatus == .pending || local.syncStatus == .syncing {
                    continue
                }
                let localRemoteTime = local.lastRemoteUpdatedAt ?? .distantPast
                if remoteUpdatedAt <= localRemoteTime.addingTimeInterval(1) {
                    continue
                }
                local.name = remote.name
                local.category = remote.category
                local.subCategory = remote.sub_category
                local.brand = remote.brand
                local.color = remote.color
                local.material = remote.material
                local.pattern = remote.pattern
                local.fit = remote.fit
                local.formality = remote.formality
                local.seasons = remote.seasons
                local.occasions = remote.occasions
                local.styleTags = remote.style_tags
                local.remoteImageURL = SharedConstants.normalizedImagePath(remote.image_url)
                local.updatedAt = remoteUpdatedAt
                local.lastRemoteUpdatedAt = remoteUpdatedAt
                local.ownerUsername = owner
                local.syncStatus = .synced
                local.syncRetryCount = 0
                local.syncErrorMessage = ""
                if local.imageData == nil, let data = await downloadImageData(from: remote.image_url) {
                    local.imageData = data
                }
            } else {
                let newItem = ClothingItem(
                    ownerUsername: owner,
                    name: remote.name,
                    category: remote.category,
                    subCategory: remote.sub_category,
                    color: remote.color,
                    material: remote.material,
                    pattern: remote.pattern,
                    fit: remote.fit,
                    formality: remote.formality,
                    seasons: remote.seasons,
                    occasions: remote.occasions,
                    styleTags: remote.style_tags,
                    brand: remote.brand,
                    createdAt: api.parseISODate(remote.created_at) ?? Date(),
                    updatedAt: remoteUpdatedAt,
                    imageData: await downloadImageData(from: remote.image_url),
                    remoteImageURL: SharedConstants.normalizedImagePath(remote.image_url),
                    syncStatusRaw: SyncStatus.synced.rawValue,
                    syncRetryCount: 0,
                    syncErrorMessage: "",
                    lastRemoteUpdatedAt: remoteUpdatedAt,
                    serverItemID: remote.id
                )
                modelContext.insert(newItem)
            }
        }
    }

    private func mergeRemoteOutfits(_ remoteOutfits: [OutfitResponse], owner: String, modelContext: ModelContext, api: ClothesAPIService) async {
        let localOutfits = (try? modelContext.fetch(FetchDescriptor<OutfitRecord>())) ?? []
        var localByServerID: [Int64: OutfitRecord] = [:]
        for outfit in localOutfits {
            guard outfit.ownerUsername == owner else { continue }
            if let serverID = outfit.serverOutfitID {
                localByServerID[serverID] = outfit
            }
        }

        for remote in remoteOutfits {
            let remoteUpdatedAt = api.parseISODate(remote.updated_at ?? remote.created_at) ?? Date()
            if let local = localByServerID[remote.id] {
                if local.syncStatus == .pending || local.syncStatus == .syncing {
                    continue
                }
                let localRemoteTime = local.lastRemoteUpdatedAt ?? .distantPast
                if remoteUpdatedAt <= localRemoteTime.addingTimeInterval(1) {
                    continue
                }
                local.title = remote.title
                local.itemNames = remote.items.map(\.name).joined(separator: "、")
                local.remoteImageURL = SharedConstants.normalizedImagePath(remote.image_url)
                local.isShared = remote.shared
                local.updatedAt = remoteUpdatedAt
                local.lastRemoteUpdatedAt = remoteUpdatedAt
                local.ownerUsername = owner
                local.syncStatus = .synced
                local.syncRetryCount = 0
                local.syncErrorMessage = ""
                if local.imageData == nil, let data = await downloadImageData(from: remote.image_url) {
                    local.imageData = data
                }
            } else {
                let record = OutfitRecord(
                    ownerUsername: owner,
                    title: remote.title,
                    itemNames: remote.items.map(\.name).joined(separator: "、"),
                    itemIDs: [],
                    createdAt: api.parseISODate(remote.created_at) ?? Date(),
                    updatedAt: remoteUpdatedAt,
                    isShared: remote.shared,
                    imageData: await downloadImageData(from: remote.image_url),
                    remoteImageURL: SharedConstants.normalizedImagePath(remote.image_url),
                    serverOutfitID: remote.id,
                    syncStatusRaw: SyncStatus.synced.rawValue,
                    syncRetryCount: 0,
                    syncErrorMessage: "",
                    lastRemoteUpdatedAt: remoteUpdatedAt
                )
                modelContext.insert(record)
            }
        }
    }

    private func claimGuestAndLegacyData(modelContext: ModelContext, owner: String) {
        // Guest partition should be moved to the current logged-in user after login.
        let items = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        for item in items where item.ownerUsername == SharedConstants.guestOwnerKey || item.ownerUsername.isEmpty {
            item.ownerUsername = owner
        }

        let outfits = (try? modelContext.fetch(FetchDescriptor<OutfitRecord>())) ?? []
        for record in outfits where record.ownerUsername == SharedConstants.guestOwnerKey || record.ownerUsername.isEmpty {
            record.ownerUsername = owner
        }

        let entries = (try? modelContext.fetch(FetchDescriptor<OutfitCalendarEntry>())) ?? []
        for entry in entries where entry.ownerUsername == SharedConstants.guestOwnerKey || entry.ownerUsername.isEmpty {
            entry.ownerUsername = owner
        }
    }

    private func reviveFailedRecordsForAutoRetry(modelContext: ModelContext, owner: String) {
        let now = Date()
        let clothing = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        for item in clothing where item.ownerUsername == owner && item.deletedAt == nil && item.syncStatus == .failed {
            guard now.timeIntervalSince(item.updatedAt) >= failedRetryCooldown else { continue }
            item.syncStatus = .pending
            item.syncRetryCount = 0
            item.syncErrorMessage = ""
            item.updatedAt = now
        }

        let outfits = (try? modelContext.fetch(FetchDescriptor<OutfitRecord>())) ?? []
        for outfit in outfits where outfit.ownerUsername == owner && outfit.deletedAt == nil && outfit.syncStatus == .failed {
            guard now.timeIntervalSince(outfit.updatedAt) >= failedRetryCooldown else { continue }
            outfit.syncStatus = .pending
            outfit.syncRetryCount = 0
            outfit.syncErrorMessage = ""
            outfit.updatedAt = now
        }
    }

    private func downloadImageData(from urlString: String) async -> Data? {
        guard let url = SharedConstants.resolvedImageURL(from: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func isRemoteImageStale(localUpdatedAt: Date, remoteUpdatedAt: Date?) -> Bool {
        guard let remoteUpdatedAt else { return true }
        return localUpdatedAt > remoteUpdatedAt.addingTimeInterval(1)
    }

    private func markClothingFailure(_ item: ClothingItem, message: String) {
        item.syncRetryCount += 1
        item.syncErrorMessage = message
        item.updatedAt = Date()
        if item.syncRetryCount >= maxAutoRetryCount {
            item.syncStatus = .failed
        } else {
            item.syncStatus = .pending
        }
    }

    private func markOutfitFailure(_ outfit: OutfitRecord, message: String) {
        outfit.syncRetryCount += 1
        outfit.syncErrorMessage = message
        outfit.updatedAt = Date()
        if outfit.syncRetryCount >= maxAutoRetryCount {
            outfit.syncStatus = .failed
        } else {
            outfit.syncStatus = .pending
        }
    }
}

// MARK: - 请求/响应模型
struct RegisterRequest: Codable {
    let username: String
    let password: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserInfo?
    let is_new_user: Bool?
}

struct UserInfo: Decodable {
    let uid: Int64?
    let username: String
    let email: String?
    let nickname: String?

    private enum CodingKeys: String, CodingKey {
        case uid
        case username
        case email
        case nickname
        case name
    }

    init(uid: Int64?, username: String, email: String?, nickname: String?) {
        self.uid = uid
        self.username = username
        self.email = email
        self.nickname = nickname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intUID = try? container.decode(Int64.self, forKey: .uid) {
            uid = intUID
        } else if let stringUID = try? container.decode(String.self, forKey: .uid) {
            uid = Int64(stringUID.filter(\.isNumber))
        } else {
            uid = nil
        }
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        email = try? container.decodeIfPresent(String.self, forKey: .email)
        nickname =
            (try? container.decodeIfPresent(String.self, forKey: .nickname))
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
    }
}

struct FileUploadResponse: Codable {
    let url: String
    let public_url: String?
    let key: String

    private enum CodingKeys: String, CodingKey {
        case url
        case public_url
        case key
        case filename
    }

    init(url: String, public_url: String?, key: String) {
        self.url = url
        self.public_url = public_url
        self.key = key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let url = try container.decode(String.self, forKey: .url)
        let publicURL = try container.decodeIfPresent(String.self, forKey: .public_url)
        let key = try container.decodeIfPresent(String.self, forKey: .key)
            ?? container.decodeIfPresent(String.self, forKey: .filename)
            ?? ""
        self.init(url: url, public_url: publicURL, key: key)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(public_url, forKey: .public_url)
        try container.encode(key, forKey: .key)
    }
}

private extension ClothesAPIService {
    struct UploadCacheEntry: Codable {
        let response: FileUploadResponse
        let savedAt: Double
    }

    func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func uploadCacheKey(scope: String, hash: String) -> String {
        "upload_cache_v1|\(scope)|\(hash)"
    }

    func loadUploadCache(scope: String, hash: String) -> FileUploadResponse? {
        let key = uploadCacheKey(scope: scope, hash: hash)
        guard let raw = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(UploadCacheEntry.self, from: raw) else {
            return nil
        }
        // Keep 30 days.
        if Date().timeIntervalSince1970 - entry.savedAt > 30 * 24 * 60 * 60 {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        return entry.response
    }

    func saveUploadCache(scope: String, hash: String, response: FileUploadResponse) {
        let key = uploadCacheKey(scope: scope, hash: hash)
        let entry = UploadCacheEntry(response: response, savedAt: Date().timeIntervalSince1970)
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct ClothingItemUpsertRequest: Codable {
    let name: String
    let category: String
    let sub_category: String
    let brand: String
    let color: String
    let material: String
    let pattern: String
    let fit: String
    let formality: Double
    let seasons: [String]
    let occasions: [String]
    let style_tags: [String]
    let image_url: String
    let source_url: String
    let source_site: String
    let source_product_id: String
}

struct ClothingItemResponse: Codable {
    let id: Int64
    let user_id: Int64
    let name: String
    let category: String
    let sub_category: String
    let brand: String
    let color: String
    let material: String
    let pattern: String
    let fit: String
    let formality: Double
    let seasons: [String]
    let occasions: [String]
    let style_tags: [String]
    let image_url: String
    let source_url: String
    let source_site: String
    let source_product_id: String
    let created_at: String
    let updated_at: String
}

struct CreateOutfitRequest: Codable {
    let title: String
    let items: [OutfitItem]
    let image_url: String
    let shared: Bool
}

struct LegacyOutfitRequest: Codable {
    let title: String
    let name: String
    let description: String
    let season: String
    let occasion: String
    let cover_image: String
    let is_public: Int
    let clothing_ids: [Int64]
}

struct CreateOutfitResponse: Codable {
    let id: Int64
}

struct CreateResourceResponse: Codable {
    let id: Int64
}

struct OutfitItem: Codable {
    let name: String
    let category: String
    let image_url: String
}

struct OutfitResponse: Codable {
    let id: Int64
    let user_id: Int64
    let title: String
    let items: [OutfitItem]
    let image_url: String
    let shared: Bool
    let created_at: String
    let updated_at: String?
}

struct OutfitVisibilityResponse: Codable {
    let id: Int64?
    let shared: Bool?
    let status: String?
}

// APIEnvelope<T> is defined in WalletService.swift and reused here.

// MARK: - 错误类型

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的服务器响应"
        case .unauthorized:
            return "未授权，请先登录"
        case let .server(message):
            return message
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
