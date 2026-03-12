// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

final class ProfileBusinessFlowUITests: BaseTestCase {

    override var useOfflineAuthShortcut: Bool { false }

    override var extraLaunchArguments: [String] {
        ["-app_environment", "online", "-has_selected_environment", "YES"]
    }

    private let defaultExistingUsername = "lzy"
    private let defaultExistingPassword = "qwe123"

    func testRegistrationGrantsThirtyCoinsAndShowsGiftRecord() {
        goToProfileTab()
        let account = makeRandomAccount(prefix: "reg30")
        _ = registerNewAccount(account)

        let profilePage = ProfilePage(app: app)
        let currentBalance = waitForBalance(atLeast: 30, timeout: 12, page: profilePage)
        XCTAssertEqual(currentBalance, 30, "新注册用户应赠送 30 穿贝")

        profilePage.tapWalletRecords()
        XCTAssertTrue(
            profilePage.firstWalletRecordMatches(reasonKeyword: "注册", amountText: "+30"),
            "收支记录首条应是注册赠送 +30"
        )
        profilePage.closePresentedViewIfNeeded()
    }

    func testStarterRechargeUpdatesBalanceAndLatestRecord() throws {
        goToProfileTab()
        let account = makeRandomAccount(prefix: "recharge")
        _ = registerNewAccount(account)

        let profilePage = ProfilePage(app: app)
        let balanceBefore = profilePage.getBalance()

        profilePage.tapRecharge()
        tapButton("wallet.package.starter")
        tapButton("wallet.recharge.confirm")
        if let failureMessage = dismissRechargeFailureAlertIfPresent(timeout: 8) {
            if isRechargeCapabilityUnavailable(message: failureMessage) {
                throw XCTSkip("当前环境暂不支持新手包充值：\(failureMessage)")
            }
            XCTFail("充值失败：\(failureMessage)")
            return
        }
        dismissRechargeSuccessAlertIfNeeded()

        XCTAssertTrue(app.buttons["profile.recharge.button"].waitForExistence(timeout: 8), "充值后应返回设置页")
        let balanceAfter = waitForBalance(atLeast: balanceBefore + 1, timeout: 15, page: profilePage)
        XCTAssertGreaterThan(balanceAfter, balanceBefore, "充值后余额应增加")

        profilePage.tapWalletRecords()
        XCTAssertTrue(
            profilePage.firstWalletRecordMatches(reasonKeyword: "新手包", amountText: nil),
            "收支记录首条应是新手包充值记录"
        )
        profilePage.closePresentedViewIfNeeded()
    }

    func testLogoutThenLoginExistingAccountAndProfileMatchesAPI() throws {
        let existing = try resolveExistingAccountForTest(prefix: "existing")
        goToProfileTab()
        let warmup = makeRandomAccount(prefix: "logout")
        _ = registerNewAccount(warmup)

        let profilePage = ProfilePage(app: app)
        _ = profilePage.tapLogout()
        try login(username: existing.username, password: existing.password, phone: existing.phone)

        let expected = try fetchBackendProfile(username: existing.username, password: existing.password)
        assertProfileRowsMatchBackend(expected)
    }

    func testAvatarUpdateReturnsAvatarInProfileAPI() throws {
        let existing = try resolveExistingAccountForTest(prefix: "avatarapi")
        try forceLoginAsAccount(username: existing.username, password: existing.password, phone: existing.phone)

        let avatarButton = app.buttons["profile.avatar.button"]
        XCTAssertTrue(avatarButton.waitForExistence(timeout: 10), "未找到头像按钮")
        avatarButton.tap()

        handleSystemAlert(buttonLabel: "允许访问所有照片", timeout: 2)
        handleSystemAlert(buttonLabel: "允许", timeout: 2)

        XCTAssertTrue(isPhotoPickerVisible(), "点击头像后应打开系统相册选择器")
        try pickRandomPhotoIfPossible()

        let avatarURL = try waitForAvatarURL(username: existing.username, password: existing.password, timeout: 30)
        XCTAssertFalse(avatarURL.isEmpty, "更新头像后，用户信息接口应返回 avatar_url")
    }

    func testAvatarPersistsAfterSwitchAccount() throws {
        let existing = try resolveExistingAccountForTest(prefix: "avatarpersist")
        try forceLoginAsAccount(username: existing.username, password: existing.password, phone: existing.phone)

        let avatarButton = app.buttons["profile.avatar.button"]
        XCTAssertTrue(avatarButton.waitForExistence(timeout: 10), "未找到头像按钮")
        avatarButton.tap()

        handleSystemAlert(buttonLabel: "允许访问所有照片", timeout: 2)
        handleSystemAlert(buttonLabel: "允许", timeout: 2)
        XCTAssertTrue(isPhotoPickerVisible(), "点击头像后应打开系统相册选择器")
        try pickRandomPhotoIfPossible()

        let expectedAvatarURL = try waitForAvatarURL(username: existing.username, password: existing.password, timeout: 30)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(expectedAvatarURL.isEmpty, "头像上传后应拿到非空 avatar_url")

        let secondAccount = makeRandomAccount(prefix: "avatar")
        _ = registerNewAccount(secondAccount)

        goToProfileTab()
        let profilePage = ProfilePage(app: app)
        profilePage.tapSwitchAccount()
        try switchAccountInSheet(to: existing.username)

        XCTAssertTrue(
            app.buttons["profile.logout.button"].waitForExistence(timeout: 10),
            "切回原账号后应保持登录态"
        )
        let usernameLabel = profilePage.getInfoRowLabel("profile.row.username")
        XCTAssertTrue(usernameLabel.contains(existing.username), "切换后当前账号应为 \(existing.username)")

        let switchedProfile = try fetchBackendProfile(username: existing.username, password: existing.password)
        let switchedAvatarURL = switchedProfile.avatarValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(switchedAvatarURL, expectedAvatarURL, "切换账号后头像应与服务端保存的最新头像一致")
        XCTAssertTrue(
            app.buttons["profile.avatar.button"].waitForExistence(timeout: 8),
            "切换账号后应展示头像入口"
        )
    }

    private func registerNewAccount(
        _ account: (username: String, nickname: String, phone: String, password: String),
        strict: Bool = true
    ) -> ProfilePage {
        let registrationPage = ProfilePage(app: app).tapRegister()
        _ = registrationPage.fillSMSRegistration(
            phone: account.phone,
            code: "123456",
            username: account.username,
            nickname: account.nickname,
            password: account.password
        )
        let profilePage = registrationPage.tapComplete()
        if let failureMessage = dismissFailureAlertIfPresent() {
            if strict {
                XCTFail("注册失败：\(failureMessage)")
            }
            return ProfilePage(app: app)
        }
        if !profilePage.isLoggedIn {
            do {
                try login(username: account.username, password: account.password, phone: account.phone)
            } catch {
                if strict {
                    XCTFail("注册后自动登录失败：\(error.localizedDescription)")
                }
            }
        }
        return ProfilePage(app: app)
    }

    private func forceLoginAsAccount(username: String, password: String, phone: String?) throws {
        goToProfileTab()
        let profilePage = ProfilePage(app: app)
        if profilePage.isLoggedIn {
            _ = profilePage.tapLogout()
        }
        try login(username: username, password: password, phone: phone)
    }

    private func login(username: String, password: String, phone: String? = nil) throws {
        goToProfileTab()
        let loginPage = ProfilePage(app: app).tapLogin()
        if app.textFields["login.username.field"].waitForExistence(timeout: 2) {
            _ = loginPage
                .inputUsername(username)
                .inputPassword(password)
            dismissKeyboard()
            tapButton("login.submit.button")
        } else if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 4) {
            let resolvedPhone = try resolveLoginPhone(username: username, password: password, explicitPhone: phone)
            performInlineSMSLogin(phone: resolvedPhone)
        } else {
            XCTFail("未找到可用登录入口（账号密码 / 短信验证码）")
            return
        }

        declineSavePasswordPrompt(timeout: 4)
        let outcome = waitForLoginOutcome(timeout: 12)
        if !outcome.loggedIn {
            if let failureMessage = outcome.failureMessage {
                XCTFail("登录失败：\(failureMessage)")
            } else {
                XCTFail("登录失败：未进入已登录状态，且未捕获到错误弹窗")
            }
            return
        }
    }

    private func resolveLoginPhone(username: String, password: String, explicitPhone: String?) throws -> String {
        if let explicitPhone, isValidPhone(explicitPhone) {
            return explicitPhone
        }
        if isValidPhone(username) {
            return username
        }
        let backendProfile = try fetchBackendProfile(username: username, password: password)
        let phoneCandidates = [backendProfile.phoneValue, backendProfile.username]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let matched = phoneCandidates.first(where: isValidPhone) {
            return matched
        }
        throw XCTSkip("短信登录需要手机号，但账号 \(username) 的 profile 接口未返回有效手机号")
    }

    private func performInlineSMSLogin(phone: String) {
        let phoneField = app.textFields["sms.inline.phone.field"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 8), "未找到短信登录手机号输入框")
        UITestSync.clearAndType(phoneField, text: phone)
        ensureInlineAgreementIfNeeded()

        let sendCodeButton = app.buttons["sms.inline.send.button"]
        XCTAssertTrue(sendCodeButton.waitForExistence(timeout: 6), "未找到发送验证码按钮")
        if sendCodeButton.isEnabled {
            sendCodeButton.tap()
        }

        let codeField = app.textFields["sms.inline.code.field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 8), "未找到验证码输入框")
        UITestSync.clearAndType(codeField, text: "123456")
        ensureInlineAgreementIfNeeded()

        let submitButton = app.buttons["sms.inline.submit.button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 8), "未找到验证码登录按钮")
        XCTAssertTrue(submitButton.isEnabled, "验证码登录按钮不可用")
        submitButton.tap()
    }

    private func ensureInlineAgreementIfNeeded() {
        let submitButton = app.buttons["sms.inline.submit.button"]
        if submitButton.waitForExistence(timeout: 1), submitButton.isEnabled {
            return
        }
        let agreementButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        if agreementButton.waitForExistence(timeout: 2), agreementButton.isHittable {
            agreementButton.tap()
        }
    }

    private func isValidPhone(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 11, trimmed.first == "1" else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }

    private func dismissRechargeSuccessAlertIfNeeded() {
        let successAlert = app.alerts["充值成功"]
        if successAlert.waitForExistence(timeout: 8) {
            let okButton = successAlert.buttons["知道了"]
            if okButton.exists { okButton.tap() }
        }
    }

    private func makeRandomAccount(prefix: String) -> (username: String, nickname: String, phone: String, password: String) {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var value = abs(Int(Date().timeIntervalSince1970 * 1000) ^ Int.random(in: 1...99_999))
        var code = ""
        for _ in 0..<3 {
            code.append(alphabet[value % alphabet.count])
            value /= alphabet.count
        }
        let username = "test\(code)"
        let phone = "18888888888"
        return (username, "nick_\(prefix)_\(code)", phone, "qwe123")
    }

    private func resolveExistingAccountForTest(prefix: String) throws -> (username: String, password: String, phone: String?) {
        if (try? fetchToken(username: defaultExistingUsername, password: defaultExistingPassword)) != nil {
            return (defaultExistingUsername, defaultExistingPassword, nil)
        }

        let fallback = makeRandomAccount(prefix: prefix)
        goToProfileTab()
        _ = registerNewAccount(fallback, strict: false)
        guard ProfilePage(app: app).isLoggedIn else {
            throw XCTSkip("无法准备可用账号：固定账号不可用且自动注册未进入登录态")
        }
        return (fallback.username, fallback.password, fallback.phone)
    }

    private func waitForLoginOutcome(timeout: TimeInterval) -> (loggedIn: Bool, failureMessage: String?) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["profile.logout.button"].exists {
                return (true, nil)
            }
            if let failureMessage = dismissFailureAlertIfPresent() {
                let loggedIn = app.buttons["profile.logout.button"].waitForExistence(timeout: 1.0)
                return (loggedIn, loggedIn ? nil : failureMessage)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let loggedIn = app.buttons["profile.logout.button"].exists
        return (loggedIn, nil)
    }

    private func switchAccountInSheet(to username: String) throws {
        XCTAssertTrue(
            app.navigationBars["切换账号"].waitForExistence(timeout: 8),
            "未进入切换账号弹窗"
        )

        let accountButton = app.buttons["account.switch.\(username)"]
        for _ in 0..<4 {
            if accountButton.exists {
                if accountButton.isHittable {
                    accountButton.tap()
                    return
                }
                app.swipeUp()
            } else {
                app.swipeDown()
            }
        }

        if app.staticTexts[username].waitForExistence(timeout: 3) {
            app.staticTexts[username].tap()
            return
        }

        throw NSError(
            domain: "UITest",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "切换账号列表中未找到用户 \(username)"]
        )
    }

    private func dismissFailureAlertIfPresent() -> String? {
        let titles = ["操作失败", "提示"]
        for title in titles {
            let alert = app.alerts[title]
            guard alert.waitForExistence(timeout: 0.8) else { continue }
            let texts = alert.staticTexts.allElementsBoundByIndex
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let message = texts.first { $0 != title } ?? texts.joined(separator: " | ")
            if alert.buttons["知道了"].exists {
                alert.buttons["知道了"].tap()
            } else {
                alert.buttons.firstMatch.tap()
            }
            return message.isEmpty ? title : "\(title): \(message)"
        }
        return nil
    }

    private func isPhotoPickerVisible() -> Bool {
        app.otherElements["PhotosPicker"].waitForExistence(timeout: 8)
            || app.navigationBars["照片"].waitForExistence(timeout: 8)
            || app.navigationBars["相簿"].waitForExistence(timeout: 8)
    }

    private func pickRandomPhotoIfPossible() throws {
        let cells = app.cells.allElementsBoundByIndex.filter(\.exists)
        if !cells.isEmpty {
            let pool = Array(cells.prefix(8))
            pool[Int.random(in: 0..<pool.count)].tap()
            return
        }

        let images = app.images.allElementsBoundByIndex.filter(\.exists)
        if !images.isEmpty {
            let pool = Array(images.prefix(8))
            pool[Int.random(in: 0..<pool.count)].tap()
            return
        }

        throw XCTSkip("当前模拟器没有可选照片，无法执行头像上传 UI 步骤")
    }

    private func waitForBalance(atLeast value: Int, timeout: TimeInterval, page: ProfilePage) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = page.getBalance()
        while Date() < deadline {
            if latest >= value { return latest }
            RunLoop.current.run(until: Date().addingTimeInterval(0.7))
            latest = page.getBalance()
        }
        return latest
    }

    private func dismissRechargeFailureAlertIfPresent(timeout: TimeInterval) -> String? {
        let alert = app.alerts["充值失败"]
        guard alert.waitForExistence(timeout: timeout) else { return nil }
        let message = alert.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty && $0 != "充值失败" }
            .joined(separator: " | ")
        if alert.buttons["知道了"].exists {
            alert.buttons["知道了"].tap()
        } else {
            alert.buttons.firstMatch.tap()
        }
        return message
    }

    private func isRechargeCapabilityUnavailable(message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("not implemented")
            || lowercased.contains("未实现")
            || lowercased.contains("暂不支持")
            || lowercased.contains("暂未开放")
    }

    private func waitForAvatarURL(username: String, password: String, timeout: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let profile = try fetchBackendProfile(username: username, password: password)
            let avatarURL = profile.avatarValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !avatarURL.isEmpty { return avatarURL }
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        }
        throw NSError(domain: "UITest", code: -1, userInfo: [NSLocalizedDescriptionKey: "超时：头像尚未写入用户信息接口"])
    }

    private func fetchBackendProfile(username: String, password: String) throws -> BackendProfile {
        let token = try fetchToken(username: username, password: password)
        let url = URL(string: "http://115.190.190.40:8080/api/v1/auth/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try send(request)
        let envelope = try JSONDecoder().decode(APIEnvelope<BackendProfile>.self, from: data)
        guard envelope.errno == 0 else {
            throw NSError(domain: "UITest", code: envelope.errno, userInfo: [NSLocalizedDescriptionKey: envelope.errmsg])
        }
        guard let profile = envelope.data else {
            throw NSError(domain: "UITest", code: -1, userInfo: [NSLocalizedDescriptionKey: "profile data 为空"])
        }
        return profile
    }

    private func fetchToken(username: String, password: String) throws -> String {
        let url = URL(string: "http://115.190.190.40:8080/api/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])

        let data = try send(request)
        let envelope = try JSONDecoder().decode(APIEnvelope<LoginPayload>.self, from: data)
        guard envelope.errno == 0 else {
            throw NSError(domain: "UITest", code: envelope.errno, userInfo: [NSLocalizedDescriptionKey: envelope.errmsg])
        }
        guard let token = envelope.data?.token else {
            throw NSError(domain: "UITest", code: -1, userInfo: [NSLocalizedDescriptionKey: "token 为空"])
        }
        return token
    }

    private func send(_ request: URLRequest, timeout: TimeInterval = 20) throws -> Data {
        let done = expectation(description: "network")
        var resultData: Data?
        var resultError: Error?

        URLSession.shared.dataTask(with: request) { data, _, error in
            resultData = data
            resultError = error
            done.fulfill()
        }.resume()

        wait(for: [done], timeout: timeout)
        if let resultError { throw resultError }
        guard let resultData else {
            throw NSError(domain: "UITest", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络返回为空"])
        }
        return resultData
    }

    private func assertProfileRowsMatchBackend(_ backend: BackendProfile) {
        goToProfileTab()
        let profilePage = ProfilePage(app: app)

        assertRowContains(profilePage, rowID: "profile.row.username", expected: normalized(backend.username, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.nickname", expected: normalized(backend.nicknameValue, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.gender", expected: genderText(value: backend.gender, raw: backend.genderRaw))
        assertRowContains(profilePage, rowID: "profile.row.height", expected: normalized(backend.height, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.weight", expected: normalized(backend.weight, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.size", expected: normalized(backend.size, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.zodiac", expected: normalized(backend.zodiac, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.mbti", expected: normalized(backend.mbti, emptyText: "未填写"))
        assertRowContains(profilePage, rowID: "profile.row.color", expected: normalized(backend.colorValue, emptyText: "未选择"))
    }

    private func assertRowContains(_ page: ProfilePage, rowID: String, expected: String) {
        let label = page.getInfoRowLabel(rowID)
        XCTAssertTrue(label.contains(expected), "\(rowID) 应包含「\(expected)」，实际：\(label)")
    }

    private func normalized(_ raw: String?, emptyText: String) -> String {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? emptyText : text
    }

    private func genderText(value: Int?, raw: String?) -> String {
        let rawText = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mapped = [0: "未填写", 1: "男", 2: "女", 3: "中性"][value ?? 0] ?? "未填写"
        return rawText.isEmpty ? mapped : rawText
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let errno: Int
    let errmsg: String
    let data: T?
}

private struct LoginPayload: Decodable {
    let token: String
}

private struct BackendProfile: Decodable {
    let username: String?
    let nickname: String?
    let name: String?
    let phone: String?
    let mobile: String?
    let mobilePhone: String?
    let phoneNumber: String?
    let gender: Int?
    let genderRaw: String?
    let height: String?
    let weight: String?
    let size: String?
    let zodiac: String?
    let mbti: String?
    let colorPreference: String?
    let colorPreferenceLegacy: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case username
        case nickname
        case name
        case phone
        case mobile
        case mobilePhone = "mobile_phone"
        case phoneNumber = "phone_number"
        case gender
        case height
        case weight
        case size
        case zodiac
        case mbti
        case colorPreference = "color_preference"
        case colorPreferenceLegacy = "colorPreference"
        case avatarURL = "avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try? container.decode(String.self, forKey: .username)
        nickname = try? container.decode(String.self, forKey: .nickname)
        name = try? container.decode(String.self, forKey: .name)
        phone = try? container.decode(String.self, forKey: .phone)
        mobile = try? container.decode(String.self, forKey: .mobile)
        mobilePhone = try? container.decode(String.self, forKey: .mobilePhone)
        phoneNumber = try? container.decode(String.self, forKey: .phoneNumber)
        gender = try? container.decode(Int.self, forKey: .gender)
        genderRaw = try? container.decode(String.self, forKey: .gender)
        height = try? container.decode(String.self, forKey: .height)
        weight = try? container.decode(String.self, forKey: .weight)
        size = try? container.decode(String.self, forKey: .size)
        zodiac = try? container.decode(String.self, forKey: .zodiac)
        mbti = try? container.decode(String.self, forKey: .mbti)
        colorPreference = try? container.decode(String.self, forKey: .colorPreference)
        colorPreferenceLegacy = try? container.decode(String.self, forKey: .colorPreferenceLegacy)
        avatarURL = try? container.decode(String.self, forKey: .avatarURL)
    }

    var nicknameValue: String? { nickname ?? name }

    var colorValue: String? { colorPreference ?? colorPreferenceLegacy }

    var phoneValue: String? { phone ?? mobile ?? mobilePhone ?? phoneNumber }

    var avatarValue: String { avatarURL ?? "" }
}
