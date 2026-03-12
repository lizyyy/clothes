// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 登录页面封装
/// 提供登录页面的元素访问和操作封装
/// 支持链式调用，返回 self 或新页面实例
struct LoginPage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - Input Methods

    /// 输入用户名（先清除已有内容）
    /// - Parameter text: 用户名文本
    /// - Returns: LoginPage 实例（支持链式调用）
    @discardableResult
    func inputUsername(_ text: String) -> LoginPage {
        let usernameField = app.textFields["login.username.field"]
        if usernameField.waitForExistence(timeout: 3) {
            UITestSync.clearAndType(usernameField, text: text)
            return self
        }

        let inlinePhoneField = app.textFields["sms.inline.phone.field"]
        XCTAssertTrue(inlinePhoneField.waitForExistence(timeout: 8), "未找到用户名/手机号输入框")
        UITestSync.clearAndType(inlinePhoneField, text: text)
        return self
    }

    /// 输入密码（先清除已有内容）
    /// - Parameter text: 密码文本
    /// - Returns: LoginPage 实例（支持链式调用）
    @discardableResult
    func inputPassword(_ text: String) -> LoginPage {
        let passwordField = resolvePasswordField()
        if passwordField.exists {
            UITestSync.clearAndType(passwordField, text: text)
            return self
        }

        let inlineCodeField = app.textFields["sms.inline.code.field"]
        XCTAssertTrue(inlineCodeField.waitForExistence(timeout: 8), "未找到密码/验证码输入框")
        UITestSync.clearAndType(inlineCodeField, text: text)
        return self
    }

    /// 清除用户名输入框
    /// - Returns: LoginPage 实例（支持链式调用）
    @discardableResult
    func clearUsername() -> LoginPage {
        let usernameField = app.textFields["login.username.field"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "未找到用户名输入框")
        usernameField.tap()
        UITestSync.clearText(in: usernameField)
        return self
    }

    /// 清除密码输入框
    /// - Returns: LoginPage 实例（支持链式调用）
    @discardableResult
    func clearPassword() -> LoginPage {
        let passwordField = resolvePasswordField()
        XCTAssertTrue(passwordField.exists, "未找到密码输入框")
        passwordField.tap()
        UITestSync.clearText(in: passwordField)
        return self
    }

    // MARK: - Action Methods

    /// 点击提交按钮，完成登录
    /// - Returns: ProfilePage 实例（登录成功后）
    /// - Note: 登录成功后会自动处理"保存密码"提示
    func tapSubmit() -> ProfilePage {
        UITestSync.dismissKeyboardIfNeeded(app: app)

        let submitButton = app.buttons["login.submit.button"]
        if submitButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(submitButton.isEnabled, "登录按钮未启用（可能是表单未填写完整）")
            submitButton.tap()
        } else {
            let inlineSubmitButton = app.buttons["sms.inline.submit.button"]
            XCTAssertTrue(inlineSubmitButton.waitForExistence(timeout: 8), "未找到登录提交按钮")
            if !inlineSubmitButton.isEnabled {
                let agreeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
                if agreeButton.waitForExistence(timeout: 2), agreeButton.isHittable {
                    agreeButton.tap()
                }
            }
            XCTAssertTrue(inlineSubmitButton.isEnabled, "验证码登录按钮未启用（请检查手机号/验证码/协议）")
            inlineSubmitButton.tap()
        }

        dismissKnownAlertIfNeeded()
        UITestSync.declineSavePasswordPromptIfNeeded(app: app)

        if !waitForLoginSuccess(timeout: 12) {
            XCTFail("登录成功后应显示退出登录按钮。当前页面按钮: \(topVisibleButtonLabels(limit: 10))")
        }

        return ProfilePage(app: app)
    }

    /// 点击返回按钮，返回个人中心
    /// - Returns: ProfilePage 实例
    func tapBack() -> ProfilePage {
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "未找到返回按钮")
        backButton.tap()
        return ProfilePage(app: app)
    }

    @discardableResult
    func tapSMSLogin() -> LoginPage {
        let smsButton = app.buttons["login.sms.button"]
        if smsButton.waitForExistence(timeout: 4), smsButton.isHittable {
            smsButton.tap()
            return self
        }
        XCTAssertTrue(app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 8), "未找到短信登录入口")
        return self
    }

    @discardableResult
    func tapForgotPassword() -> LoginPage {
        let forgotButton = app.buttons["login.forgot.button"]
        if forgotButton.waitForExistence(timeout: 4), forgotButton.isHittable {
            forgotButton.tap()
            return self
        }
        if app.textFields["reset.phone.field"].waitForExistence(timeout: 4) {
            return self
        }
        XCTFail("未找到忘记密码入口")
        return self
    }

    // MARK: - State Methods

    /// 检查是否显示错误消息
    /// - Returns: true 如果显示错误提示（如"账号或密码错误"）
    func isErrorMessageDisplayed() -> Bool {
        if app.alerts.firstMatch.exists { return true }

        let errorPredicates = ["账号或密码错误", "用户不存在", "密码错误", "登录失败", "Error", "Failed", "请输入用户名和密码"]
        for errorText in errorPredicates {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", errorText)
            if app.staticTexts.matching(predicate).firstMatch.exists {
                return true
            }
        }

        return false
    }

    /// 获取错误消息文本
    /// - Returns: 错误消息文本，如果没有则返回空字符串
    func getErrorMessage() -> String {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            let message = alert.staticTexts.element(boundBy: 1)
            if message.exists { return message.label }
        }

        let errorPredicates = ["账号或密码错误", "用户不存在", "密码错误", "登录失败", "请输入用户名和密码"]
        for errorText in errorPredicates {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", errorText)
            let errorElement = app.staticTexts.matching(predicate).firstMatch
            if errorElement.waitForExistence(timeout: 1) {
                return errorElement.label
            }
        }

        return ""
    }

    /// 检查登录按钮是否启用
    /// - Returns: true 如果登录按钮可点击
    func isSubmitButtonEnabled() -> Bool {
        let submitButton = app.buttons["login.submit.button"]
        guard submitButton.waitForExistence(timeout: 5) else { return false }
        return submitButton.isEnabled
    }

    // MARK: - Private Helpers

    private func resolvePasswordField() -> XCUIElement {
        let secureField = app.secureTextFields["login.password.field"]
        if secureField.waitForExistence(timeout: 0.8) {
            return secureField
        }

        let textField = app.textFields["login.password.field"]
        _ = textField.waitForExistence(timeout: 2)
        return textField
    }

    private func dismissKnownAlertIfNeeded() {
        let okButton = app.buttons["知道了"]
        if okButton.waitForExistence(timeout: 1.5) {
            okButton.tap()
        }
    }

    private func waitForLoginSuccess(timeout: TimeInterval) -> Bool {
        let logoutButton = app.buttons["profile.logout.button"]
        return UITestSync.waitUntil(timeout: timeout) {
            if logoutButton.exists { return true }
            if isErrorMessageDisplayed() { return false }
            return false
        } && logoutButton.exists
    }

    private func topVisibleButtonLabels(limit: Int) -> [String] {
        app.buttons.allElementsBoundByIndex
            .prefix(limit)
            .compactMap { $0.label.isEmpty ? nil : $0.label }
    }
}
