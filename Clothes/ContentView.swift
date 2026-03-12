// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ContentView.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var envManager: EnvironmentManager
    private let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    @State private var selectedTab: Tab = .wardrobe
    @State private var showLaunchOverlay = !ProcessInfo.processInfo.arguments.contains("-uiTesting") && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LazyView {
                    WardrobeTabView()
                }
                .tabItem {
                    Label("衣橱", systemImage: "square.grid.2x2")
                }
                .tag(Tab.wardrobe)

                LazyView {
                    OutfitsTabView()
                }
                .tabItem {
                    Label("搭配", systemImage: "rectangle.stack")
                }
                .tag(Tab.outfits)

                LazyView {
                    CreateTabView(selectedTab: $selectedTab)
                }
                .tabItem {
                    Label("AI场景搭配", systemImage: "plus.circle.fill")
                }
                .tag(Tab.create)

                LazyView {
                    ExploreTabView()
                }
                .tabItem {
                    Label("探索", systemImage: "sparkles")
                }
                .tag(Tab.explore)

                LazyView {
                    ProfileTabView()
                }
                .tabItem {
                    Label("设置", systemImage: "person.crop.circle")
                }
                .tag(Tab.profile)
            }

            // 环境指示器（仅在 dev 环境显示）
            VStack {
                HStack {
                    EnvironmentIndicator()
                        .padding(.leading, 16)
                        .padding(.top, 8)
                    Spacer()
                }
                Spacer()
            }

            if showLaunchOverlay {
                LaunchLoadingOverlay()
                    .transition(.opacity)
                    .zIndex(1)
                    .allowsHitTesting(false) // 允许点击穿透，避免阻塞交互
            }
        }
        .task {
            guard !isRunningInPreview else { return }
            guard showLaunchOverlay else { return }
            // 使用 task 确保在视图加载后开始倒计时
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 秒
            withAnimation(.easeOut(duration: 0.2)) {
                showLaunchOverlay = false
            }
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
        .task {
            guard !isRunningInPreview else { return }
            // UI test seeding should run even when the launch overlay is disabled.
            seedForUITestingIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !isRunningInPreview else { return }
            if newPhase == .active {
                // UI tests rely on deterministic local state; avoid background sync/network flakiness.
                if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                    return
                }
                Task { @MainActor in
                    await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
                }
            }
        }
        .buttonStyle(AppWideHitButtonStyle())
    }

    @MainActor
    private func seedForUITestingIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting"), args.contains("-uiTesting-seed-two-users") else { return }

        let seedKey = "ui_testing_seed_two_users_v1"
        guard UserDefaults.standard.bool(forKey: seedKey) == false else { return }
        UserDefaults.standard.set(true, forKey: seedKey)

        let itemA = ClothingItem(
            ownerUsername: "test0001",
            name: "A_上衣",
            category: "上衣",
            subCategory: "",
            color: "黑色",
            material: "",
            pattern: "",
            fit: "regular",
            formality: 0.5,
            seasons: ["春", "秋"],
            occasions: ["休闲"],
            styleTags: [],
            brand: "UITest",
            imageData: nil,
            remoteImageURL: "",
            syncStatusRaw: SyncStatus.synced.rawValue
        )
        let itemB = ClothingItem(
            ownerUsername: "test0002",
            name: "B_上衣",
            category: "上衣",
            subCategory: "",
            color: "白色",
            material: "",
            pattern: "",
            fit: "regular",
            formality: 0.5,
            seasons: ["春", "秋"],
            occasions: ["休闲"],
            styleTags: [],
            brand: "UITest",
            imageData: nil,
            remoteImageURL: "",
            syncStatusRaw: SyncStatus.synced.rawValue
        )
        modelContext.insert(itemA)
        modelContext.insert(itemB)

        let outfitA = OutfitRecord(
            ownerUsername: "test0001",
            title: "A_穿搭",
            itemNames: "A_上衣",
            itemIDs: [itemA.id],
            createdAt: Date(),
            updatedAt: Date(),
            isShared: false,
            imageData: nil,
            remoteImageURL: "",
            serverOutfitID: nil,
            syncStatusRaw: SyncStatus.synced.rawValue
        )
        let outfitB = OutfitRecord(
            ownerUsername: "test0002",
            title: "B_穿搭",
            itemNames: "B_上衣",
            itemIDs: [itemB.id],
            createdAt: Date(),
            updatedAt: Date(),
            isShared: false,
            imageData: nil,
            remoteImageURL: "",
            serverOutfitID: nil,
            syncStatusRaw: SyncStatus.synced.rawValue
        )
        modelContext.insert(outfitA)
        modelContext.insert(outfitB)

        // Persist immediately so UI tests can deterministically observe seeded records.
        try? modelContext.save()
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [ClothingItem.self, OutfitRecord.self, OutfitCalendarEntry.self], inMemory: true)
        .environmentObject(EnvironmentManager.shared)
}

enum Tab {
    case wardrobe
    case outfits
    case create
    case explore
    case profile
}
