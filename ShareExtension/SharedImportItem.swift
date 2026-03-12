// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 分享扩展共享层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedImportItem.swift
//  ClothesShareExtension
//
//  Created by Codex on 2026/1/15.
//

import Foundation

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
