// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  LocalWardrobeAnalysisService.swift
//  Clothes
//
//  完整的本地衣橱分析服务：分割 + 分类
//  整合 LocalImageSegmentationService 和 LocalClothingClassifier
//

import Foundation
import UIKit

/// 完整的衣橱分析结果
struct WardrobeAnalysisResult: Identifiable, Codable {
    let id: String
    let category: String       // 最终分类: 上衣/外套/长裤/鞋子等
    let confidence: Float      // 分类置信度
    let bbox: CGRect           // 在原图中的位置
    let croppedImage: Data      // 裁剪后的图片 (JPEG)
}

/// 本地衣橱分析服务
final class LocalWardrobeAnalysisService {
    static let shared = LocalWardrobeAnalysisService()

    private let segmentationService = LocalImageSegmentationService.shared
    private let classifier = LocalClothingClassifier.shared

    // MARK: - Initialization

    /// 初始化所有模型（建议在 App 启动时调用）
    func initialize() async throws {
        // 初始化分类器
        try await classifier.initializeAsync()
        print("✅ LocalWardrobeAnalysisService 初始化完成")
    }

    // MARK: - Public Methods

    /// 分析图片：分割 + 分类
    /// - Parameters:
    ///   - image: 输入图片
    ///   - minConfidence: 最低置信度阈值，默认 0.5
    /// - Returns: 分析结果数组
    func analyze(
        image: UIImage,
        minConfidence: Float = 0.5
    ) async throws -> [WardrobeAnalysisResult] {
        // 1. 分割图片
        print("🔪 开始分割...")
        let segmentationResults = try await segmentationService.segmentClothingItems(from: image)

        guard !segmentationResults.isEmpty else {
            throw AnalysisError.noItemsFound
        }

        print("   分割完成，发现 \(segmentationResults.count) 个区域")

        // 2. 对每个分割区域进行分类
        var analysisResults: [WardrobeAnalysisResult] = []

        print("🧠 开始分类...")

        for segment in segmentationResults {
            guard let croppedData = segment.croppedImage,
                  let croppedImage = UIImage(data: croppedData) else {
                continue
            }

            do {
                let classification = try await classifier.classify(image: croppedImage)

                // 过滤低置信度结果
                if classification.confidence >= minConfidence {
                    let result = WardrobeAnalysisResult(
                        id: segment.id,
                        category: classification.category,
                        confidence: classification.confidence,
                        bbox: segment.bbox,
                        croppedImage: croppedData
                    )
                    analysisResults.append(result)
                }
            } catch {
                print("   分类失败: \(error.localizedDescription)")
                continue
            }
        }

        print("   分类完成，有效结果 \(analysisResults.count) 个")

        // 3. 按置信度排序
        analysisResults.sort { $0.confidence > $1.confidence }

        return analysisResults
    }

    /// 简化版本：直接返回分类结果（不分割）
    func classifySimple(image: UIImage) async throws -> ClassificationResult {
        try await classifier.classify(image: image)
    }
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case noItemsFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .noItemsFound:
            return "未检测到衣物"
        case .processingFailed:
            return "处理失败"
        }
    }
}

// MARK: - Convenience Extension

extension UIImage {
    /// 快速分析（分割+分类）
    func analyzeWardrobe() async throws -> [WardrobeAnalysisResult] {
        try await LocalWardrobeAnalysisService.shared.analyze(image: self)
    }
}
