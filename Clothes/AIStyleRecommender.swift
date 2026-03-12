// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  AIStyleRecommender.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import Foundation

@MainActor
struct AIStyleRecommender {
    func recommendStyle(profile: AIStyleProfile) async throws -> AIStylePlan {
        let endpoint = aiChatCompletionsEndpoint()

        let systemPrompt = AIPrompts.styleSystemPrompt
        let userPrompt = AIPrompts.styleUserPrompt(profile: profile)

        let requestBody = ChatCompletionRequest(
            model: "doubao-seed-1-8-251228",
            maxCompletionTokens: 2048,
            reasoningEffort: "medium",
            messages: [
                .init(role: "system", content: [ChatContent.text(systemPrompt)]),
                .init(role: "user", content: [ChatContent.text(userPrompt)])
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIStyleError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw AIStyleError.server(message)
        }

        let wrapped = try JSONDecoder().decode(WrappedChatCompletionResponse.self, from: data)
        guard wrapped.errno == 0 else {
            throw AIStyleError.server(wrapped.errmsg)
        }
        guard let decoded = wrapped.data,
              let content = decoded.choices.first?.message.content.first?.text else {
            throw AIStyleError.noResult
        }
        return try parsePlan(from: content)
    }

    func recommendDaily(profile: AIStyleProfile, context: DailyContext) async throws -> AIDailyRecommendation {
        let endpoint = aiChatCompletionsEndpoint()

        let systemPrompt = AIPrompts.styleSystemPrompt
        let userPrompt = AIPrompts.dailyUserPrompt(profile: profile, context: context)

        let requestBody = ChatCompletionRequest(
            model: "doubao-seed-1-8-251228",
            maxCompletionTokens: 2048,
            reasoningEffort: "medium",
            messages: [
                .init(role: "system", content: [ChatContent.text(systemPrompt)]),
                .init(role: "user", content: [ChatContent.text(userPrompt)])
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIStyleError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw AIStyleError.server(message)
        }

        let wrapped = try JSONDecoder().decode(WrappedChatCompletionResponse.self, from: data)
        guard wrapped.errno == 0 else {
            throw AIStyleError.server(wrapped.errmsg)
        }
        guard let decoded = wrapped.data,
              let content = decoded.choices.first?.message.content.first?.text else {
            throw AIStyleError.noResult
        }
        return try parseDailyRecommendation(from: content)
    }

    private func parsePlan(from text: String) throws -> AIStylePlan {
        guard let json = extractFirstJSONObject(from: text),
              let data = json.data(using: .utf8) else {
#if DEBUG
            print("AIStyleRecommender.parsePlan invalid JSON")
#endif
            throw AIStyleError.invalidJSON
        }
        return try JSONDecoder().decode(AIStylePlan.self, from: data)
    }

    private func parseDailyRecommendation(from text: String) throws -> AIDailyRecommendation {
        guard let json = extractFirstJSONObject(from: text),
              let data = json.data(using: .utf8) else {
#if DEBUG
            print("AIStyleRecommender.parseDailyRecommendation invalid JSON")
#endif
            throw AIStyleError.invalidJSON
        }
        return try JSONDecoder().decode(AIDailyRecommendation.self, from: data)
    }

    private func aiChatCompletionsEndpoint() -> URL {
        URL(string: "\(APIConfig.baseURL)/api/v1/ai/chat/completions")!
    }
}

struct AIStyleProfile {
    let height: String
    let weight: String
    let occasion: String
    let climate: String
    let colorTaboos: String
    let stylePreference: String
}

struct AIStylePlan: Codable {
    let styleTags: [String]
    let colors: [String]
    let categories: [String]
    let notes: String

    enum CodingKeys: String, CodingKey {
        case styleTags = "style_tags"
        case colors
        case categories
        case notes
    }
}

struct AIDailyRecommendation: Codable {
    let title: String
    let styleTags: [String]
    let colors: [String]
    let categories: [String]
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case styleTags = "style_tags"
        case colors
        case categories
        case reasons
    }
}

struct DailyContext {
    let date: Date
    let name: String
    let location: String
    let weather: String
    let temperature: String
    let isWeekend: Bool
    let calendarSummary: String
    let availableColors: [String]
}

private struct ChatCompletionRequest: Codable {
    let model: String
    let maxCompletionTokens: Int
    let reasoningEffort: String
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxCompletionTokens = "max_completion_tokens"
        case reasoningEffort = "reasoning_effort"
        case messages
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: [ChatContent]
}

private struct ChatContent: Codable {
    let type: String
    let text: String?

    static func text(_ value: String) -> ChatContent {
        ChatContent(type: "text", text: value)
    }
}

// 包装响应 - 匹配后端 errno/errmsg/data 格式
private struct WrappedChatCompletionResponse: Codable {
    let errno: Int
    let errmsg: String
    let data: ChatCompletionResponse?
}

private struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Codable {
    let message: ChatMessageResponse
}

private struct ChatMessageResponse: Codable {
    let content: [ChatContentResponse]
}

private struct ChatContentResponse: Codable {
    let type: String
    let text: String?
}

enum AIStyleError: LocalizedError {
    case invalidResponse
    case noResult
    case invalidJSON
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务响应异常。"
        case .noResult:
            return "没有得到推荐结果。"
        case .invalidJSON:
            return "推荐结果解析失败。"
        case .server(let message):
            return message
        }
    }
}

private func extractFirstJSONObject(from text: String) -> String? {
    guard let start = text.firstIndex(of: "{"),
          let end = text.lastIndex(of: "}") else { return nil }
    if start >= end { return nil }
    return String(text[start...end])
}
