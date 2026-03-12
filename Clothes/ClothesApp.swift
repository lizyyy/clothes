// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ClothesApp.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct ClothesApp: App {
    @StateObject private var envManager = EnvironmentManager.shared

    init() {
        configureForUITestingIfNeeded()

        // Make remote image access cacheable on disk to reduce repeated downloads from object storage.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "clothes-urlcache"
        )

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.background)
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AppTheme.primary).withAlphaComponent(0.4)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.primary).withAlphaComponent(0.4)]
        itemAppearance.selected.iconColor = UIColor(AppTheme.primary)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.primary)]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

    }
    var sharedModelContainer: ModelContainer = {
        let modelName = "ClothesV6"
        let schema = Schema([ 
            ClothingItem.self,
            OutfitRecord.self,
            OutfitCalendarEntry.self,
        ])
        // UI tests should not touch the on-disk store: it adds flakiness and can trigger watchdog kills
        // when repeatedly purging stores between test runs.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let modelConfiguration = ModelConfiguration(modelName, schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // One-time recovery: purge incompatible store and recreate.
            Self.purgeStores(modelName: modelName)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if envManager.hasSelectedEnvironment {
                    ContentView()
                        .tint(AppTheme.primary)
                        .environmentObject(envManager)
                } else {
                    EnvironmentPickerView()
                        .environmentObject(envManager)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private static func purgeStores(modelName: String) {
        let fm = FileManager.default
        var candidateDirectories: [URL] = []

        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
           let bundleID = Bundle.main.bundleIdentifier {
            candidateDirectories.append(appSupport.appendingPathComponent(bundleID, isDirectory: true))
        }

        if let appGroupSupport = fm
            .containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)?
            .appendingPathComponent("Library/Application Support", isDirectory: true) {
            candidateDirectories.append(appGroupSupport)
        }

        for directory in candidateDirectories {
            removeStoreFiles(named: "default.store", in: directory, using: fm)
            removeStoreFiles(named: "\(modelName).store", in: directory, using: fm)
        }
    }

    private static func removeStoreFiles(named fileName: String, in directory: URL, using fm: FileManager) {
        let storeURL = directory.appendingPathComponent(fileName)
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? fm.removeItem(at: storeURL.appendingPathExtension("wal"))
    }

    private func configureForUITestingIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting") else { return }

        // Default to a logged-out state so UI tests don't depend on prior simulator runs.
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "auth_username")

        if args.contains("-uiTesting-disable-animations") {
            UIView.setAnimationsEnabled(false)
        }

        if args.contains("-resetAuth") {
            // 彻底清除登录状态
            UserDefaults.standard.removeObject(forKey: "auth_token")
            UserDefaults.standard.removeObject(forKey: "auth_username")
            UserDefaults.standard.removeObject(forKey: "account_sessions_json")
            UserDefaults.standard.removeObject(forKey: "current_user_profile")
            // 清除App Group中的认证信息
            UserDefaults(suiteName: SharedConstants.appGroupID)?.removeObject(forKey: "auth_token")
            UserDefaults(suiteName: SharedConstants.appGroupID)?.removeObject(forKey: "auth_username")
            UserDefaults.standard.synchronize()
        }

        if args.contains("-uiTesting-clear-state"),
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults(suiteName: SharedConstants.appGroupID)?
                .removePersistentDomain(forName: SharedConstants.appGroupID)
            UserDefaults.standard.synchronize()
            UserDefaults(suiteName: SharedConstants.appGroupID)?.synchronize()
            // When UI testing we use an in-memory SwiftData store, so there is no disk state to purge.
        }

        if args.contains("-uiTesting-seed-two-users") {
            // Seed deterministic accounts for UI tests that validate account switching behavior.
            UserDefaults.standard.set("test0001", forKey: "auth_username")
            UserDefaults.standard.set("ui_test_token_A", forKey: "auth_token")
            // profileAvatar is Data type, encoded as Base64 string (empty Data = "")
            UserDefaults.standard.set(
                """
                [
                  {"username":"test0001","token":"ui_test_token_A","profileName":"A","profileNickname":"A","profileUID":"1","profileGender":"","bodyHeight":"","bodyWeight":"","bodySize":"","profileZodiac":"","profileMBTI":"","preferenceColors":"","profileAvatar":""},
                  {"username":"test0002","token":"ui_test_token_B","profileName":"B","profileNickname":"B","profileUID":"2","profileGender":"","bodyHeight":"","bodyWeight":"","bodySize":"","profileZodiac":"","profileMBTI":"","preferenceColors":"","profileAvatar":""}
                ]
                """,
                forKey: "account_sessions_json"
            )
        }
    }
}
