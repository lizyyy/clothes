// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation

enum TryOnErrorReporting {
    static func resolvedMessage(from error: Error) -> String {
        if let serviceError = error as? ServiceError {
            return "[\(serviceError.errno)] \(serviceError.message)"
        }
        let message = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "生成失败，请稍后重试。" : message
    }

    static func reportGenerationFailure(
        action: String,
        screen: String,
        error: Error,
        extraContext: [String: Any]
    ) {
        var context = extraContext
        context["error_type"] = String(describing: type(of: error))
        context["error"] = String(describing: error)
        if let serviceError = error as? ServiceError {
            context["errno"] = serviceError.errno
            context["service_message"] = serviceError.message
        }

        ErrorReporter.report(
            message: "\(action): \(resolvedMessage(from: error))",
            errorCode: ErrorReporter.ERROR_TRYON_GENERATION_FAILED,
            screen: screen,
            context: context
        )
    }

    @discardableResult
    static func handleOutfitPreviewFailure(
        error: Error,
        selectedItemCount: Int,
        clothingImageCount: Int,
        promptLength: Int,
        hasPersonPhoto: Bool
    ) -> String {
        let message = resolvedMessage(from: error)
        reportGenerationFailure(
            action: "Outfit preview generation failed",
            screen: "OutfitsTabView.generatePreview",
            error: error,
            extraContext: [
                "selected_item_count": selectedItemCount,
                "clothing_image_count": clothingImageCount,
                "prompt_length": promptLength,
                "has_person_photo": hasPersonPhoto
            ]
        )
        return message
    }

    @discardableResult
    static func handleTryOnGenerationFailure(
        error: Error,
        recordID: UUID,
        itemCount: Int,
        clothingImageCount: Int,
        hasModelImage: Bool,
        promptLength: Int
    ) -> String {
        let message = resolvedMessage(from: error)
        reportGenerationFailure(
            action: "Try-on generation failed",
            screen: "TryOnTabView.generateTryOn",
            error: error,
            extraContext: [
                "record_id": recordID.uuidString,
                "item_count": itemCount,
                "clothing_image_count": clothingImageCount,
                "has_model_image": hasModelImage,
                "prompt_length": promptLength
            ]
        )
        return message
    }

    @discardableResult
    static func handleModelGenerationFailure(
        error: Error,
        height: String,
        weight: String,
        hasPhoto: Bool,
        size: String
    ) -> String {
        let message = resolvedMessage(from: error)
        reportGenerationFailure(
            action: "Try-on model generation failed",
            screen: "TryOnModelSheet.generateModel",
            error: error,
            extraContext: [
                "height": height,
                "weight": weight,
                "has_photo": hasPhoto,
                "size": size
            ]
        )
        return message
    }
}
