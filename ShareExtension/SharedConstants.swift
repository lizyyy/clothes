// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 分享扩展共享层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedConstants.swift
//  ClothesShareExtension
//
//  Created by Codex on 2026/1/15.
//

import Foundation

enum SharedConstants {
    // TODO: Replace with your actual App Group ID and enable it in both app + share extension targets.
    static let appGroupID = "group.x.Clothes"
    static let sharedImportsKey = "shared_import_items"
    static let sharedImportFolder = "SharedImports"
}
