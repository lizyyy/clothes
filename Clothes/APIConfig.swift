// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  APIConfig.swift
//  Clothes
//
//  Created by lzy on 2026/1/15.
//

import Foundation

/// API 配置管理
@MainActor
struct APIConfig {
    /// Go 服务 API 基础地址
    /// 统一从 EnvironmentManager 获取，支持 dev/online 切换
    static var baseURL: String {
        EnvironmentManager.shared.apiBaseURL
    }

    /// 健康检查端点
    static var healthEndpoint: String {
        "\(baseURL)/health"
    }

    /// 认证相关端点
    struct Auth {
        static var register: String { "\(baseURL)/api/v1/auth/register" }
        static var login: String { "\(baseURL)/api/v1/auth/login" }
    }

    /// 穿搭相关端点
    struct Outfits {
        static var base: String { "\(baseURL)/api/v1/outfits" }
        static var publicUri: String { "\(baseURL)/api/v1/outfits/public" }

        static func detail(id: Int64) -> String {
            return "\(baseURL)/api/v1/outfits/\(id)"
        }

        static func share(id: Int64) -> String {
            return "\(baseURL)/api/v1/outfits/\(id)/share"
        }
    }
}
