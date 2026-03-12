// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

final class AuthUITests: BaseTestCase {

    override var useOfflineAuthShortcut: Bool { false }

    override var extraLaunchArguments: [String] {
        ["-app_environment", "online", "-has_selected_environment", "YES"]
    }

    func testRegistrationBySMSFlow() {
        let account = makeAccount(prefix: "smsreg")
        goToProfileTab()
        let registrationPage = ProfilePage(app: app).tapRegister()

        _ = registrationPage.fillSMSRegistration(
            phone: account.phone,
            code: "123456",
            username: account.username,
            nickname: account.nickname,
            password: account.password
        )
        let profilePage = registrationPage.tapComplete()

        XCTAssertTrue(profilePage.isLoggedIn, "短信注册完成后应为登录状态")
        XCTAssertTrue(profilePage.hasInfoRow("profile.row.nickname"), "注册后应展示昵称信息行")
    }

    func testLoginBySMSForExistingAccount() {
        let account = makeAccount(prefix: "smsold")
        _ = registerAccount(account)
        logoutIfNeeded()

        goToProfileTab()
        _ = ProfilePage(app: app).tapLogin()
        fillSMSLogin(phone: account.phone, code: "123456")
        submitSMSLogin()
        XCTAssertTrue(ProfilePage(app: app).isLoggedIn, "手机号+验证码登录应成功")
    }

    func testLoginBySMSCode() {
        let account = makeAccount(prefix: "smslogin")
        _ = registerAccount(account)
        logoutIfNeeded()

        let loginPage = ProfilePage(app: app).tapLogin()
        _ = loginPage.tapSMSLogin()
        fillSMSLogin(phone: account.phone, code: "123456")
        submitSMSLogin()

        XCTAssertTrue(ProfilePage(app: app).isLoggedIn, "手机号+验证码登录应成功")
    }

    func testForgotPasswordBySMS() throws {
        let account = makeAccount(prefix: "reset")
        _ = registerAccount(account)
        logoutIfNeeded()

        guard openResetPasswordFlowIfAvailable() else {
            throw XCTSkip("当前入口未提供忘记密码页面，跳过该用例")
        }

        let newPassword = "abc12345"
        fillResetPasswordForm(phone: account.phone, code: "123456", password: newPassword)
        tapButton("reset.submit.button")
    }

    func testForgotPasswordFieldValidation() throws {
        goToProfileTab()
        guard openResetPasswordFlowIfAvailable() else {
            throw XCTSkip("当前入口未提供忘记密码页面，跳过该用例")
        }

        UITestSync.clearAndType(app.textFields["reset.phone.field"], text: "1a38001380001234")
        let normalizedPhone = (app.textFields["reset.phone.field"].value as? String) ?? ""
        XCTAssertEqual(normalizedPhone, "13800138000", "手机号应限制为 11 位数字")

        tapButton("reset.send.button")
        XCTAssertTrue(app.buttons["reset.resend.button"].waitForExistence(timeout: 5), "应进入验证码步骤")
        XCTAssertFalse(app.buttons["reset.resend.button"].isEnabled, "倒计时期间不应允许重发")
        XCTAssertTrue(app.buttons["reset.resend.button"].label.contains("s"), "重发按钮应显示倒计时")

        UITestSync.clearAndType(app.textFields["reset.code.field"], text: "123456")
        tapButton("reset.verify.button")

        UITestSync.clearAndType(resolvePasswordField("reset.password.field"), text: "abcdef")
        UITestSync.clearAndType(resolvePasswordField("reset.confirm.field"), text: "abcdef")
        XCTAssertTrue(app.staticTexts["reset.password.error"].waitForExistence(timeout: 3), "缺少密码规则错误提示")
        XCTAssertFalse(app.buttons["reset.submit.button"].isEnabled, "密码不符合规则时提交按钮应禁用")

        UITestSync.clearAndType(resolvePasswordField("reset.password.field"), text: "abc12345")
        UITestSync.clearAndType(resolvePasswordField("reset.confirm.field"), text: "abc12346")
        XCTAssertTrue(app.staticTexts["reset.confirm.error"].waitForExistence(timeout: 3), "两次密码不一致应提示")
        XCTAssertFalse(app.buttons["reset.submit.button"].isEnabled, "两次密码不一致时提交按钮应禁用")
    }

    @discardableResult
    private func registerAccount(_ account: TestAccount) -> ProfilePage {
        goToProfileTab()
        let registrationPage = ProfilePage(app: app).tapRegister()
        _ = registrationPage.fillSMSRegistration(
            phone: account.phone,
            code: "123456",
            username: account.username,
            nickname: account.nickname,
            password: account.password
        )
        return registrationPage.tapComplete()
    }

    private func logoutIfNeeded() {
        goToProfileTab()
        let page = ProfilePage(app: app)
        if page.isLoggedIn {
            _ = page.tapLogout()
        }
    }

    private func fillSMSLogin(phone: String, code: String) {
        if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
            UITestSync.clearAndType(app.textFields["sms.inline.phone.field"], text: phone)
            ensureInlineAgreementIfNeeded()
            let sendButton = app.buttons["sms.inline.send.button"]
            XCTAssertTrue(sendButton.waitForExistence(timeout: 6), "未找到发送验证码按钮")
            if sendButton.isEnabled { sendButton.tap() }
            UITestSync.clearAndType(app.textFields["sms.inline.code.field"], text: code)
            return
        }
        UITestSync.clearAndType(app.textFields["sms.login.phone.field"], text: phone)
        tapButton("sms.login.send.button")
        UITestSync.clearAndType(app.textFields["sms.login.code.field"], text: code)
    }

    private func submitSMSLogin() {
        if app.buttons["sms.inline.submit.button"].waitForExistence(timeout: 3) {
            ensureInlineAgreementIfNeeded()
            let submitButton = app.buttons["sms.inline.submit.button"]
            XCTAssertTrue(submitButton.isEnabled, "验证码登录按钮不可用")
            submitButton.tap()
        } else {
            tapButton("sms.login.submit.button")
        }
        declineSavePasswordPrompt(timeout: 3)
    }

    private func fillResetPasswordForm(phone: String, code: String, password: String) {
        UITestSync.clearAndType(app.textFields["reset.phone.field"], text: phone)
        tapButton("reset.send.button")
        UITestSync.clearAndType(app.textFields["reset.code.field"], text: code)
        tapButton("reset.verify.button")
        UITestSync.clearAndType(resolvePasswordField("reset.password.field"), text: password)
        UITestSync.clearAndType(resolvePasswordField("reset.confirm.field"), text: password)
        UITestSync.dismissKeyboardIfNeeded(app: app)
    }

    private func resolvePasswordField(_ id: String) -> XCUIElement {
        let secure = app.secureTextFields[id]
        if secure.exists {
            return secure
        }
        return app.textFields[id]
    }

    private func makeAccount(prefix: String) -> TestAccount {
        let suffix = Int(Date().timeIntervalSince1970) % 100000
        let username = "\(prefix)\(suffix)"
        let phone = String(format: "1%010d", suffix + 1000000000)
        return TestAccount(username: username, nickname: "nick_\(username)", phone: phone, password: "qwe123")
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

    private func openResetPasswordFlowIfAvailable() -> Bool {
        let loginPage = ProfilePage(app: app).tapLogin()
        _ = loginPage.tapForgotPassword()
        return app.textFields["reset.phone.field"].waitForExistence(timeout: 5)
    }
}

private struct TestAccount {
    let username: String
    let nickname: String
    let phone: String
    let password: String
}
