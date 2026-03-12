// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  UIComponents.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import SwiftUI
import UIKit

struct AppWideHitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

struct AppPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == AppPlainButtonStyle {
    static var appPlain: AppPlainButtonStyle { AppPlainButtonStyle() }
}

struct WarmBackdrop: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
}

struct GlassBackdrop: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .background(Color.white.opacity(0.12))
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
}

struct AIGeneratingIconView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 44, height: 44)
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .scaleEffect(isAnimating ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear { isAnimating = true }
        .accessibilityLabel("AI生成中")
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primary)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.appPlain)
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.actionText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.primaryLight.opacity(0.6), lineWidth: 1)
                    )
            )
            .foregroundStyle(AppTheme.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.appPlain)
    }
}

struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

extension View {
    func adaptiveContentWidth(maxWidth: CGFloat = 720) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}

func baseColorName(from selection: String) -> String {
    let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "·", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    return parts.first.map { String($0) } ?? trimmed
}

func selectionHex(from selection: String) -> String? {
    guard let hashIndex = selection.firstIndex(of: "#") else { return nil }
    let hexStart = selection.index(after: hashIndex)
    let hex = selection[hexStart...].prefix(6)
    guard hex.count == 6 else { return nil }
    return "#" + hex
}

func colorFromHexString(_ hex: String) -> Color? {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}

func hexString(from color: Color) -> String? {
    let uiColor = UIColor(color)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
}
