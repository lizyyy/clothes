// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension ProfileTabView {
    func resetAllData() {
        clothingItems.forEach { modelContext.delete($0) }
        outfitRecords.forEach { modelContext.delete($0) }
        calendarEntries.forEach { modelContext.delete($0) }
        UsageTracker.reset()
        ImageCache.shared.cache.removeAllObjects()
        clearUserDefaults()
        clearProfileState()
    }

    /// 清理当前账号下名称或图片为空的物品
    func clearBlankItems() {
        let currentOwner = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemsToDelete = clothingItems.filter {
            $0.ownerUsername == currentOwner &&
            ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
             ($0.imageData == nil && $0.remoteImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        itemsToDelete.forEach { modelContext.delete($0) }
        draftboxMessage = "已清理 \(itemsToDelete.count) 个空白物品"
    }

    /// 清理已保存的无效账号列表（保留当前登录的账号）
    func clearInvalidAccounts() {
        let current = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        var accounts = decodedStoredAccounts()
        let originalCount = accounts.count
        let removedUsernames: [String]
        if !current.isEmpty {
            removedUsernames = accounts.filter { $0.username != current }.map(\.username)
            accounts.removeAll { $0.username != current }
        } else {
            removedUsernames = accounts.map(\.username)
            accounts.removeAll()
        }
        removedUsernames.forEach { removePersistedAccountAvatar(for: $0) }
        persistStoredAccounts(accounts)
        draftboxMessage = "已清理 \(originalCount - accounts.count) 个保存的账号"
    }

    func clearUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }

    func clearProfileState() {
        authToken = ""
        authUsername = ""
        registrationPhone = ""
        registrationSMSCode = ""
        registrationVerified = false
        smsRegistrationToken = ""
        profileNickname = ""
        profileUID = ""
        profileGender = ""
        bodyHeight = ""
        bodyWeight = ""
        bodySize = ""
        profileZodiac = ""
        profileMBTI = ""
        preferenceColors = ""
        profileAvatar = Data()
        registrationPassword = ""
        registrationConfirmPassword = ""
    }

    func handleSMSRegistration() {
        let code = registrationSMSCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = profileNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if let err = validateSMSRegistration(code: code, username: username, nickname: nickname) {
            authErrorMessage = err
            return
        }
        Task { await submitSMSRegistrationCompletion(username: username, nickname: nickname) }
    }

    func validateSMSRegistration(code: String, username: String, nickname: String) -> String? {
        if !registrationVerified || code.isEmpty {
            return "请先完成验证码验证。"
        }
        if username.isEmpty || nickname.isEmpty {
            return "请填写登录账号和昵称。"
        }
        if registrationPassword != registrationConfirmPassword {
            return "两次输入的密码不一致。"
        }
        if registrationPassword.count < 6 {
            return "密码长度至少6位。"
        }
        return nil
    }

    @MainActor
    func applySMSRegistrationVerification(_ response: AuthResponse, phone: String) {
        let defaultUsername = phone
        let defaultNickname = resolvedSMSRegistrationNickname(from: response.user)
        smsRegistrationToken = response.token
        authUsername = response.user?.username ?? defaultUsername
        profileName = response.user?.nickname ?? defaultNickname
        profileNickname = response.user?.nickname ?? defaultNickname
        profileUID = response.user?.uid.map(String.init) ?? profileUID
        registrationPhone = phone
        registrationVerified = true
        if authUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authUsername = defaultUsername
        }
        if profileNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileNickname = defaultNickname
            profileName = defaultNickname
        }
        profileAvatar = Data()
    }

    func verifySMSRegistration(phone: String, code: String) async throws {
        let response = try await UserAuthService().registerBySMS(phone: phone, code: code)
        await MainActor.run { applySMSRegistrationVerification(response, phone: phone) }
    }

    func submitSMSRegistrationCompletion(username: String, nickname: String) async {
        let token = smsRegistrationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            await MainActor.run { authErrorMessage = "注册状态异常，请重新获取验证码。" }
            return
        }
        do {
            if ProcessInfo.processInfo.arguments.contains("-uiTesting"),
               token == UserAuthService.uiTestingSMSPendingToken {
                let payload = UserProfilePayload(
                    nickname: nickname,
                    username: username,
                    password: registrationPassword,
                    gender: profileGender,
                    height: bodyHeight,
                    size: bodySize,
                    zodiac: profileZodiac,
                    mbti: profileMBTI,
                    colorPreference: preferenceColors,
                    weight: bodyWeight
                )
                let registerResp = try await UserAuthService().register(payload: payload)
                await MainActor.run { applySMSRegistrationVerification(registerResp, phone: registrationPhone) }
                let profile = try await UserAuthService().fetchProfile(token: registerResp.token)
                let avatarData = (try? await loadAvatarDataIfNeeded(from: profile.avatarURL)) ?? nil
                await MainActor.run {
                    authToken = registerResp.token
                    applyCompletedRegistrationProfile(profile, username: username, nickname: nickname)
                    profileAvatar = resolvedProfileAvatar(downloaded: avatarData, avatarURL: profile.avatarURL, fallback: profileAvatar)
                }
                await refreshWallet()
                await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
                await MainActor.run { upsertCurrentAccount() }
                return
            }

            _ = try await UserAuthService().completeSMSRegistration(
                token: token,
                username: username,
                nickname: nickname,
                password: registrationPassword
            )
            let syncedProfile = try await UserAuthService().updateProfile(
                token: token,
                nickname: nickname,
                genderText: profileGender,
                height: bodyHeight,
                weight: bodyWeight,
                size: bodySize,
                zodiac: profileZodiac,
                mbti: profileMBTI,
                colorPreference: preferenceColors
            )
            let avatarData = (try? await loadAvatarDataIfNeeded(from: syncedProfile.avatarURL)) ?? nil
            await MainActor.run {
                authToken = token
                applyCompletedRegistrationProfile(syncedProfile, username: username, nickname: nickname)
                profileAvatar = resolvedProfileAvatar(downloaded: avatarData, avatarURL: syncedProfile.avatarURL, fallback: profileAvatar)
            }
            await refreshWallet()
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
            await MainActor.run { upsertCurrentAccount() }
        } catch {
            await MainActor.run { authErrorMessage = error.localizedDescription }
        }
    }

    @MainActor
    func applyCompletedRegistrationProfile(_ profile: UserProfile, username: String, nickname: String) {
        authUsername = username
        profileName = profile.name.isEmpty ? nickname : profile.name
        profileNickname = profile.name.isEmpty ? nickname : profile.name
        profileUID = profile.uid
        profileGender = normalizeGender(profile.gender)
        bodyHeight = profile.height
        bodyWeight = profile.weight
        bodySize = profile.size
        profileZodiac = profile.zodiac
        profileMBTI = profile.mbti
        preferenceColors = profile.colorPreference
        // 新注册账号默认没有头像，先清空，后续若拉到头像会覆盖。
        profileAvatar = Data()
        registrationSMSCode = ""
        registrationPassword = ""
        registrationConfirmPassword = ""
        registrationVerified = false
        smsRegistrationToken = ""
    }

    func handleAppleSignIn() async {
        // 获取当前视图控制器用于展示苹果登录界面
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            authErrorMessage = "无法获取当前视图控制器"
            return
        }

        // 调用苹果登录
        AppleSignInManager.shared.signIn(presentingViewController: rootViewController) { result in
            Task {
                switch result {
                case .success(let appleResponse):
                    do {
                        let response = try await UserAuthService().appleSignIn(
                            appleID: appleResponse.appleID,
                            email: appleResponse.email,
                            fullName: appleResponse.fullName,
                            identityToken: appleResponse.identityToken
                        )

                        await MainActor.run {
                            authToken = response.token
                            authUsername = response.user?.username ?? ""
                            if let uid = response.user?.uid {
                                profileUID = String(uid)
                            }
                            profileName = appleResponse.fullName.isEmpty ? "Apple用户" : appleResponse.fullName
                            profileNickname = profileName
                            profileAvatar = Data()
                        }

                        // 获取用户资料
                        do {
                            let profile = try await UserAuthService().fetchProfile(token: response.token)
                            let avatarData = (try? await loadAvatarDataIfNeeded(from: profile.avatarURL)) ?? nil
                            await MainActor.run {
                                profileGender = normalizeGender(profile.gender)
                                bodyHeight = profile.height
                                bodyWeight = profile.weight
                                bodySize = profile.size
                                profileZodiac = profile.zodiac
                                profileMBTI = profile.mbti
                                preferenceColors = profile.colorPreference
                                profileAvatar = resolvedProfileAvatar(downloaded: avatarData, avatarURL: profile.avatarURL, fallback: profileAvatar)
                            }
                        } catch {
                            print("[Apple Sign In] Failed to fetch profile: \(error)")
                        }

                        await refreshWallet()
                        await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
                        await MainActor.run {
                            upsertCurrentAccount()
                        }
                    } catch {
                        await MainActor.run {
                            ErrorReporter.report(
                                message: "Apple Sign In API failed: \(error.localizedDescription)",
                                errorCode: ErrorReporter.ERROR_APPLE_SIGNIN_FAILED,
                                screen: "ProfileTabView",
                                context: ["error": "\(error)"]
                            )
                            authErrorMessage = "苹果登录失败: \(error.localizedDescription)"
                        }
                    }

                case .failure(let error):
                    await MainActor.run {
                        ErrorReporter.report(
                            message: "Apple Sign In failed: \(error.localizedDescription)",
                            errorCode: ErrorReporter.ERROR_APPLE_SIGNIN_FAILED,
                            screen: "ProfileTabView",
                            context: ["error": "\(error)"]
                        )
                        authErrorMessage = "苹果登录失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func signOut() {
        // Prevent legacy/unowned records from being "claimed" by the next user who logs in on this device.
        let current = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty {
            claimLegacyUnownedData(to: current)
        }
        authToken = ""
        authUsername = ""
        profileName = ""
        profileNickname = ""
        profileUID = ""
        profileGender = ""
        bodyHeight = ""
        bodyWeight = ""
        bodySize = ""
        profileZodiac = ""
        profileMBTI = ""
        preferenceColors = ""
        profileAvatar = Data()
        walletSummary = nil
        walletRecords = []
    }

    func switchAccount() {
        upsertCurrentAccount()
        switcherAccounts = decodedStoredAccounts()
        showAccountSwitcher = true
        Task { @MainActor in
            await refreshStoredAccountAvatarsIfNeeded()
            switcherAccounts = decodedStoredAccounts()
        }
    }

    @MainActor
    func handleSMSAuthSuccess(response: AuthResponse, account: String) async {
        authToken = response.token
        let resolvedUsername = response.user?.username ?? account
        authUsername = resolvedUsername
        let fallbackName = response.user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        profileName = (fallbackName?.isEmpty == false ? fallbackName ?? resolvedUsername : resolvedUsername)
        profileNickname = profileName
        profileUID = ""
        profileGender = ""
        bodyHeight = ""
        bodyWeight = ""
        bodySize = ""
        profileZodiac = ""
        profileMBTI = ""
        preferenceColors = ""
        let cachedAvatar = decodedStoredAccounts()
            .first(where: { $0.username == resolvedUsername })?
            .profileAvatar
        profileAvatar = cachedAvatar ?? Data()
        let shouldPromptProfileCompletion = (response.is_new_user == true)
        if let uid = response.user?.uid {
            profileUID = String(uid)
        }
        showSMSAuth = false
        do {
            let profile = try await UserAuthService().fetchProfile(token: response.token)
            applyProfile(profile)
            let avatarData = (try? await loadAvatarDataIfNeeded(from: profile.avatarURL)) ?? nil
            profileAvatar = resolvedProfileAvatar(downloaded: avatarData, avatarURL: profile.avatarURL, fallback: profileAvatar)
        } catch {
            authErrorMessage = error.localizedDescription
        }
        await refreshWallet()
        await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        upsertCurrentAccount()
        if shouldPromptProfileCompletion {
            showSMSProfileCompletion = true
        }
    }

    @MainActor
    func submitSMSProfileCompletion() async throws {
        let syncedProfile = try await UserAuthService().updateProfile(
            token: authToken,
            nickname: profileNickname.isEmpty ? (profileName.isEmpty ? authUsername : profileName) : profileNickname,
            genderText: profileGender,
            height: bodyHeight,
            weight: bodyWeight,
            size: bodySize,
            zodiac: profileZodiac,
            mbti: profileMBTI,
            colorPreference: preferenceColors
        )
        profileName = syncedProfile.name
        profileNickname = syncedProfile.name
        profileGender = normalizeGender(syncedProfile.gender)
        bodyHeight = syncedProfile.height
        bodyWeight = syncedProfile.weight
        bodySize = syncedProfile.size
        profileZodiac = syncedProfile.zodiac
        profileMBTI = syncedProfile.mbti
        preferenceColors = syncedProfile.colorPreference
        upsertCurrentAccount()
    }

    @MainActor
    func persistEditedProfileFromSettings() async {
        // 未登录状态下仅做本地持久化，避免无 token 请求。
        let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedToken.isEmpty {
            upsertCurrentAccount()
            return
        }

        let trimmedNickname = profileNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNickname.isEmpty {
            profileNickname = profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? authUsername : profileName
        } else {
            profileNickname = trimmedNickname
        }

        do {
            let syncedProfile = try await UserAuthService().updateProfile(
                token: trimmedToken,
                nickname: profileNickname,
                genderText: profileGender,
                height: bodyHeight,
                weight: bodyWeight,
                size: bodySize,
                zodiac: profileZodiac,
                mbti: profileMBTI,
                colorPreference: preferenceColors
            )
            profileName = syncedProfile.name
            profileNickname = syncedProfile.name
            profileGender = normalizeGender(syncedProfile.gender)
            bodyHeight = syncedProfile.height
            bodyWeight = syncedProfile.weight
            bodySize = syncedProfile.size
            profileZodiac = syncedProfile.zodiac
            profileMBTI = syncedProfile.mbti
            preferenceColors = syncedProfile.colorPreference
            upsertCurrentAccount()
        } catch {
            authErrorMessage = "资料保存失败：\(error.localizedDescription)"
            // 失败时仍保留本地改动，避免用户感知“输入丢失”。
            upsertCurrentAccount()
        }
    }

    func decodedStoredAccounts() -> [StoredAccount] {
        guard !accountSessionsJSON.isEmpty else {
            print("[AccountSwitch] No stored accounts data found")
            return []
        }
        guard let data = accountSessionsJSON.data(using: .utf8) else {
            print("[AccountSwitch] Failed to convert accountSessionsJSON to data")
            return []
        }
        do {
            let decoded = try JSONDecoder().decode([StoredAccount].self, from: data)
            let hydrated = decoded.map { hydrateStoredAccountAvatar($0) }
            print("[AccountSwitch] Successfully decoded \(hydrated.count) accounts")
            return hydrated
        } catch {
            print("[AccountSwitch] Failed to decode accounts: \(error)")
            print("[AccountSwitch] Raw JSON: \(accountSessionsJSON)")
            // 如果解码失败，清除无效数据
            accountSessionsJSON = ""
            return []
        }
    }

    func persistStoredAccounts(_ accounts: [StoredAccount]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // 使输出更稳定
        do {
            let data = try encoder.encode(accounts)
            guard let string = String(data: data, encoding: .utf8) else {
                print("[AccountSwitch] Failed to convert account data to string")
                return
            }
            accountSessionsJSON = string
            print("[AccountSwitch] Persisted \(accounts.count) accounts successfully")
        } catch {
            print("[AccountSwitch] Failed to encode accounts: \(error)")
        }
    }

    func upsertCurrentAccount() {
        let username = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AccountSwitch] upsertCurrentAccount called - username: \(username), token empty: \(token.isEmpty)")
        guard !username.isEmpty, !token.isEmpty else {
            print("[AccountSwitch] Skipping upsert - username or token is empty")
            return
        }

        var accounts = decodedStoredAccounts()
        print("[AccountSwitch] Current accounts count: \(accounts.count)")
        let normalizedAvatar = normalizedAvatarData(profileAvatar, maxDimension: 480, compression: 0.82)
        let switcherAvatar = normalizedAvatarData(normalizedAvatar, maxDimension: 144, compression: 0.78)
        persistAccountAvatar(normalizedAvatar, for: username)
        let current = StoredAccount(
            username: username,
            token: token,
            profileName: profileName,
            profileNickname: profileNickname,
            profileUID: profileUID,
            profileGender: profileGender,
            bodyHeight: bodyHeight,
            bodyWeight: bodyWeight,
            bodySize: bodySize,
            profileZodiac: profileZodiac,
            profileMBTI: profileMBTI,
            preferenceColors: preferenceColors,
            profileAvatar: switcherAvatar
        )
        if let idx = accounts.firstIndex(where: { $0.username == username }) {
            accounts[idx] = current
            print("[AccountSwitch] Updated existing account at index \(idx)")
        } else {
            accounts.insert(current, at: 0)
            print("[AccountSwitch] Inserted new account at index 0")
        }
        persistStoredAccounts(accounts)
    }

    func applyAccount(_ account: StoredAccount) {
        print("[AccountSwitch] Applying account - username: \(account.username)")
        // Before switching away, claim any legacy/unowned data to the current account so it won't "leak" into other accounts.
        let current = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty {
            claimLegacyUnownedData(to: current)
        }

        authToken = account.token
        authUsername = account.username
        profileName = account.profileName
        profileNickname = account.profileNickname
        profileUID = account.profileUID
        profileGender = normalizeGender(account.profileGender)
        bodyHeight = account.bodyHeight
        bodyWeight = account.bodyWeight
        bodySize = account.bodySize
        profileZodiac = account.profileZodiac
        profileMBTI = account.profileMBTI
        preferenceColors = account.preferenceColors
        profileAvatar = account.profileAvatar.isEmpty ? loadPersistedAccountAvatar(for: account.username) : account.profileAvatar
        print("[AccountSwitch] Account applied successfully - username: \(account.username), uid: \(account.profileUID)")
        let expectedUsername = account.username
        let expectedToken = account.token
        Task {
            await refreshWallet()
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
            do {
                let profile = try await UserAuthService().fetchProfile(token: expectedToken)
                let avatarData = try await loadAvatarDataIfNeeded(from: profile.avatarURL)
                await MainActor.run {
                    guard authUsername == expectedUsername, authToken == expectedToken else { return }
                    applyProfile(profile)
                    profileAvatar = resolvedProfileAvatar(downloaded: avatarData, avatarURL: profile.avatarURL, fallback: profileAvatar)
                    upsertCurrentAccount()
                }
            } catch {
                // Keep local cached account data if profile refresh fails.
            }
        }
    }

    @MainActor
    func refreshStoredAccountAvatarsIfNeeded() async {
        var accounts = decodedStoredAccounts()
        guard !accounts.isEmpty else { return }

        var changed = false
        for idx in accounts.indices {
            if !accounts[idx].profileAvatar.isEmpty {
                persistAccountAvatar(accounts[idx].profileAvatar, for: accounts[idx].username)
                continue
            }

            let token = accounts[idx].token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            do {
                let profile = try await UserAuthService().fetchProfile(token: token)
                guard let avatarData = try await loadAvatarDataIfNeeded(from: profile.avatarURL, tokenOverride: token),
                      !avatarData.isEmpty else { continue }

                let normalized = normalizedAvatarData(avatarData, maxDimension: 480, compression: 0.82)
                let switcherAvatar = normalizedAvatarData(normalized, maxDimension: 144, compression: 0.78)
                persistAccountAvatar(normalized, for: accounts[idx].username)

                let account = accounts[idx]
                accounts[idx] = StoredAccount(
                    username: account.username,
                    token: account.token,
                    profileName: account.profileName,
                    profileNickname: account.profileNickname,
                    profileUID: account.profileUID,
                    profileGender: account.profileGender,
                    bodyHeight: account.bodyHeight,
                    bodyWeight: account.bodyWeight,
                    bodySize: account.bodySize,
                    profileZodiac: account.profileZodiac,
                    profileMBTI: account.profileMBTI,
                    preferenceColors: account.preferenceColors,
                    profileAvatar: switcherAvatar
                )
                changed = true
            } catch {
                continue
            }
        }

        if changed {
            persistStoredAccounts(accounts)
        }
    }

    func claimLegacyUnownedData(to owner: String) {
        // Items created before we introduced ownerUsername were stored without partitioning.
        // Claim them for the current user at the moment we know who "owns" this device's legacy data.
        for item in clothingItems where item.ownerUsername.isEmpty {
            item.ownerUsername = owner
        }
        for outfit in outfitRecords where outfit.ownerUsername.isEmpty {
            outfit.ownerUsername = owner
        }
        for entry in calendarEntries where entry.ownerUsername.isEmpty {
            entry.ownerUsername = owner
        }
    }

    func removeAccount(_ account: StoredAccount) {
        var accounts = decodedStoredAccounts()
        accounts.removeAll { $0.username == account.username }
        persistStoredAccounts(accounts)
        removePersistedAccountAvatar(for: account.username)
        if authUsername == account.username {
            signOut()
        }
    }

    func refreshWallet() async {
        do {
            let wallet = try await WalletService().fetchWallet(token: authToken)
            await MainActor.run {
                walletSummary = wallet
            }
        } catch {
            await MainActor.run {
                walletSummary = nil
                walletRecords = []
            }
            return
        }

        do {
            let records = try await WalletService().fetchTransactions(token: authToken)
            await MainActor.run {
                walletRecords = records
            }
        } catch {
            await MainActor.run {
                walletRecords = []
            }
        }
    }

    func handleAvatarSelection(item: PhotosPickerItem) async {
        guard !authToken.isEmpty else { return }

        do {
            // Load image data from picker
            guard let rawImageData = try? await item.loadTransferable(type: Data.self) else {
                return
            }
            let imageData = normalizedAvatarData(rawImageData, maxDimension: 720, compression: 0.85)

            // Update local avatar immediately for UI responsiveness
            await MainActor.run {
                profileAvatar = imageData
                upsertCurrentAccount()
            }

            // Upload avatar to server
            let api = ClothesAPIService.shared
            api.setAuthToken(authToken)

            let uploaded = try await api.uploadFile(
                data: imageData,
                fileName: "avatar-\(authUsername)-\(UUID().uuidString).jpg",
                scope: "avatar"
            )

            // Get the public URL (fallback to url if public_url is empty)
            var avatarURL = uploaded.public_url?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            if avatarURL.isEmpty {
                avatarURL = uploaded.url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            guard !avatarURL.isEmpty else {
                ErrorReporter.report(
                    message: "Avatar upload returned empty URL",
                    errorCode: ErrorReporter.ERROR_AVATAR_UPLOAD_FAILED,
                    screen: "ProfileTabView",
                    context: ["username": authUsername]
                )
                return
            }

            // Update avatar URL on server
            try await UserAuthService().updateAvatar(token: authToken, avatarURL: avatarURL)
            await MainActor.run {
                upsertCurrentAccount()
            }

        } catch {
            ErrorReporter.report(
                message: "Avatar upload failed: \(error.localizedDescription)",
                errorCode: ErrorReporter.ERROR_AVATAR_UPLOAD_FAILED,
                screen: "ProfileTabView",
                context: ["username": authUsername, "error": "\(error)"]
            )
        }
    }

    @MainActor
    private func applyProfile(_ profile: UserProfile) {
        profileName = profile.name
        profileNickname = profile.name
        profileUID = profile.uid
        profileGender = normalizeGender(profile.gender)
        bodyHeight = profile.height
        bodyWeight = profile.weight
        bodySize = profile.size
        profileZodiac = profile.zodiac
        profileMBTI = profile.mbti
        preferenceColors = profile.colorPreference
    }

    @MainActor
    private func resolvedProfileAvatar(downloaded: Data?, avatarURL: String, fallback: Data) -> Data {
        if let downloaded, !downloaded.isEmpty {
            return normalizedAvatarData(downloaded, maxDimension: 480, compression: 0.82)
        }
        if avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Data()
        }
        guard !fallback.isEmpty else { return Data() }
        return normalizedAvatarData(fallback, maxDimension: 480, compression: 0.82)
    }

    private func hydrateStoredAccountAvatar(_ account: StoredAccount) -> StoredAccount {
        if !account.profileAvatar.isEmpty {
            persistAccountAvatar(account.profileAvatar, for: account.username)
        }
        let avatar = account.profileAvatar.isEmpty ? loadPersistedAccountAvatar(for: account.username) : account.profileAvatar
        return StoredAccount(
            username: account.username,
            token: account.token,
            profileName: account.profileName,
            profileNickname: account.profileNickname,
            profileUID: account.profileUID,
            profileGender: account.profileGender,
            bodyHeight: account.bodyHeight,
            bodyWeight: account.bodyWeight,
            bodySize: account.bodySize,
            profileZodiac: account.profileZodiac,
            profileMBTI: account.profileMBTI,
            preferenceColors: account.preferenceColors,
            profileAvatar: avatar
        )
    }

    private func accountAvatarDataKey(for username: String) -> String {
        "account_avatar_data_v1_\(username)"
    }

    private func persistAccountAvatar(_ data: Data, for username: String) {
        let key = accountAvatarDataKey(for: username)
        if data.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadPersistedAccountAvatar(for username: String) -> Data {
        let key = accountAvatarDataKey(for: username)
        return UserDefaults.standard.data(forKey: key) ?? Data()
    }

    private func removePersistedAccountAvatar(for username: String) {
        let key = accountAvatarDataKey(for: username)
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func normalizedAvatarData(_ data: Data, maxDimension: CGFloat, compression: CGFloat) -> Data {
        guard !data.isEmpty, let image = UIImage(data: data) else { return data }
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else {
            return image.jpegData(compressionQuality: compression) ?? data
        }
        let scale = maxDimension / longEdge
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: compression) ?? data
    }

    private func loadAvatarDataIfNeeded(from avatarURL: String, tokenOverride: String? = nil) async throws -> Data? {
        let trimmed = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let resolvedURL = SharedConstants.resolvedImageURL(from: trimmed) ?? URL(string: trimmed)
        guard let url = resolvedURL else { return nil }
        var request = URLRequest(url: url)
        let token = (tokenOverride ?? authToken).trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            return nil
        }
        return data
    }

    private func normalizeGender(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "1", "男", "male", "m":
            return "男"
        case "2", "女", "female", "f":
            return "女"
        case "3", "中性", "neutral", "non-binary", "nonbinary":
            return "中性"
        case "0", "", "unknown", "未设置":
            return ""
        default:
            return trimmed
        }
    }
}
