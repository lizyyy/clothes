// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

final class AuthValidationUITests: BaseTestCase {

    func testLoginShowsErrorWhenCredentialsMissing() {
        goToProfileTab()
        _ = ProfilePage(app: app).tapLogin()

        if app.buttons["login.submit.button"].waitForExistence(timeout: 3) {
            let submit = app.buttons["login.submit.button"]
            submit.tap()
            let alert = app.alerts["操作失败"]
            XCTAssertTrue(alert.waitForExistence(timeout: 8), "空登录未出现失败提示")
            XCTAssertTrue(alert.staticTexts["请输入用户名和密码。"].exists, "错误文案不符合预期")
            return
        }

        let submit = app.buttons["sms.inline.submit.button"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8), "未找到验证码登录提交按钮")
        XCTAssertFalse(submit.isEnabled, "手机号与验证码为空时按钮应禁用")
    }

    func testLoginSubmitButtonEnabledAfterCredentialsFilled() {
        goToProfileTab()
        _ = ProfilePage(app: app).tapLogin()

        if app.buttons["login.submit.button"].waitForExistence(timeout: 2) {
            let loginPage = LoginPage(app: app)
            _ = loginPage
                .inputUsername("test20")
                .inputPassword("qwe123!")
            XCTAssertTrue(loginPage.isSubmitButtonEnabled(), "填写账号密码后登录按钮应可用")
            return
        }

        let phoneField = app.textFields["sms.inline.phone.field"]
        let codeField = app.textFields["sms.inline.code.field"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 6), "未找到手机号输入框")
        XCTAssertTrue(codeField.waitForExistence(timeout: 6), "未找到验证码输入框")
        UITestSync.clearAndType(phoneField, text: "13800138000")
        UITestSync.clearAndType(codeField, text: "123456")
        ensureInlineAgreement()

        let submit = app.buttons["sms.inline.submit.button"]
        XCTAssertTrue(submit.waitForExistence(timeout: 6), "未找到验证码登录按钮")
        XCTAssertTrue(submit.isEnabled, "填写手机号+验证码并同意协议后按钮应可用")
    }

    func testRegistrationCanProceedAfterEditingPasswordFields() throws {
        goToProfileTab()
        let registrationPage = ProfilePage(app: app).tapRegister()
        guard registrationPage.entryMode == .registrationFlow else {
            throw XCTSkip("当前版本注册走 inline 短信自动注册，不再进入账号密码注册页")
        }

        fillAccountStepForValidation()

        let complete = app.buttons["register.complete.button"]
        XCTAssertTrue(complete.waitForExistence(timeout: 8), "未找到完成注册按钮")
        XCTAssertTrue(complete.isEnabled, "注册信息填写完整后完成注册按钮应可用")
    }

    private func fillAccountStepForValidation() {
        let phone = "1\(Int(Date().timeIntervalSince1970) % 10000000000)"
        let username = "ui\(Int(Date().timeIntervalSince1970))"
        UITestSync.clearAndType(app.textFields["register.phone.field"], text: phone)
        UITestSync.clearAndType(app.textFields["register.smsCode.field"], text: "123456")
        tapButton("register.verify.button")
        XCTAssertTrue(app.textFields["register.username.field"].waitForExistence(timeout: 10), "验证码校验后应出现账号输入框")
        UITestSync.clearAndType(app.textFields["register.username.field"], text: username)
        UITestSync.clearAndType(app.textFields["register.nickname.field"], text: "nick_\(username)")
        UITestSync.clearAndType(resolvePasswordField(id: "register.password.field"), text: "qwe123!")
        UITestSync.clearAndType(resolvePasswordField(id: "register.confirmPassword.field"), text: "qwe123!")
        UITestSync.dismissKeyboardIfNeeded(app: app)
    }

    private func resolvePasswordField(id: String) -> XCUIElement {
        let secureField = app.secureTextFields[id]
        if secureField.waitForExistence(timeout: 0.8) {
            return secureField
        }
        let textField = app.textFields[id]
        _ = textField.waitForExistence(timeout: 4)
        return textField
    }

    private func ensureInlineAgreement() {
        let submit = app.buttons["sms.inline.submit.button"]
        if submit.waitForExistence(timeout: 1), submit.isEnabled {
            return
        }
        let agreement = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        if agreement.waitForExistence(timeout: 2), agreement.isHittable {
            agreement.tap()
        }
    }
}
