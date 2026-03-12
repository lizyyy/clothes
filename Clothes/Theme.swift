// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.184, green: 0.184, blue: 0.184) // #2F2F2F
    static let primaryLight = Color(red: 0.184, green: 0.184, blue: 0.184) // #2F2F2F
    static let placeholder = Color(red: 0.36, green: 0.36, blue: 0.36)
    static let background = Color.white
    static let titleText = Color(red: 0.18, green: 0.14, blue: 0.11)
    static let bodyText = Color(red: 0.24, green: 0.20, blue: 0.16)
    static let actionText = Color(red: 0.36, green: 0.29, blue: 0.23)
    static let secondaryText = Color(red: 0.58, green: 0.52, blue: 0.46)
    static let mutedText = Color(red: 0.56, green: 0.48, blue: 0.40)
    static let subtleText = Color(red: 0.60, green: 0.56, blue: 0.50)
}

// MARK: - 统一按钮样式

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.primary)
            .foregroundStyle(Color.white)
            .clipShape(Capsule())
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundStyle(AppTheme.primary)
            .overlay(
                Capsule()
                    .stroke(AppTheme.primary, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct ToolbarDoneButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.primary)
    }
}

extension View {
    func primaryButton() -> some View {
        modifier(PrimaryButtonStyle())
    }

    func secondaryButton() -> some View {
        modifier(SecondaryButtonStyle())
    }

    func toolbarDoneButton() -> some View {
        modifier(ToolbarDoneButtonStyle())
    }
}
