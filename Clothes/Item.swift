// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  Item.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import Foundation
import SwiftData

enum SyncStatus: String, Codable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed
}

@Model
final class ClothingItem {
    var id: UUID
    // Account partition key. "__guest__" for logged-out local items; otherwise auth_username.
    var ownerUsername: String
    var serverItemID: Int64?
    var name: String
    var category: String
    var subCategory: String
    var color: String
    var material: String
    var pattern: String
    var fit: String
    var formality: Double
    private var styleTagsData: Data?
    private var seasonsData: Data?
    private var occasionsData: Data?
    var brand: String
    var price: Double?
    var purchaseDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var imageData: Data?
    var remoteImageURL: String = ""
    var syncStatusRaw: String
    var syncRetryCount: Int
    var syncErrorMessage: String
    var lastRemoteUpdatedAt: Date?
    var deletedAt: Date?

    var seasons: [String] {
        get { Self.decodeArray(from: seasonsData) }
        set { seasonsData = Self.encodeArray(newValue) }
    }

    var occasions: [String] {
        get { Self.decodeArray(from: occasionsData) }
        set { occasionsData = Self.encodeArray(newValue) }
    }

    var styleTags: [String] {
        get { Self.decodeArray(from: styleTagsData) }
        set { styleTagsData = Self.encodeArray(newValue) }
    }

    init(
        id: UUID = UUID(),
        ownerUsername: String = "",
        name: String,
        category: String,
        subCategory: String = "",
        color: String,
        material: String = "",
        pattern: String = "",
        fit: String = "regular",
        formality: Double = 0.5,
        seasons: [String],
        occasions: [String],
        styleTags: [String] = [],
        brand: String,
        price: Double? = nil,
        purchaseDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        imageData: Data? = nil,
        remoteImageURL: String = "",
        syncStatusRaw: String = SyncStatus.pending.rawValue,
        syncRetryCount: Int = 0,
        syncErrorMessage: String = "",
        lastRemoteUpdatedAt: Date? = nil,
        serverItemID: Int64? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.serverItemID = serverItemID
        self.name = name
        self.category = category
        self.subCategory = subCategory
        self.color = color
        self.material = material
        self.pattern = pattern
        self.fit = fit
        self.formality = formality
        self.seasonsData = Self.encodeArray(seasons)
        self.occasionsData = Self.encodeArray(occasions)
        self.styleTagsData = Self.encodeArray(styleTags)
        self.brand = brand
        self.price = price
        self.purchaseDate = purchaseDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.remoteImageURL = remoteImageURL
        self.syncStatusRaw = syncStatusRaw
        self.syncRetryCount = syncRetryCount
        self.syncErrorMessage = syncErrorMessage
        self.lastRemoteUpdatedAt = lastRemoteUpdatedAt
        self.deletedAt = deletedAt
    }

    private static func encodeArray(_ value: [String]) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decodeArray(from data: Data?) -> [String] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
}
