// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  LaunchLoadingOverlay.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import SwiftUI

struct LaunchLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            VStack(spacing: 14) {
                LaunchHangerAnimationView()
                Text("加载中…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.7))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
        }
    }
}

private struct LaunchHangerAnimationView: View {
    @State private var isAnimating = false

    var body: some View {
        LaunchHangerShape()
            .stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 46, height: 36)
            .rotationEffect(.degrees(isAnimating ? 10 : -10), anchor: .top)
            .animation(
                .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                // 确保在主线程上立即开始动画
                isAnimating = true
            }
    }
}

private struct LaunchHangerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let hookRadius = rect.width * 0.18
        let hookCenter = CGPoint(x: rect.midX, y: rect.minY + hookRadius)

        path.addArc(
            center: hookCenter,
            radius: hookRadius,
            startAngle: .degrees(200),
            endAngle: .degrees(-20),
            clockwise: false
        )

        let topPoint = CGPoint(x: rect.midX, y: rect.minY + hookRadius * 2.2)
        let leftPoint = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.08)
        let rightPoint = CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY - rect.height * 0.08)

        path.move(to: topPoint)
        path.addLine(to: leftPoint)
        path.addLine(to: rightPoint)
        path.addLine(to: topPoint)
        return path
    }
}
