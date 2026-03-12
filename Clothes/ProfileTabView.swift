// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ProfileTabView.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import PhotosUI
import StoreKit
import SwiftData
import SwiftUI
import UIKit

struct ProfileTabView: View {
    @AppStorage("auth_token") var authToken = ""
    @AppStorage("auth_username") var authUsername = ""
    @AppStorage("profile_name") var profileName = ""
    @AppStorage("profile_nickname") var profileNickname = ""
    @AppStorage("profile_uid") var profileUID = ""
    @AppStorage("profile_gender") var profileGender = ""
    @AppStorage("body_height") var bodyHeight = ""
    @AppStorage("body_weight") var bodyWeight = ""
    @AppStorage("body_size") var bodySize = ""
    @AppStorage("profile_zodiac") var profileZodiac = ""
    @AppStorage("profile_mbti") var profileMBTI = ""
    @AppStorage("preference_colors") var preferenceColors = ""
    @AppStorage("profile_avatar") var profileAvatar = Data()
    @AppStorage("profile_online_admin_modules_unlocked") var onlineAdminModulesUnlocked = false
    @ObservedObject private var envManager = EnvironmentManager.shared
    @State var avatarItem: PhotosPickerItem?
    @State var showAvatarPicker = false
    @State var walletSummary: WalletSummary?
    @State var showWalletRecords = false
    @State var walletRecords: [CoinTransaction] = []
    @State var showRechargeSheet = false
    @State var showCoinHelp = false
    @State var rechargeMessage: String?
    @State var showResetAlert = false
    @State var showClearCacheAlert = false
    @State var draftboxMessage: String?
    @State var activeEditSheet: ProfileEditSheet?
    @State var showSMSAuth = false
    @State var showSMSProfileCompletion = false
    @State var showRegistrationFlow = false
    @State var registrationPhone = ""
    @State var registrationSMSCode = ""
    @State var registrationVerified = false
    @State var smsRegistrationToken = ""
    @State var showAccountSwitcher = false
    @State var switcherAccounts: [StoredAccount] = []
    @State var registrationPassword = ""
    @State var registrationConfirmPassword = ""
    @State var authErrorMessage: String?
    @State var titleTapCount = 0
    @State var hiddenModulesUnlockedMessage: String?
    @AppStorage("account_sessions_json") var accountSessionsJSON = ""
    @Environment(\.modelContext) var modelContext
    @Query var clothingItems: [ClothingItem]
    @Query var outfitRecords: [OutfitRecord]
    @Query var calendarEntries: [OutfitCalendarEntry]
    let zodiacOptions = [
        "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座",
        "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"
    ]
    let mbtiOptions = [
        "不知道",
        "INTJ", "INTP", "ENTJ", "ENTP",
        "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ",
        "ISTP", "ISFP", "ESTP", "ESFP"
    ]
    let genderOptions = ["女", "男", "中性"]
    let sizeOptions = ["XS", "S", "M", "L", "XL", "XXL"]
    let colorOptions = ["白色系", "杏色系", "黄色系", "橙色系", "红色系", "粉色系", "紫色系", "蓝色系", "绿色系", "棕色系", "咖色系", "灰色系", "黑色系"]
    let heightOptions = Array(130...200).map { "\($0)" }
    let weightOptions = Array(35...120).map { "\($0)" }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("我的")
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(AppTheme.titleText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleMyAreaTap()
                            }
                            .accessibilityIdentifier("profile.my.area")

                        if authToken.isEmpty {
                            VStack(spacing: 14) {
                                SMSLoginInlineCard { response, account in
                                    Task { await handleSMSAuthSuccess(response: response, account: account) }
                                }
                            }
                        } else {
                            ProfileHero(
                                name: profileNickname.isEmpty ? (profileName.isEmpty ? "用户" : profileName) : profileNickname,
                                style: "",
                                avatarData: profileAvatar.isEmpty ? nil : profileAvatar,
                                onAvatarTap: { showAvatarPicker = true }
                            ) {
                                VStack(alignment: .trailing, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "creditcard")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.bodyText)
                                        Text("穿贝 \(walletSummary?.balance ?? 0)")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.bodyText)
                                            .accessibilityIdentifier("profile.balance.label")
                                        Button {
                                            showCoinHelp = true
                                        } label: {
                                            Image(systemName: "questionmark.circle")
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.mutedText)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Button("充值穿贝") {
                                        showRechargeSheet = true
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        AppTheme.primary,
                                                        Color(red: 0.42, green: 0.30, blue: 0.21)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                                    .foregroundStyle(Color.white)
                                    .accessibilityIdentifier("profile.recharge.button")
                                }
                            }
                            Button {
                                showWalletRecords = true
                            } label: {
                                Label("收支记录", systemImage: "list.bullet.rectangle")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.primary)
                                    )
                                    .foregroundStyle(Color.white)
                            }
                            .buttonStyle(.appPlain)
                            .accessibilityIdentifier("profile.wallet.records")

                            SettingsSection(title: "基本信息") {
                                SettingsActionRow(title: "昵称", value: profileNickname.isEmpty ? "未填写" : profileNickname, accessibilityId: "profile.row.nickname") {
                                    activeEditSheet = .nickname
                                }
                                SettingsStaticRow(title: "登录用户名", value: authUsername.isEmpty ? "未填写" : authUsername, accessibilityId: "profile.row.username")
                                SettingsActionRow(title: "性别", value: displayGender(profileGender), accessibilityId: "profile.row.gender") {
                                    activeEditSheet = .gender
                                }
                                SettingsActionRow(title: "身高", value: bodyHeight.isEmpty ? "未填写" : "\(bodyHeight) cm", accessibilityId: "profile.row.height") {
                                    activeEditSheet = .height
                                }
                                SettingsActionRow(title: "体重", value: bodyWeight.isEmpty ? "未填写" : "\(bodyWeight) kg", accessibilityId: "profile.row.weight") {
                                    activeEditSheet = .weight
                                }
                                SettingsActionRow(title: "常规尺码", value: bodySize.isEmpty ? "未填写" : bodySize, accessibilityId: "profile.row.size") {
                                    activeEditSheet = .size
                                }
                                SettingsActionRow(title: "星座", value: profileZodiac.isEmpty ? "未填写" : profileZodiac, accessibilityId: "profile.row.zodiac") {
                                    activeEditSheet = .zodiac
                                }
                                SettingsActionRow(title: "MBTI", value: profileMBTI.isEmpty ? "未填写" : profileMBTI, accessibilityId: "profile.row.mbti") {
                                    activeEditSheet = .mbti
                                }
                                SettingsActionRow(title: "色系", value: preferenceColors.isEmpty ? "未选择" : preferenceColors, accessibilityId: "profile.row.color") {
                                    activeEditSheet = .color
                                }
                            }

                            SettingsSection(title: "系统设置") {
                                Button {
                                    switchAccount()
                                } label: {
                                    HStack {
                                        Text("切换账号")
                                            .font(.subheadline)
                                        Spacer()
                                        Image(systemName: "person.2")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.white.opacity(0.9))
                                    )
                                }
                                .buttonStyle(.appPlain)
                                .accessibilityIdentifier("profile.switch.account")
                                Button(role: .destructive) {
                                    signOut()
                                } label: {
                                    HStack {
                                        Text("退出登录")
                                            .font(.subheadline)
                                        Spacer()
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.22))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.white.opacity(0.9))
                                    )
                                }
                                .buttonStyle(.appPlain)
                                .accessibilityIdentifier("profile.logout.button")
                            }

                            if shouldShowAdminModules {
                                SettingsSection(title: "环境设置") {
                                    EnvironmentSettingsRow()
                                        .environmentObject(EnvironmentManager.shared)
                                }

                                SettingsSection(title: "数据管理") {
                                    Button {
                                        showClearCacheAlert = true
                                    } label: {
                                        HStack {
                                            Text("清理本地缓存")
                                                .font(.subheadline)
                                            Spacer()
                                            Image(systemName: "arrow.clockwise.circle")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.9))
                                        )
                                    }
                                    .buttonStyle(.appPlain)
                                    Button(role: .destructive) {
                                        showResetAlert = true
                                    } label: {
                                        HStack {
                                            Text("清空所有数据")
                                                .font(.subheadline)
                                            Spacer()
                                            Image(systemName: "trash")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.22))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.9))
                                        )
                                    }
                                    .buttonStyle(.appPlain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
        .alert("清空数据", isPresented: $showResetAlert) {
            Button("清空", role: .destructive) { resetAllData() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除所有衣物、穿搭记录与日历数据，并清空登录与偏好设置，无法恢复。")
        }
        .alert("清理本地缓存", isPresented: $showClearCacheAlert) {
            Button("清理空白物品", role: .destructive) { clearBlankItems() }
            Button("清理无效账号", role: .destructive) { clearInvalidAccounts() }
            Button("全部清理", role: .destructive) {
                clearBlankItems()
                clearInvalidAccounts()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("可选择清理当前账号下的空白物品、清理已保存的无效账号列表，或全部清理。")
        }
        .sheet(isPresented: $showWalletRecords) {
            WalletRecordsView(records: walletRecords)
        }
        .sheet(isPresented: $showRechargeSheet) {
            WalletRechargeView(token: authToken, currentBalance: walletSummary?.balance ?? 0) { summary, package in
                walletSummary = summary
                rechargeMessage = "充值成功，已到账\(package.coins)穿贝。"
                Task { await refreshWallet() }
            }
        }
        .sheet(item: $activeEditSheet) { sheet in
            switch sheet {
            case .nickname:
                NavigationStack {
                    SettingsEditTextView(title: "昵称", text: $profileNickname, placeholder: "请输入昵称")
                }
            case .gender:
                SettingsEditWheelPickerView(title: "性别", options: genderOptions, selection: $profileGender)
            case .height:
                SettingsEditWheelPickerView(title: "身高（cm）", options: heightOptions, selection: $bodyHeight)
            case .weight:
                SettingsEditWheelPickerView(title: "体重（kg）", options: weightOptions, selection: $bodyWeight)
            case .size:
                SettingsEditWheelPickerView(title: "常规尺码", options: sizeOptions, selection: $bodySize)
            case .zodiac:
                SettingsEditWheelPickerView(title: "星座", options: zodiacOptions, selection: $profileZodiac)
            case .mbti:
                SettingsEditWheelPickerView(title: "MBTI", options: mbtiOptions, selection: $profileMBTI)
            case .color:
                SettingsEditWheelPickerView(title: "色系", options: colorOptions, selection: $preferenceColors)
            }
        }
        .onChange(of: activeEditSheet) { oldValue, newValue in
            // 用户关闭任一资料编辑弹层后，统一落库并同步到服务端，避免刷新后回滚。
            guard oldValue != nil, newValue == nil else { return }
            Task { await persistEditedProfileFromSettings() }
        }
        .onChange(of: showWalletRecords) { _, newValue in
            if newValue {
                Task { await refreshWallet() }
            }
        }
        .photosPicker(
            isPresented: $showAvatarPicker,
            selection: $avatarItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: avatarItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handleAvatarSelection(item: newItem)
            }
        }
        .task(id: authToken) {
            guard !authToken.isEmpty else { return }
            await refreshWallet()
        }
        .sheet(isPresented: $showSMSAuth) {
            SMSAuthSheet { response, account in
                Task { await handleSMSAuthSuccess(response: response, account: account) }
            }
        }
        .sheet(isPresented: $showAccountSwitcher) {
            AccountSwitcherSheet(
                accounts: switcherAccounts,
                currentUsername: authUsername,
                onSelect: { account in
                    applyAccount(account)
                    showAccountSwitcher = false
                },
                onDelete: { account in
                    removeAccount(account)
                    switcherAccounts = decodedStoredAccounts()
                },
                onAddLogin: {
                    showAccountSwitcher = false
                    showSMSAuth = true
                }
            )
        }
        .sheet(isPresented: $showSMSProfileCompletion) {
            SMSProfileCompletionSheet(
                gender: $profileGender,
                height: $bodyHeight,
                weight: $bodyWeight,
                size: $bodySize,
                zodiac: $profileZodiac,
                mbti: $profileMBTI,
                colorPreference: $preferenceColors
            ) {
                try await submitSMSProfileCompletion()
            }
        }
        .sheet(isPresented: $showRegistrationFlow) {
            RegistrationFlowView(
                phone: $registrationPhone,
                code: $registrationSMSCode,
                isVerified: $registrationVerified,
                nickname: $profileNickname,
                username: $authUsername,
                password: $registrationPassword,
                confirmPassword: $registrationConfirmPassword,
                gender: $profileGender,
                height: $bodyHeight,
                weight: $bodyWeight,
                size: $bodySize,
                zodiac: $profileZodiac,
                mbti: $profileMBTI,
                colorPreference: $preferenceColors
            ) { phone, code in
                try await verifySMSRegistration(phone: phone, code: code)
            } onComplete: {
                Task { await submitSMSRegistrationCompletion(username: authUsername, nickname: profileNickname) }
            }
        }
        .alert("操作失败", isPresented: Binding(get: { authErrorMessage != nil }, set: { _ in authErrorMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(authErrorMessage ?? "")
        }
        .alert("充值成功", isPresented: Binding(get: { rechargeMessage != nil }, set: { _ in rechargeMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(rechargeMessage ?? "")
        }
        .alert("关于穿贝", isPresented: $showCoinHelp) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(
                "穿贝用于消耗型功能，例如：虚拟试穿、AI 生成/推荐、图片整理美化等。\n\n固定汇率：10 穿贝 = 1 元。\n\n重要提示：穿贝属于虚拟商品，充值到账后不支持退款或提现；请确认账号与套餐后再充值。若遇到异常扣款/未到账，请联系管理员处理。"
            )
        }
        .alert("草稿箱", isPresented: Binding(get: { draftboxMessage != nil }, set: { _ in draftboxMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(draftboxMessage ?? "")
        }
        .alert("已解锁", isPresented: Binding(get: { hiddenModulesUnlockedMessage != nil }, set: { _ in hiddenModulesUnlockedMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(hiddenModulesUnlockedMessage ?? "")
        }
        .onChange(of: profileNickname) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileName = newValue
            }
        }
        .onAppear {
            // 强制同步 UserDefaults 中的 auth_token 到 @AppStorage
            // 确保在 UITest 模式下 -resetAuth 参数清除的登录状态能正确反映
            let actualToken = UserDefaults.standard.string(forKey: "auth_token") ?? ""
            if authToken != actualToken {
                authToken = actualToken
            }
        }
    }
}

private extension ProfileTabView {
    var shouldShowAdminModules: Bool {
        if envManager.currentEnvironment == .online {
            return onlineAdminModulesUnlocked
        }
        return true
    }

    func handleMyAreaTap() {
        guard envManager.currentEnvironment == .online else { return }
        guard !onlineAdminModulesUnlocked else { return }

        titleTapCount += 1
        if titleTapCount >= 8 {
            onlineAdminModulesUnlocked = true
            titleTapCount = 0
            hiddenModulesUnlockedMessage = "已开启“环境设置”和“数据管理”，请刷新页面后查看。"
        }
    }

    func displayGender(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        switch lowered {
        case "1", "男", "male", "m":
            return "男"
        case "2", "女", "female", "f":
            return "女"
        case "3", "中性", "neutral", "non-binary", "nonbinary":
            return "中性"
        case "0", "", "unknown", "未设置", "未填写":
            return "未填写"
        default:
            return trimmed
        }
    }
}
