// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  OutfitRecord.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import Foundation
import SwiftData

@Model
final class OutfitRecord {
    var id: UUID
    // Account partition key. "__guest__" for logged-out local records; otherwise auth_username.
    var ownerUsername: String
    var title: String
    var itemNames: String
    var itemIDsData: Data?
    var createdAt: Date
    var updatedAt: Date
    var isShared: Bool
    var imageData: Data?
    var remoteImageURL: String = ""
    var personImageData: Data?
    var aiTryOnImageData: Data?
    var deletedAt: Date?
    var serverOutfitID: Int64?
    var syncStatusRaw: String
    var syncRetryCount: Int
    var syncErrorMessage: String
    var lastRemoteUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        ownerUsername: String = "",
        title: String,
        itemNames: String,
        itemIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isShared: Bool = false,
        imageData: Data? = nil,
        remoteImageURL: String = "",
        personImageData: Data? = nil,
        aiTryOnImageData: Data? = nil,
        deletedAt: Date? = nil,
        serverOutfitID: Int64? = nil,
        syncStatusRaw: String = SyncStatus.pending.rawValue,
        syncRetryCount: Int = 0,
        syncErrorMessage: String = "",
        lastRemoteUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.title = title
        self.itemNames = itemNames
        self.itemIDsData = try? JSONEncoder().encode(itemIDs)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isShared = isShared
        self.imageData = imageData
        self.remoteImageURL = remoteImageURL
        self.personImageData = personImageData
        self.aiTryOnImageData = aiTryOnImageData
        self.deletedAt = deletedAt
        self.serverOutfitID = serverOutfitID
        self.syncStatusRaw = syncStatusRaw
        self.syncRetryCount = syncRetryCount
        self.syncErrorMessage = syncErrorMessage
        self.lastRemoteUpdatedAt = lastRemoteUpdatedAt
    }

    var itemIDs: [UUID] {
        get {
            guard let itemIDsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: itemIDsData)) ?? []
        }
        set { itemIDsData = try? JSONEncoder().encode(newValue) }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
}
