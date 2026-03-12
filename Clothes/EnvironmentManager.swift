// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  EnvironmentManager.swift
//  Clothes
//
//  环境管理器 - 负责 dev/online 环境切换与配置隔离
//

import Foundation
import SwiftUI
import Combine

/// 环境类型
enum EnvironmentType: String, CaseIterable, Identifiable {
    case dev = "dev"
    case online = "online"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dev: return "开发环境"
        case .online: return "线上环境"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .dev: return .orange
        case .online: return .green
        }
    }
}

/// 环境配置
struct EnvironmentConfig {
    let apiHost: String
    let apiPort: Int
    let fileHost: String
    let filePort: Int
    let fileBucket: String

    var apiBaseURL: String {
        "http://\(apiHost):\(apiPort)"
    }

    var fileBaseURL: String {
        "http://\(fileHost):\(filePort)"
    }
}

/// 环境管理器
@MainActor
final class EnvironmentManager: ObservableObject {
    static let shared = EnvironmentManager()

    private init() {
        if applyUITestLaunchEnvironmentOverrideIfNeeded() {
            return
        }

        // 从 UserDefaults 读取保存的环境设置
        let savedEnv = UserDefaults.standard.string(forKey: Self.environmentKey) ?? ""
        if let env = EnvironmentType(rawValue: savedEnv) {
            if env == .dev {
                self.currentEnvironment = .online
                UserDefaults.standard.set(EnvironmentType.online.rawValue, forKey: Self.environmentKey)
            } else {
                self.currentEnvironment = env
            }
        } else {
            // 首次启动，默认使用 online 环境，不需要用户选择
            self.currentEnvironment = .online
            UserDefaults.standard.set(EnvironmentType.online.rawValue, forKey: Self.environmentKey)
            UserDefaults.standard.set(true, forKey: Self.hasSelectedEnvironmentKey)
        }
    }

    private func applyUITestLaunchEnvironmentOverrideIfNeeded() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting") else { return false }
        guard let envRaw = valueAfterFlag("-app_environment", in: args),
              let env = EnvironmentType(rawValue: envRaw) else {
            return false
        }

        let hasSelectedRaw = valueAfterFlag("-has_selected_environment", in: args)?.uppercased()
        let hasSelected = hasSelectedRaw != "NO" && hasSelectedRaw != "FALSE" && hasSelectedRaw != "0"

        currentEnvironment = env
        UserDefaults.standard.set(env.rawValue, forKey: Self.environmentKey)
        UserDefaults.standard.set(hasSelected, forKey: Self.hasSelectedEnvironmentKey)
        return true
    }

    private func valueAfterFlag(_ flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag) else { return nil }
        let valueIndex = args.index(after: index)
        guard valueIndex < args.endIndex else { return nil }
        return args[valueIndex]
    }

    // MARK: - Keys

    private static let environmentKey = "app_environment"
    private static let hasSelectedEnvironmentKey = "has_selected_environment"

    // MARK: - Published

    @Published private(set) var currentEnvironment: EnvironmentType?

    // MARK: - 配置

    /// 开发环境配置
    static let devConfig = EnvironmentConfig(
        apiHost: "192.168.124.17",
        apiPort: 8082,
        fileHost: "192.168.124.17",
        filePort: 9000,
        fileBucket: "clothes"
    )

    /// 线上环境配置
    static let onlineConfig = EnvironmentConfig(
        apiHost: "115.190.190.40",
        apiPort: 8080,
        fileHost: "tos-s3-cn-beijing.volces.com",
        filePort: 443,
        fileBucket: "clothestest"
    )

    /// 当前环境的配置
    var currentConfig: EnvironmentConfig {
        switch currentEnvironment {
        case .dev, .none:
            return Self.devConfig
        case .online:
            return Self.onlineConfig
        }
    }

    /// API 基础 URL
    var apiBaseURL: String {
        currentConfig.apiBaseURL
    }

    /// 文件服务基础 URL
    var fileBaseURL: String {
        currentConfig.fileBaseURL
    }

    /// 文件存储 bucket
    var fileBucket: String {
        currentConfig.fileBucket
    }

    // MARK: - 方法

    /// 是否已选择环境
    var hasSelectedEnvironment: Bool {
        UserDefaults.standard.bool(forKey: Self.hasSelectedEnvironmentKey)
    }

    /// 切换环境
    func switchTo(_ environment: EnvironmentType) {
        currentEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: Self.environmentKey)
        UserDefaults.standard.set(true, forKey: Self.hasSelectedEnvironmentKey)
    }

    /// 重置环境选择（用于测试）
    func resetEnvironment() {
        currentEnvironment = nil
        UserDefaults.standard.removeObject(forKey: Self.environmentKey)
        UserDefaults.standard.removeObject(forKey: Self.hasSelectedEnvironmentKey)
    }

    /// 获取当前环境标识文本
    var environmentIndicator: String {
        guard let env = currentEnvironment else { return "未选择" }
        switch env {
        case .dev: return "DEV"
        case .online: return ""
        }
    }

    /// 是否显示环境标识（dev 环境显示）
    var shouldShowIndicator: Bool {
        currentEnvironment == .dev
    }
}

// MARK: - 环境选择引导视图

struct EnvironmentPickerView: View {
    @EnvironmentObject private var envManager: EnvironmentManager
    @State private var selectedEnv: EnvironmentType = .online
    @State private var showRestartAlert = false

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 图标
                Image(systemName: "gear.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.bottom, 16)

                // 标题
                Text("选择运行环境")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.titleText)

                Text("请选择要连接的服务器环境\n切换后需要重启应用生效")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.center)

                // 环境选择
                VStack(spacing: 16) {
                    EnvironmentOptionCard(
                        env: .dev,
                        isSelected: selectedEnv == .dev,
                        apiURL: EnvironmentManager.devConfig.apiBaseURL
                    ) {
                        selectedEnv = .dev
                    }

                    EnvironmentOptionCard(
                        env: .online,
                        isSelected: selectedEnv == .online,
                        apiURL: EnvironmentManager.onlineConfig.apiBaseURL
                    ) {
                        selectedEnv = .online
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // 确认按钮
                Button {
                    envManager.switchTo(selectedEnv)
                    showRestartAlert = true
                } label: {
                    Text("确认选择")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("环境已切换", isPresented: $showRestartAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("应用将在下次启动时使用 \(selectedEnv.displayName)")
        }
    }
}

// MARK: - 环境选项卡片

private struct EnvironmentOptionCard: View {
    let env: EnvironmentType
    let isSelected: Bool
    let apiURL: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 指示器
                Circle()
                    .fill(isSelected ? AppTheme.primary : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppTheme.primary : Color.gray.opacity(0.5), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(env.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.titleText)

                        // 环境标签
                        Text(env == .dev ? "调试" : "生产")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(env.indicatorColor.opacity(0.15))
                            .foregroundStyle(env.indicatorColor)
                            .clipShape(Capsule())
                    }

                    Text(apiURL)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.appPlain)
    }
}

// MARK: - 环境设置行（用于设置页面）

struct EnvironmentSettingsRow: View {
    @EnvironmentObject private var envManager: EnvironmentManager
    @State private var showEnvironmentPicker = false
    @State private var showRestartAlert = false

    var body: some View {
        Button {
            showEnvironmentPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务器环境")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))

                    Text(envManager.currentEnvironment?.displayName ?? "未选择")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                }

                Spacer()

                // 环境指示标签
                if let env = envManager.currentEnvironment {
                    Text(env == .dev ? "DEV" : "ONLINE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(env.indicatorColor.opacity(0.15))
                        .foregroundStyle(env.indicatorColor)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.9))
            )
        }
        .buttonStyle(.appPlain)
        .sheet(isPresented: $showEnvironmentPicker) {
            EnvironmentChangeSheet()
        }
        .alert("需要重启", isPresented: $showRestartAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("环境切换将在应用重启后生效")
        }
    }
}

// MARK: - 环境切换 Sheet

private struct EnvironmentChangeSheet: View {
    @EnvironmentObject private var envManager: EnvironmentManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEnv: EnvironmentType
    @State private var showConfirmAlert = false

    init() {
        _selectedEnv = State(initialValue: EnvironmentManager.shared.currentEnvironment ?? .online)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("切换服务器环境")
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)
                        .padding(.top, 8)

                    VStack(spacing: 16) {
                        EnvironmentOptionCard(
                            env: .dev,
                            isSelected: selectedEnv == .dev,
                            apiURL: EnvironmentManager.devConfig.apiBaseURL
                        ) {
                            selectedEnv = .dev
                        }

                        EnvironmentOptionCard(
                            env: .online,
                            isSelected: selectedEnv == .online,
                            apiURL: EnvironmentManager.onlineConfig.apiBaseURL
                        ) {
                            selectedEnv = .online
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("环境设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        if selectedEnv != envManager.currentEnvironment {
                            showConfirmAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .alert("确认切换环境?", isPresented: $showConfirmAlert) {
            Button("取消", role: .cancel) {}
            Button("确认") {
                envManager.switchTo(selectedEnv)
                dismiss()
            }
        } message: {
            Text("切换到 \(selectedEnv.displayName) 后，需要重启应用才能生效")
        }
    }
}

// MARK: - 环境指示器（用于主界面显示）

struct EnvironmentIndicator: View {
    @EnvironmentObject private var envManager: EnvironmentManager

    var body: some View {
        if envManager.shouldShowIndicator {
            Text("DEV")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Preview

#Preview {
    EnvironmentPickerView()
        .environmentObject(EnvironmentManager.shared)
}
