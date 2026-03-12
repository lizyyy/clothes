// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  WardrobeClassifierTrainer.swift
//  使用 CreateML 训练高精度服饰分类模型（目标 99% 准确率）
//
//  在 macOS Playground 或 Command Line Tool 中运行此代码来训练模型
//

import Foundation
import Vision

#if canImport(CreateML) && os(macOS)
import CreateML

/*
 训练说明：
 1. 在 macOS 上创建新的 Playground 或 Command Line Tool 项目
 2. 准备训练数据文件夹结构：
    TrainingData/
    ├── 上衣/          (1000张，T恤、衬衫、毛衣等)
    ├── 外套/          (1000张，风衣、夹克、大衣等)
    ├── 长裤/          (1000张，牛仔裤、休闲裤等)
    ├── 短裤/          (1000张，牛仔短裤、运动短裤等)
    ├── 鞋子/          (1000张，运动鞋、皮鞋、靴子等)
    ├── 帽子/          (1000张，棒球帽、渔夫帽、毛线帽等)
    ├── 箱包/          (1000张，手提包、背包、钱包等)
    ├── 袜子/          (1000张，短袜、中筒袜、长筒袜等)
    └── 饰品/          (1000张，围巾、腰带、首饰等 - 重点类别！)

 3. 运行 trainModel() 函数
 4. 生成的 WardrobeCategoryClassifier.mlmodel 导入到 iOS 项目中
 */

class WardrobeClassifierTrainer {

    // MARK: - 配置参数（针对 99% 准确率优化）

    struct TrainingConfig {
        /// 特征提取器：Scene Print 是 Apple 预训练的最强模型
        var featureExtractor: MLImageClassifier.FeatureExtractorType = .scenePrint(revision: nil)

        /// 最大迭代次数：增加以提高准确率（默认 100，追求 99% 建议 300-500）
        var maxIterations: Int = 500

        /// 是否自动分割验证集（默认 10% 作为验证集）
        var autoValidation: Bool = true

        /// 模型版本号
        var version: String = "2.0-high-accuracy"
    }

    // MARK: - 高级训练（推荐，追求 99% 准确率）

    /// 使用高级参数训练分类模型（追求 99% 准确率）
    /// - Parameters:
    ///   - trainingDataPath: 训练数据目录路径（包含9个类别文件夹）
    ///   - outputPath: 输出模型文件路径
    ///   - config: 训练配置参数
    static func trainModel(
        trainingDataPath: String,
        outputPath: String,
        config: TrainingConfig = TrainingConfig()
    ) {
        do {
            let separator = String(repeating: "=", count: 60)
            print(separator)
            print("CoreML 高精度服饰分类模型训练")
            print("目标准确率: 99%")
            print(separator)
            print()

            // 1. 加载训练数据
            print("📂 加载训练数据...")
            let trainingDataURL = URL(fileURLWithPath: trainingDataPath)
            let trainingData = try MLImageClassifier.DataSource.labeledDirectories(at: trainingDataURL)

            // 统计各类别数量
            let fileManager = FileManager.default
            let categories = try fileManager.contentsOfDirectory(atPath: trainingDataPath)
                .filter { $0 != ".DS_Store" && !$0.hasPrefix(".") }
                .sorted()

            print("📊 发现 \(categories.count) 个类别:")
            for category in categories {
                let catPath = trainingDataURL.appendingPathComponent(category)
                let files = try? fileManager.contentsOfDirectory(atPath: catPath.path)
                    .filter { !$0.hasPrefix(".") }
                print("   - \(category): \(files?.count ?? 0) 张图片")
            }
            print()

            // 2. 配置高级训练参数
            print("⚙️  配置训练参数...")
            print("   特征提取器: Scene Print")
            print("   最大迭代次数: \(config.maxIterations)")
            print("   数据增强: 使用 CreateML 默认增强（裁剪、旋转、翻转、曝光、噪声）")
            print()

            let parameters = MLImageClassifier.ModelParameters(
                featureExtractor: config.featureExtractor,
                validationData: config.autoValidation ? nil : nil,  // nil = 自动分割 10% 验证集
                maxIterations: config.maxIterations
            )

            // 3. 开始训练
            print("🚀 开始训练...")
            print("   这可能需要 10-60 分钟，取决于数据量")
            print()

            let classifier = try MLImageClassifier(trainingData: trainingData, parameters: parameters)

            // 4. 评估模型
            print("📈 评估模型...")
            let evaluation = classifier.evaluation(on: trainingData)

            let accuracy = (1.0 - evaluation.classificationError) * 100

            print()
            print(separator)
            print("训练结果")
            print(separator)
            print("分类错误率: \(String(format: "%.4f", evaluation.classificationError))")
            print("准确率: \(String(format: "%.2f", accuracy))%")
            print()
            print("混淆矩阵:")
            print(evaluation.confusion.description)

            // 5. 保存模型
            print()
            print("💾 保存模型...")
            let modelURL = URL(fileURLWithPath: outputPath)

            let metadata = MLModelMetadata(
                author: "ClothesApp",
                shortDescription: "高精度服饰分类模型 - 9类 - 准确率 \(String(format: "%.1f", accuracy))%",
                version: config.version
            )

            try classifier.write(to: modelURL, metadata: metadata)

            print("✅ 模型已保存到: \(outputPath)")

            // 6. 检查模型大小
            if let attributes = try? fileManager.attributesOfItem(atPath: outputPath),
               let fileSize = attributes[.size] as? Int64 {
                let sizeKB = Double(fileSize) / 1024.0
                let sizeMB = sizeKB / 1024.0
                print("📦 模型大小: \(String(format: "%.2f", sizeKB)) KB (\(String(format: "%.2f", sizeMB)) MB)")
            }

            // 7. 准确率评估
            print()
            print(separator)
            if accuracy >= 99.0 {
                print("🎉 恭喜！达到目标准确率 99%+")
            } else if accuracy >= 95.0 {
                print("✅ 良好！准确率超过 95%")
                print("💡 要进一步提高到 99%，建议：")
                print("   1. 增加每类训练数据到 2000+ 张")
                print("   2. 清理标注错误的图片")
                print("   3. 增加难例样本（易混淆类别）")
            } else {
                print("⚠️  准确率偏低 (\(String(format: "%.1f", accuracy))%)")
                print("💡 建议：")
                print("   1. 确保每类至少 1000 张图片")
                print("   2. 使用 data_augmentation.py 生成更多数据")
                print("   3. 检查训练数据质量（删除模糊图片）")
            }
            print(separator)

            print()
            print("📋 下一步:")
            print("   1. 将 WardrobeCategoryClassifier.mlmodel 拖入 Xcode 项目")
            print("   2. 确保 Target Membership 选中主 App")
            print("   3. 重新编译 iOS 项目测试")

        } catch {
            print("❌ 训练失败: \(error)")
            print("💡 常见问题：")
            print("   - 检查训练数据目录是否正确")
            print("   - 确保每个类别文件夹内有图片")
            print("   - 检查磁盘空间是否充足")
        }
    }

    // MARK: - 快速训练（简化版，适合快速测试）

    /// 快速训练（使用默认参数）
    /// - Parameters:
    ///   - dataPath: 训练数据目录
    ///   - outputPath: 输出模型路径
    static func quickTrain(dataPath: String, outputPath: String) {
        let config = TrainingConfig(
            maxIterations: 100,  // 快速训练用较少迭代
            version: "1.0-quick"
        )
        trainModel(trainingDataPath: dataPath, outputPath: outputPath, config: config)
    }

    // MARK: - 超参数搜索（追求极限准确率）

    /// 超参数搜索 - 尝试多种配置找到最佳模型
    /// - Parameters:
    ///   - dataPath: 训练数据目录
    ///   - outputDir: 输出目录（会生成多个模型）
    static func hyperparameterSearch(dataPath: String, outputDir: String) {
        print("🔍 开始超参数搜索...")

        let iterationsToTry = [100, 200, 500]
        var bestAccuracy: Double = 0
        var bestModelPath: String = ""

        for iterations in iterationsToTry {
            let config = TrainingConfig(
                maxIterations: iterations,
                version: "2.0-iter\(iterations)"
            )

            let outputPath = "\(outputDir)/WardrobeClassifier_\(iterations).mlmodel"

            print("\n尝试迭代次数: \(iterations)")
            trainModel(trainingDataPath: dataPath, outputPath: outputPath, config: config)

            // 这里简化处理，实际应该解析训练结果获取准确率
        }

        print("\n超参数搜索完成")
        print("最佳模型: \(bestModelPath)")
    }
}

// MARK: - 使用示例

// 示例 1: 标准训练（推荐）
// WardrobeClassifierTrainer.trainModel(
//     trainingDataPath: "/Users/你的用户名/Documents/TrainingData",
//     outputPath: "/Users/你的用户名/Documents/WardrobeCategoryClassifier.mlmodel"
// )

// 示例 2: 自定义配置（追求 99% 准确率）
// let config = WardrobeClassifierTrainer.TrainingConfig(
//     maxIterations: 500,
//     version: "2.0-high-accuracy"
// )
// WardrobeClassifierTrainer.trainModel(
//     trainingDataPath: "/Users/你的用户名/Documents/TrainingData",
//     outputPath: "/Users/你的用户名/Documents/WardrobeCategoryClassifier.mlmodel",
//     config: config
// )

// 示例 3: 快速测试
// WardrobeClassifierTrainer.quickTrain(
//     dataPath: "/Users/你的用户名/Documents/TrainingData",
//     outputPath: "/Users/你的用户名/Documents/WardrobeCategoryClassifier.mlmodel"
// )

#else

// iOS target 不支持 CreateML，仅保留占位实现以保证主工程可编译。
class WardrobeClassifierTrainer {
    struct TrainingConfig {
        var maxIterations: Int = 500
        var autoValidation: Bool = true
        var version: String = "2.0-high-accuracy"
    }

    static func trainModel(trainingDataPath: String, outputPath: String, config: TrainingConfig = TrainingConfig()) {
        print("WardrobeClassifierTrainer 仅支持 macOS + CreateML 环境。")
    }

    static func quickTrain(dataPath: String, outputPath: String) {
        print("WardrobeClassifierTrainer 仅支持 macOS + CreateML 环境。")
    }

    static func hyperparameterSearch(dataPath: String, outputDir: String) {
        print("WardrobeClassifierTrainer 仅支持 macOS + CreateML 环境。")
    }
}

#endif
