// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  LocalClothingClassifier.swift
//  Clothes
//
//  使用本地 CoreML 模型进行衣服分类
//

import Foundation
import UIKit
import CoreML
import Vision

/// 分类结果
struct ClassificationResult: Identifiable, Codable {
    let id: String
    let category: String      // 上衣, 外套, 长裤, 短裤, 鞋子, 帽子, 箱包, 袜子, 饰品
    let confidence: Float    // 置信度 0-1
    let allProbabilities: [String: Float]  // 所有类别的概率
}

/// 本地衣服分类器
final class LocalClothingClassifier {
    static let shared = LocalClothingClassifier()

    // 模型配置
    private let modelName = "cclothes"
    private var model: VNCoreMLModel?

    // 类别映射
    private let categoryMapping: [String: String] = [
        "0": "上衣",
        "1": "外套", 
        "2": "长裤",
        "3": "短裤",
        "4": "鞋子",
        "5": "帽子",
        "6": "箱包",
        "7": "袜子",
        "8": "饰品"
    ]

    // 模型路径
    private var modelURL: URL? {
        // 优先从 App Bundle 加载
        if let bundleURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            return bundleURL
        }
        // 其次从 Documents 目录加载
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("\(modelName).mlmodelc")
    }

    // MARK: - Public Methods

    /// 初始化分类器（建议在 App 启动时调用）
    func initialize() throws {
        guard let url = modelURL else {
            throw ClassifierError.modelNotFound
        }

        // 尝试加载 compiled model
        let mlModel = try MLModel(contentsOf: url)
        let visionModel = try VNCoreMLModel(for: mlModel)
        self.model = visionModel
        print("✅ 本地分类模型加载成功: \(url.lastPathComponent)")
    }

    /// 初始化异步版本
    func initializeAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try self.initialize()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 分类单张图片
    /// - Parameters:
    ///   - image: 输入图片 (UIImage)
    ///   - completion: 回调结果
    func classify(
        image: UIImage,
        completion: @escaping (Result<ClassificationResult, Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ClassifierError.invalidImage))
            return
        }

        guard let model = self.model else {
            // 尝试重新初始化
            do {
                try initialize()
            } catch {
                completion(.failure(ClassifierError.modelNotLoaded))
                return
            }
            classify(image: image, completion: completion)
            return
        }

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let observations = request.results as? [VNClassificationObservation],
                  let topResult = observations.first else {
                DispatchQueue.main.async {
                    completion(.failure(ClassifierError.noResult))
                }
                return
            }

            // 解析结果
            var allProbabilities: [String: Float] = [:]
            for obs in observations.prefix(5) {
                let category = self.categoryMapping[obs.identifier] ?? obs.identifier
                allProbabilities[category] = obs.confidence
            }

            let result = ClassificationResult(
                id: UUID().uuidString,
                category: self.categoryMapping[topResult.identifier] ?? topResult.identifier,
                confidence: topResult.confidence,
                allProbabilities: allProbabilities
            )

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 异步版本
    func classify(image: UIImage) async throws -> ClassificationResult {
        try await withCheckedThrowingContinuation { continuation in
            classify(image: image) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// 批量分类
    func classifyBatch(images: [UIImage]) async throws -> [ClassificationResult] {
        var results: [ClassificationResult] = []

        for image in images {
            let result = try await classify(image: image)
            results.append(result)
        }

        return results
    }

    // MARK: - Utility

    /// 检查模型是否可用
    var isModelLoaded: Bool {
        return model != nil
    }

    /// 获取所有支持的类别
    var supportedCategories: [String] {
        return Array(categoryMapping.values).sorted()
    }
}

// MARK: - Errors

enum ClassifierError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case invalidImage
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "分类模型文件未找到"
        case .modelNotLoaded:
            return "分类模型未加载"
        case .invalidImage:
            return "无效的图片"
        case .noResult:
            return "分类失败"
        }
    }
}

// MARK: - Convenience Extension

extension UIImage {
    /// 快速分类
    func classifyClothing() async throws -> ClassificationResult {
        try await LocalClothingClassifier.shared.classify(image: self)
    }
}
