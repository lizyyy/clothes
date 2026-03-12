// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ShareImportManager.swift
//  Clothes
//
//  Created by Codex on 2026/1/15.
//

import Foundation
import SwiftData
import UIKit

struct SharedImportItem: Codable, Identifiable {
    enum ItemType: String, Codable {
        case image
        case url
    }

    let id: String
    let type: ItemType
    let fileName: String?
    let url: String?
    let createdAt: Double
}

final class ShareImportManager {
    static let shared = ShareImportManager()

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedConstants.appGroupID)
    }

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)
    }

    func importPending(modelContext: ModelContext) async {
        guard let pending = loadPendingItems(), !pending.isEmpty else { return }
        var remaining: [SharedImportItem] = []

        for item in pending {
            var imageData: Data?
            switch item.type {
            case .image:
                imageData = loadImageData(from: item.fileName)
            case .url:
                if let urlString = item.url, let url = URL(string: urlString) {
                    imageData = await downloadImageData(from: url)
                }
            }

            if let data = imageData, UIImage(data: data) != nil {
                await MainActor.run {
                    let username = (UserDefaults.standard.string(forKey: "auth_username") ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let ownerKey = username.isEmpty ? SharedConstants.guestOwnerKey : username
                    let name = "分享导入 \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
                    let newItem = ClothingItem(
                        ownerUsername: ownerKey,
                        name: name,
                        category: "上衣",
                        color: "未知",
                        seasons: [],
                        occasions: [],
                        brand: ""
                    )
                    newItem.imageData = data
                    newItem.syncStatus = .pending
                    newItem.updatedAt = Date()
                    modelContext.insert(newItem)
                    Task { @MainActor in
                        await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
                    }
                }
                cleanupFile(for: item.fileName)
            } else {
                remaining.append(item)
            }
        }

        savePendingItems(remaining)
    }

    private func loadPendingItems() -> [SharedImportItem]? {
        guard let data = userDefaults?.data(forKey: SharedConstants.sharedImportsKey) else { return nil }
        return try? JSONDecoder().decode([SharedImportItem].self, from: data)
    }

    private func savePendingItems(_ items: [SharedImportItem]) {
        if items.isEmpty {
            userDefaults?.removeObject(forKey: SharedConstants.sharedImportsKey)
            return
        }
        if let data = try? JSONEncoder().encode(items) {
            userDefaults?.set(data, forKey: SharedConstants.sharedImportsKey)
        }
    }

    private func loadImageData(from fileName: String?) -> Data? {
        guard let fileName,
              let folder = containerURL?.appendingPathComponent(SharedConstants.sharedImportFolder, isDirectory: true) else {
            return nil
        }
        let fileURL = folder.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    private func cleanupFile(for fileName: String?) {
        guard let fileName,
              let folder = containerURL?.appendingPathComponent(SharedConstants.sharedImportFolder, isDirectory: true) else {
            return
        }
        let fileURL = folder.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func downloadImageData(from url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}
