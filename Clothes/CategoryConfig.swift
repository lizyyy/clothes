// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  CategoryConfig.swift
//  Clothes
//
//  Created by Codex on 2026/1/10.
//

import Foundation

enum CategoryConfig {
    static let categories = [
        "上衣",
        "长裤",
        "短裤",
        "外套",
        "帽子",
        "鞋子",
        "袜子",
        "箱包",
        "饰品"
    ]
    static let categoryOrderWithAll = ["全部"] + categories
    static let allowedCategoriesPrompt = categories.joined(separator: ",")
    static let defaultSubCategories = [
        "T恤", "衬衫", "针织", "卫衣", "牛仔裤", "休闲裤",
        "风衣", "夹克", "运动鞋", "皮鞋", "包", "配饰"
    ]

    static func subCategories(for category: String) -> [String] {
        switch category {
        case "上衣":
            return ["T恤", "衬衫", "针织", "卫衣"]
        case "长裤":
            return ["牛仔裤", "休闲裤", "西裤", "运动裤"]
        case "短裤":
            return ["牛仔短裤", "运动短裤", "工装短裤"]
        case "外套":
            return ["风衣", "夹克", "大衣"]
        case "鞋子":
            return ["运动鞋", "皮鞋", "靴子", "凉鞋"]
        case "袜子":
            return ["短袜", "中筒袜", "长筒袜"]
        case "箱包":
            return ["手提包", "斜挎包", "双肩包"]
        case "饰品":
            return ["项链", "耳环", "戒指", "手表", "围巾"]
        case "帽子":
            return ["棒球帽", "渔夫帽", "毛线帽"]
        default:
            return defaultSubCategories
        }
    }
}
