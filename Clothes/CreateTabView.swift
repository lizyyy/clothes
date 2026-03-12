// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  CreateTabView.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import SwiftData
import SwiftUI

struct CreateTabView: View {
    @Binding var selectedTab: Tab
    @State private var showTryOnFromCreate = false
    @State private var showAIStyling = false
    @AppStorage("auth_username") private var authUsername = ""
    @Query private var clothingItems: [ClothingItem]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer(minLength: 0)

                        CreateFeatureCard(
                            title: "DIY 穿搭",
                            subtitle: "搭出创意好品味",
                            background: Color(red: 0.94, green: 0.94, blue: 0.97),
                            iconBackground: Color.white,
                            systemImage: "tshirt"
                        ) {
                            showTryOnFromCreate = true
                        }

                        CreateFeatureCard(
                            title: "AI 智能搭配",
                            subtitle: "AI 帮你搭出无限可能",
                            background: Color(red: 0.36, green: 0.37, blue: 0.78),
                            titleColor: .white,
                            subtitleColor: Color.white.opacity(0.85),
                            iconBackground: Color.white.opacity(0.15),
                            systemImage: "sparkles"
                        ) {
                            showAIStyling = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, minHeight: 560, alignment: .bottom)
                    .adaptiveContentWidth(maxWidth: 700)
                }
            }
            .navigationTitle("AI场景搭配")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showTryOnFromCreate) {
            NavigationStack {
                OutfitTryOnView(wardrobeItems: activeClothingItems)
            }
        }
        .fullScreenCover(isPresented: $showAIStyling) {
            TryOnTabView()
        }
    }

    private var activeClothingItems: [ClothingItem] {
        let owner = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = owner.isEmpty ? SharedConstants.guestOwnerKey : owner
        let isGuest = key == SharedConstants.guestOwnerKey
        return clothingItems.filter {
            $0.deletedAt == nil && ($0.ownerUsername == key || (isGuest && $0.ownerUsername.isEmpty))
        }
    }

}

private struct CreateFeatureCard: View {
    let title: String
    let subtitle: String
    let background: Color
    let titleColor: Color
    let subtitleColor: Color
    let iconBackground: Color
    let systemImage: String
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        background: Color,
        titleColor: Color = Color(red: 0.18, green: 0.16, blue: 0.14),
        subtitleColor: Color = Color(red: 0.56, green: 0.52, blue: 0.48),
        iconBackground: Color,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.background = background
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.iconBackground = iconBackground
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(titleColor)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(subtitleColor)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .fill(iconBackground)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.title2)
                            .foregroundStyle(titleColor)
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(background)
            )
        }
        .buttonStyle(.appPlain)
    }
}
