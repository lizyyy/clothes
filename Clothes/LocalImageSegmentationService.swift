// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  LocalImageSegmentationService.swift
//  Clothes
//
//  使用 Apple Vision 框架进行本地图像分割
//

import Foundation
import UIKit
import Vision
import CoreImage
import CoreML

/// 分割结果
struct SegmentationResult: Identifiable, Codable {
    let id: String
    let category: String
    let confidence: Float
    let bbox: CGRect
    let mask: Data?  // 前景 mask (PNG)
    let croppedImage: Data?  // 裁剪后的图片
}

/// 本地图像分割服务
final class LocalImageSegmentationService {
    static let shared = LocalImageSegmentationService()

    // MARK: - Public Methods

    /// 分割图片中的衣物
    /// - Parameters:
    ///   - image: 输入图片
    ///   - completion: 回调结果
    func segmentClothingItems(
        from image: UIImage,
        completion: @escaping (Result<[SegmentationResult], Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(SegmentationError.invalidImage))
            return
        }

        // 1. 使用 VNGenerateForegroundInstanceMaskRequest (iOS 17+)
        // 或者 VNGeneratePersonSegmentationRequest (iOS 15+)
        if #available(iOS 17.0, *) {
            generateForegroundMask(cgImage: cgImage, originalImage: image, completion: completion)
        } else {
            // 降级方案：使用物体检测
            detectObjects(cgImage: cgImage, originalImage: image, completion: completion)
        }
    }

    /// 异步版本
    func segmentClothingItems(from image: UIImage) async throws -> [SegmentationResult] {
        try await withCheckedThrowingContinuation { continuation in
            segmentClothingItems(from: image) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - iOS 17+ Foreground Mask

    @available(iOS 17.0, *)
    private func generateForegroundMask(
        cgImage: CGImage,
        originalImage: UIImage,
        completion: @escaping (Result<[SegmentationResult], Error>) -> Void
    ) {
        let request = VNGenerateForegroundInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    DispatchQueue.main.async {
                        completion(.failure(SegmentationError.noResults))
                    }
                    return
                }

                var results: [SegmentationResult] = []

                // 遍历所有检测到的物体
                for (index, instance) in result.allInstances.enumerated() {
                    guard let instanceMask = try? result.generateScaledMaskForImage(
                        forInstances: IndexSet(integer: instance),
                        from: handler
                    ) else { continue }

                    // 提取 mask 区域
                    if let croppedResult = self.extractCroppedImage(
                        from: cgImage,
                        mask: instanceMask,
                        originalImage: originalImage,
                        instanceId: index
                    ) {
                        results.append(croppedResult)
                    }
                }

                DispatchQueue.main.async {
                    completion(.success(results))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Object Detection (iOS 15+ Fallback)

    private func detectObjects(
        cgImage: CGImage,
        originalImage: UIImage,
        completion: @escaping (Result<[SegmentationResult], Error>) -> Void
    ) {
        // 使用 VNRecognizeAnimalsRequest 或 VNRecognizeTextRequest 等
        // 这里使用 general object detection 的替代方案
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  !observations.isEmpty else {
                // 没有检测到人体，尝试其他方法
                self?.detectRectangularRegions(cgImage: cgImage, originalImage: originalImage, completion: completion)
                return
            }

            // 根据人体姿态估算衣服区域
            var results: [SegmentationResult] = []

            // 简化：直接返回原图作为整体
            let result = SegmentationResult(
                id: UUID().uuidString,
                category: "待识别",
                confidence: 0.5,
                bbox: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height),
                mask: nil,
                croppedImage: originalImage.jpegData(compressionQuality: 0.8)
            )
            results.append(result)

            DispatchQueue.main.async {
                completion(.success(results))
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

    // MARK: - Rectangle Detection

    private func detectRectangularRegions(
        cgImage: CGImage,
        originalImage: UIImage,
        completion: @escaping (Result<[SegmentationResult], Error>) -> Void
    ) {
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let observations = request.results as? [VNRectangleObservation],
                  !observations.isEmpty else {
                // 没有检测到矩形，返回原图
                let result = SegmentationResult(
                    id: UUID().uuidString,
                    category: "待识别",
                    confidence: 0.3,
                    bbox: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height),
                    mask: nil,
                    croppedImage: originalImage.jpegData(compressionQuality: 0.8)
                )
                DispatchQueue.main.async {
                    completion(.success([result]))
                }
                return
            }

            var results: [SegmentationResult] = []

            for (index, observation) in observations.enumerated() {
                let boundingBox = observation.boundingBox

                // 转换坐标
                let rect = CGRect(
                    x: boundingBox.origin.x * CGFloat(cgImage.width),
                    y: (1 - boundingBox.origin.y - boundingBox.height) * CGFloat(cgImage.height),
                    width: boundingBox.width * CGFloat(cgImage.width),
                    height: boundingBox.height * CGFloat(cgImage.height)
                )

                // 裁剪图片
                if let croppedImage = self.cropImage(originalImage, to: rect) {
                    let result = SegmentationResult(
                        id: "rect_\(index)",
                        category: "待识别",
                        confidence: Float(observation.confidence),
                        bbox: rect,
                        mask: nil,
                        croppedImage: croppedImage.jpegData(compressionQuality: 0.8)
                    )
                    results.append(result)
                }
            }

            DispatchQueue.main.async {
                completion(.success(results))
            }
        }

        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.1
        request.maximumObservations = 10

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

    // MARK: - Helper Methods

    private func extractCroppedImage(
        from cgImage: CGImage,
        mask: CVPixelBuffer,
        originalImage: UIImage,
        instanceId: Int
    ) -> SegmentationResult? {
        let ciContext = CIContext()

        // 获取 mask 的尺寸
        let maskWidth = CVPixelBufferGetWidth(mask)
        let maskHeight = CVPixelBufferGetHeight(mask)

        // 创建 CIImage from mask
        let maskImage = CIImage(cvPixelBuffer: mask)

        // 缩放 mask 到原图尺寸
        let scaleX = CGFloat(cgImage.width) / CGFloat(maskWidth)
        let scaleY = CGFloat(cgImage.height) / CGFloat(maskHeight)
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // 提取 mask 区域
        let originalCIImage = CIImage(cgImage: cgImage)

        // 创建 mask 应用
        guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
        filter.setValue(originalCIImage, forKey: kCIInputImageKey)
        filter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)

        guard let outputImage = filter.outputImage else { return nil }

        // 渲染
        guard let outputCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        let croppedUIImage = UIImage(cgImage: outputCGImage)

        // 计算 bounding box
        let bbox = CGRect(
            x: 0,
            y: 0,
            width: cgImage.width,
            height: cgImage.height
        )

        return SegmentationResult(
            id: "instance_\(instanceId)",
            category: "待识别",
            confidence: 0.8,
            bbox: bbox,
            mask: croppedUIImage.pngData(),
            croppedImage: croppedUIImage.jpegData(compressionQuality: 0.8)
        )
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // 确保 rect 在图片范围内
        let scaledRect = CGRect(
            x: max(0, rect.origin.x),
            y: max(0, rect.origin.y),
            width: min(rect.width, CGFloat(cgImage.width) - rect.origin.x),
            height: min(rect.height, CGFloat(cgImage.height) - rect.origin.y)
        )

        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Errors

enum SegmentationError: LocalizedError {
    case invalidImage
    case noResults
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图片"
        case .noResults:
            return "未检测到物体"
        case .processingFailed:
            return "处理失败"
        }
    }
}

// MARK: - Convenience Extension

extension UIImage {
    /// 快速分割
    func segmentClothing() async throws -> [SegmentationResult] {
        try await LocalImageSegmentationService.shared.segmentClothingItems(from: self)
    }
}
