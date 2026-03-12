// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation
import UIKit

@MainActor
struct AIVirtualTryOnService {
    func generateTryOn(prompt: String, images: [Data]) async throws -> URL {
        let endpoint = aiImageGenerationsEndpoint()
        let model = "doubao-seedream-5-0-260128"
        do {
            return try await generateWithUploadedURLs(
                endpoint: endpoint,
                model: model,
                prompt: prompt,
                images: images,
                scope: "ai-tryon"
            )
        } catch TryOnError.server(let message) where shouldFallbackToInlineImages(message: message) {
            return try await generateWithInlineBase64(endpoint: endpoint, model: model, prompt: prompt, images: images)
        }
    }

    func generateBaseModel(personImage: Data, height: String, weight: String, size: String) async throws -> URL {
        let endpoint = aiImageGenerationsEndpoint()
        let model = "doubao-seedream-5-0-260128"
        let prompt = AIPrompts.baseModel(height: height, weight: weight, size: size)
        let images = [personImage]
        do {
            return try await generateWithUploadedURLs(
                endpoint: endpoint,
                model: model,
                prompt: prompt,
                images: images,
                scope: "ai-model"
            )
        } catch TryOnError.server(let message) where shouldFallbackToInlineImages(message: message) {
            return try await generateWithInlineBase64(endpoint: endpoint, model: model, prompt: prompt, images: images)
        }
    }

    func parseOutfit(imageData: Data) async throws -> [String: Data] {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        let endpoint = aiChatCompletionsEndpoint()
        guard let resized = resizedJPEGData(from: imageData, maxDimension: 1536, compression: 0.85) else {
            throw TryOnError.invalidResponse
        }
        let base64 = "data:image/jpeg;base64,\(resized.base64EncodedString())"
        let requestBody = VisionChatCompletionRequest(
            model: "doubao-vision-pro",
            maxCompletionTokens: 2048,
            messages: [
                VisionChatMessage(role: "user", content: [
                    .text(AIPrompts.outfitParsing),
                    .imageURL(base64)
                ])
            ]
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }

        let wrapped = try JSONDecoder().decode(WrappedVisionChatCompletionResponse.self, from: data)
        guard wrapped.errno == 0 else {
            throw TryOnError.server(wrapped.errmsg)
        }
        if let error = wrapped.error {
            throw TryOnError.server("\(error.code): \(error.message)")
        }
        guard let decoded = wrapped.data,
              let text = decoded.choices.first?.message.content.first?.text,
              let json = extractFirstJSONObjectFromTryOnResponse(text) else {
            throw TryOnError.noResult
        }
        guard let resultData = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw TryOnError.invalidResponse
        }
        var outputs: [String: Data] = [:]
        for (key, value) in object {
            guard let base64Value = value as? String else { continue }
            let cleaned = base64Value
                .replacingOccurrences(of: "data:image/png;base64,", with: "")
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            if let data = Data(base64Encoded: cleaned) {
                outputs[key] = data
            }
        }
        return outputs
    }

    func parseOutfitViaBackend(imageData: Data) async throws -> [String: Data] {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        guard let resized = resizedJPEGData(from: imageData, maxDimension: 1536, compression: 0.85) else {
            throw TryOnError.invalidResponse
        }
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/ai/wardrobe/decompose")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["image": resized.base64EncodedString()])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<WardrobeDecomposePayload>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw TryOnError.server(envelope.errmsg)
        }

        var outputs: [String: Data] = [:]
        for (key, value) in payload.parts {
            let cleaned = value
                .replacingOccurrences(of: "data:image/png;base64,", with: "")
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            if let data = Data(base64Encoded: cleaned), !data.isEmpty {
                outputs[key] = data
            }
        }
        return outputs
    }

    func classifyGarmentViaBackend(imageData: Data) async throws -> String? {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        guard let resized = resizedJPEGData(from: imageData, maxDimension: 1024, compression: 0.85) else {
            throw TryOnError.invalidResponse
        }
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/ai/wardrobe/classify")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["image": resized.base64EncodedString()])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<WardrobeClassifyPayload>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw TryOnError.server(envelope.errmsg)
        }
        return payload.category
    }

    func removeBackground(imageData: Data) async throws -> Data {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        let endpoint = aiImageGenerationsEndpoint()
        guard let resized = resizedJPEGData(from: imageData, maxDimension: 2048, compression: 0.9) else {
            throw TryOnError.invalidResponse
        }

        let base64 = resized.base64EncodedString()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = BackgroundRemovalRequest(
            model: "doubao-seededit-3-0-i2i",
            prompt: AIPrompts.backgroundRemoval,
            image: [base64],
            size: "2048x2048",
            responseFormat: "b64_json",
            watermark: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }

        let decoded = try JSONDecoder().decode(BackgroundRemovalResponse.self, from: data)
        if let error = decoded.error {
            throw TryOnError.server("\(error.code): \(error.message)")
        }
        guard let b64 = decoded.data.first?.b64Json, let outputData = Data(base64Encoded: b64) else {
            throw TryOnError.noResult
        }
        return outputData
    }

    func generateFlatLay(imageData: Data, prompt: String) async throws -> URL {
        let endpoint = aiImageGenerationsEndpoint()
        guard let resized = resizedJPEGData(from: imageData, maxDimension: 2048, compression: 0.85) else {
            throw TryOnError.invalidResponse
        }

        let base64 = resized.base64EncodedString()
        let model = "doubao-seedream-5-0-260128"
        let request = try buildGenerationRequest(
            endpoint: endpoint,
            model: model,
            prompt: prompt,
            image: [base64],
            size: "2048x2048"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
#if DEBUG
            print("FlatLay request failed status:", httpResponse.statusCode)
#endif
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }
        let wrapped = try JSONDecoder().decode(WrappedGenerationResponse.self, from: data)
        guard wrapped.errno == 0 else {
#if DEBUG
            print("FlatLay response error:", wrapped.errmsg)
#endif
            throw TryOnError.server(wrapped.errmsg)
        }
        if let error = wrapped.error {
#if DEBUG
            print("FlatLay response error:", error.code)
#endif
            throw TryOnError.server("\(error.code): \(error.message)")
        }
        guard let decoded = wrapped.data,
              let urlString = decoded.data.first?.url, let url = URL(string: urlString) else {
            throw TryOnError.noResult
        }
        return url
    }

    private func resizedJPEGData(from data: Data, maxDimension: CGFloat, compression: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let pixelWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width))
        let pixelHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height))
        let maxSide = max(pixelWidth, pixelHeight)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let newSize = CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: compression)
    }

    private func buildGenerationRequest(
        endpoint: URL,
        model: String,
        prompt: String,
        image: [String],
        size: String
    ) throws -> URLRequest {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = GenerationRequest(
            model: model,
            prompt: prompt,
            image: image,
            size: size,
            sequentialImageGeneration: "disabled",
            responseFormat: "url",
            watermark: false
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func aiImageGenerationsEndpoint() -> URL {
        URL(string: "\(APIConfig.baseURL)/api/v1/ai/images/generations")!
    }

    private func aiChatCompletionsEndpoint() -> URL {
        URL(string: "\(APIConfig.baseURL)/api/v1/ai/chat/completions")!
    }

    private func generateWithUploadedURLs(
        endpoint: URL,
        model: String,
        prompt: String,
        images: [Data],
        scope: String
    ) async throws -> URL {
        let imageURLs = try await uploadImagesAndBuildPublicURLs(images, scope: scope)
        let body = GenerationRequest(
            model: model,
            prompt: prompt,
            image: imageURLs,
            size: "1440x2560",
            sequentialImageGeneration: "disabled",
            responseFormat: "url",
            watermark: false
        )
        return try await requestGenerationURL(endpoint: endpoint, body: body)
    }

    private func generateWithInlineBase64(endpoint: URL, model: String, prompt: String, images: [Data]) async throws -> URL {
        do {
            let imageInputs = try prepareGenerationImages(images, includeDataURLPrefix: true)
            let body = GenerationRequest(
                model: model,
                prompt: prompt,
                image: imageInputs,
                size: "1440x2560",
                sequentialImageGeneration: "disabled",
                responseFormat: "url",
                watermark: false
            )
            return try await requestGenerationURL(endpoint: endpoint, body: body)
        } catch TryOnError.server(let message) where message.localizedCaseInsensitiveContains("invalid base64") {
            let imageInputs = try prepareGenerationImages(images, includeDataURLPrefix: false)
            let body = GenerationRequest(
                model: model,
                prompt: prompt,
                image: imageInputs,
                size: "1440x2560",
                sequentialImageGeneration: "disabled",
                responseFormat: "url",
                watermark: false
            )
            return try await requestGenerationURL(endpoint: endpoint, body: body)
        }
    }

    private func uploadImagesAndBuildPublicURLs(_ images: [Data], scope: String) async throws -> [String] {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        let api = ClothesAPIService.shared
        api.setAuthToken(token)

        var urls: [String] = []
        urls.reserveCapacity(images.count)
        for (index, rawData) in images.enumerated() {
            guard let resized = resizedJPEGData(from: rawData, maxDimension: 1536, compression: 0.82) else {
                continue
            }
            let uploaded = try await api.uploadFile(
                data: resized,
                fileName: "ai-\(scope)-\(index)-\(UUID().uuidString).jpg",
                scope: scope
            )

            let publicCandidate = uploaded.public_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let absolute = URL(string: publicCandidate), absolute.scheme != nil, absolute.host != nil {
                urls.append(absolute.absoluteString)
                continue
            }

            if let absolute = SharedConstants.resolvedImageURL(from: uploaded.url)?.absoluteString {
                urls.append(absolute)
            }
        }

        guard !urls.isEmpty else {
            throw TryOnError.noResult
        }
        return urls
    }

    private func shouldFallbackToInlineImages(message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("timeout while downloading url") ||
            lowercased.contains("invalidparameter") ||
            lowercased.contains("invalid url") ||
            lowercased.contains("invalid image url")
    }

    private func prepareGenerationImages(_ images: [Data], includeDataURLPrefix: Bool) throws -> [String] {
        let outputs = images.compactMap { data -> String? in
            guard let resized = resizedJPEGData(from: data, maxDimension: 1536, compression: 0.82) else {
                return nil
            }
            let payload = resized.base64EncodedString()
            if includeDataURLPrefix {
                return "data:image/jpeg;base64,\(payload)"
            }
            return payload
        }
        guard !outputs.isEmpty else {
            throw TryOnError.noResult
        }
        return outputs
    }

    private func requestGenerationURL(endpoint: URL, body: GenerationRequest) async throws -> URL {
        let token = UserDefaults.standard.string(forKey: "auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw TryOnError.server("请先登录后再操作。")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw TryOnError.server(message)
        }

        let wrapped = try JSONDecoder().decode(WrappedGenerationResponse.self, from: data)
        guard wrapped.errno == 0 else {
            throw TryOnError.server(wrapped.errmsg)
        }
        if let error = wrapped.error {
            throw TryOnError.server("\(error.code): \(error.message)")
        }
        let generatedURLs = wrapped.data?.data.compactMap { image in
            image.url?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty } ?? []
        if let urlString = generatedURLs.first,
           let url = URL(string: urlString) {
            return url
        }

        if let inlineB64 = wrapped.data?.data.compactMap({ $0.b64Json }).first,
           let fileURL = persistInlineImageToTempFile(base64: inlineB64) { return fileURL }
        if let fallbackURL = resolveURLFromRawGenerationPayload(data) { return fallbackURL }
        if let fallbackError = resolveServerErrorFromRawGenerationPayload(data) { throw TryOnError.server(fallbackError) }
        if let payloadSummary = summarizeRawGenerationPayload(data) { throw TryOnError.server(payloadSummary) }
        throw TryOnError.noResult
    }

    private func resolveURLFromRawGenerationPayload(_ data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let rawURL = extractString(keys: ["url", "image_url", "output_url", "result_url"], from: object),
           let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil {
            return url
        }
        if let url = extractFirstURLCandidate(from: object) { return url }
        let rawB64 = extractString(keys: ["b64_json", "image_base64", "base64", "image"], from: object)
            ?? extractFirstInlineImageCandidate(from: object)
        guard let rawB64 else { return nil }
        return persistInlineImageToTempFile(base64: rawB64)
    }

    private func extractString(keys: [String], from object: Any) -> String? {
        if let dict = object as? [String: Any] {
            for key in keys {
                if let value = dict[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            }
            for value in dict.values {
                if let found = extractString(keys: keys, from: value) { return found }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = extractString(keys: keys, from: item) { return found }
            }
        }
        return nil
    }

    private func extractFirstURLCandidate(from object: Any) -> URL? {
        if let string = object as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
               ["http", "https", "file"].contains(scheme), !trimmed.isEmpty {
                return url
            }
            return nil
        }
        if let dict = object as? [String: Any] {
            for value in dict.values {
                if let url = extractFirstURLCandidate(from: value) { return url }
            }
            return nil
        }
        if let array = object as? [Any] {
            for value in array {
                if let url = extractFirstURLCandidate(from: value) { return url }
            }
            return nil
        }
        return nil
    }

    private func extractFirstInlineImageCandidate(from object: Any) -> String? {
        if let string = object as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("data:image/") || looksLikeBase64ImagePayload(trimmed) {
                return trimmed
            }
            return nil
        }
        if let dict = object as? [String: Any] {
            for value in dict.values {
                if let candidate = extractFirstInlineImageCandidate(from: value) { return candidate }
            }
            return nil
        }
        if let array = object as? [Any] {
            for value in array {
                if let candidate = extractFirstInlineImageCandidate(from: value) { return candidate }
            }
            return nil
        }
        return nil
    }

    private func looksLikeBase64ImagePayload(_ value: String) -> Bool {
        let cleaned = value.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 256 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard cleaned.rangeOfCharacter(from: allowed.inverted) == nil else { return false }
        return Data(base64Encoded: cleaned) != nil
    }

    private func resolveServerErrorFromRawGenerationPayload(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return extractErrorMessage(from: object)
    }

    private func extractErrorMessage(from object: Any) -> String? {
        if let dict = object as? [String: Any] {
            if let errorValue = dict["error"], let nested = extractErrorMessage(from: errorValue) {
                return nested
            }
            let code = normalizeServerMessage(dict["code"] as? String)
                ?? normalizeServerMessage(dict["error_code"] as? String)
            let message = normalizeServerMessage(dict["message"] as? String)
                ?? normalizeServerMessage(dict["errmsg"] as? String)
                ?? normalizeServerMessage(dict["msg"] as? String)
                ?? normalizeServerMessage(dict["detail"] as? String)
                ?? normalizeServerMessage(dict["reason"] as? String)
            if let message {
                if let code {
                    return "\(code): \(message)"
                }
                return message
            }
            if let code, code != "0" {
                return code
            }
            let status = normalizeServerMessage(dict["status"] as? String)
                ?? normalizeServerMessage(dict["task_status"] as? String)
            if let status {
                let lowered = status.lowercased()
                if ["pending", "queued", "running", "in_progress", "processing"].contains(lowered) {
                    return "生成任务处理中，请稍后重试。（\(status)）"
                }
            }
            for value in dict.values {
                if let nested = extractErrorMessage(from: value) { return nested }
            }
            return nil
        }
        if let text = object as? String {
            return normalizeServerMessage(text)
        }
        if let array = object as? [Any] {
            for value in array {
                if let nested = extractErrorMessage(from: value) { return nested }
            }
            return nil
        }
        return nil
    }

    private func normalizeServerMessage(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered == "success" || lowered == "ok" || lowered == "null" || lowered == "none" {
            return nil
        }
        return trimmed
    }

    private func summarizeRawGenerationPayload(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let dict = object as? [String: Any] else { return "生成结果缺失，响应结构异常。" }
        let topKeys = dict.keys.sorted()
        let status = extractString(keys: ["status", "task_status"], from: object)
        let errnoValue = dict["errno"].map { "\($0)" }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var segments: [String] = ["生成结果缺失"]
        if !topKeys.isEmpty {
            segments.append("top_keys=\(topKeys.joined(separator: "|"))")
        }
        if let status, !status.isEmpty {
            segments.append("status=\(status)")
        }
        if !errnoValue.isEmpty {
            segments.append("errno=\(errnoValue)")
        }
        return segments.joined(separator: "，")
    }

    private func persistInlineImageToTempFile(base64: String) -> URL? {
        let cleaned = base64.replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: cleaned), !data.isEmpty else { return nil }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tryon-\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch { return nil }
    }
}
