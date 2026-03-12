// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  LazyView.swift
//  Clothes
//
//  Created by lzy on 2026/1/15.
//

import SwiftUI

/// 懒加载 View，延迟初始化内容直到首次显示
struct LazyView<Content: View>: View {
    private let build: () -> Content
    @State private var isLoaded = false
    
    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: some View {
        Group {
            if isLoaded {
                build()
            } else {
                // 显示占位视图，避免黑屏
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .task {
                    // 立即加载，不延迟，确保快速显示
                    isLoaded = true
                }
            }
        }
    }
}
