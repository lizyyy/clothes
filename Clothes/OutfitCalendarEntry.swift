// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  OutfitCalendarEntry.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import Foundation
import SwiftData

@Model
final class OutfitCalendarEntry {
    var id: UUID
    // Account partition key. "__guest__" for logged-out local records; otherwise auth_username.
    var ownerUsername: String
    var date: Date
    var title: String
    var outfitID: UUID?

    init(id: UUID = UUID(), ownerUsername: String = "", date: Date, title: String, outfitID: UUID? = nil) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.date = date
        self.title = title
        self.outfitID = outfitID
    }
}
