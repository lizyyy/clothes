// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  InputFieldStyle.swift
//  Clothes
//
//  Created by Codex on 2026/1/10.
//

import SwiftUI

struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.86, green: 0.80, blue: 0.74), lineWidth: 1)
            )
            .foregroundStyle(AppTheme.bodyText)
    }
}

// MARK: - Placeholder 灰色样式

struct PlaceholderGrayStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppTheme.placeholder)
    }
}

extension View {
    func appInputStyle() -> some View {
        modifier(InputFieldStyle())
    }

    func placeholderGrayStyle() -> some View {
        modifier(PlaceholderGrayStyle())
    }
}
