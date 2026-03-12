// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation

struct WardrobeDecomposePayload: Codable {
    let parts: [String: String]
    let rawText: String?

    enum CodingKeys: String, CodingKey {
        case parts
        case rawText = "raw_text"
    }
}

struct WardrobeClassifyPayload: Codable {
    let category: String
    let rawText: String?

    enum CodingKeys: String, CodingKey {
        case category
        case rawText = "raw_text"
    }
}

struct GenerationRequest: Codable {
    let model: String
    let prompt: String
    let image: [String]
    let size: String
    let sequentialImageGeneration: String
    let responseFormat: String
    let watermark: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case image
        case size
        case sequentialImageGeneration = "sequential_image_generation"
        case responseFormat = "response_format"
        case watermark
    }
}

struct WrappedGenerationResponse: Decodable {
    let errno: Int
    let errmsg: String
    let data: GenerationResponse?
    let error: ResponseError?
}

struct GenerationResponse: Decodable {
    let model: String?
    let created: Int?
    let data: [GeneratedImage]

    enum CodingKeys: String, CodingKey {
        case model
        case created
        case data
        case images
        case output
        case url
        case imageURL = "image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try? container.decode(String.self, forKey: .model)
        created = try? container.decode(Int.self, forKey: .created)

        if let values = try? container.decode([GeneratedImage].self, forKey: .data), !values.isEmpty {
            data = values
            return
        }
        if let values = try? container.decode([GeneratedImage].self, forKey: .images), !values.isEmpty {
            data = values
            return
        }
        if let value = try? container.decode(GeneratedImage.self, forKey: .data) {
            data = [value]
            return
        }
        if let value = try? container.decode(GeneratedImage.self, forKey: .output) {
            data = [value]
            return
        }
        if let directURL = (try? container.decode(String.self, forKey: .url)) ?? (try? container.decode(String.self, forKey: .imageURL)) {
            data = [GeneratedImage(url: directURL, size: nil)]
            return
        }
        data = []
    }
}

struct VisionChatCompletionRequest: Codable {
    let model: String
    let maxCompletionTokens: Int
    let messages: [VisionChatMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxCompletionTokens = "max_completion_tokens"
        case messages
    }
}

struct VisionChatMessage: Codable {
    let role: String
    let content: [VisionChatContent]
}

struct VisionChatContent: Codable {
    let type: String
    let text: String?
    let imageURL: VisionChatImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    static func text(_ value: String) -> VisionChatContent {
        VisionChatContent(type: "text", text: value, imageURL: nil)
    }

    static func imageURL(_ value: String) -> VisionChatContent {
        VisionChatContent(type: "image_url", text: nil, imageURL: VisionChatImageURL(url: value))
    }
}

struct VisionChatImageURL: Codable {
    let url: String
}

struct WrappedVisionChatCompletionResponse: Codable {
    let errno: Int
    let errmsg: String
    let data: VisionChatCompletionResponse?
    let error: ResponseError?
}

struct VisionChatCompletionResponse: Codable {
    let choices: [VisionChatChoice]
}

struct VisionChatChoice: Codable {
    let message: VisionChatMessageResponse
}

struct VisionChatMessageResponse: Codable {
    let content: [VisionChatContentResponse]
}

struct VisionChatContentResponse: Codable {
    let type: String
    let text: String?
}

struct BackgroundRemovalRequest: Codable {
    let model: String
    let prompt: String
    let image: [String]
    let size: String
    let responseFormat: String
    let watermark: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case image
        case size
        case responseFormat = "response_format"
        case watermark
    }
}

func extractFirstJSONObjectFromTryOnResponse(_ text: String) -> String? {
    guard let start = text.firstIndex(of: "{"),
          let end = text.lastIndex(of: "}") else { return nil }
    if start >= end { return nil }
    return String(text[start...end])
}

struct BackgroundRemovalResponse: Decodable {
    let model: String
    let created: Int
    let data: [BackgroundRemovalImage]
    let error: ResponseError?
}

struct BackgroundRemovalImage: Codable {
    let b64Json: String?

    enum CodingKeys: String, CodingKey {
        case b64Json = "b64_json"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        b64Json = try? container.decode(String.self, forKey: .b64Json)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(b64Json, forKey: .b64Json)
    }
}

struct GeneratedImage: Decodable {
    let url: String?
    let size: String?
    let b64Json: String?

    enum CodingKeys: String, CodingKey {
        case url
        case imageURL = "image_url"
        case size
        case b64Json = "b64_json"
        case imageBase64 = "image_base64"
        case base64
        case image
    }

    init(url: String?, size: String?, b64Json: String? = nil) {
        self.url = url
        self.size = size
        self.b64Json = b64Json
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let directURL = try? container.decode(String.self, forKey: .url)
        let imageURL = try? container.decode(String.self, forKey: .imageURL)
        url = directURL ?? imageURL
        b64Json = (try? container.decode(String.self, forKey: .b64Json))
            ?? (try? container.decode(String.self, forKey: .imageBase64))
            ?? (try? container.decode(String.self, forKey: .base64))
            ?? (try? container.decode(String.self, forKey: .image))
        if let stringSize = try? container.decode(String.self, forKey: .size) {
            size = stringSize
        } else if let intSize = try? container.decode(Int.self, forKey: .size) {
            size = String(intSize)
        } else {
            size = nil
        }
    }
}

struct ResponseError: Codable {
    let code: String
    let message: String
}

enum TryOnError: LocalizedError {
    case invalidResponse
    case noResult
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务响应异常。"
        case .noResult:
            return "未生成结果图。"
        case .server(let message):
            return message
        }
    }
}
