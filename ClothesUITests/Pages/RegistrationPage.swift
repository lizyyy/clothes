// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

struct RegistrationPage {
    enum EntryMode {
        case registrationFlow
        case inlineSMS
    }

    let app: XCUIApplication
    private(set) var currentStep: Int
    private(set) var entryMode: EntryMode = .registrationFlow

    @discardableResult
    func fillSMSRegistration(phone: String, code: String, username: String, nickname: String, password: String) -> RegistrationPage {
        let verified = verifyBySMS(phone: phone, code: code)
        if verified.entryMode == .inlineSMS {
            return verified
        }
        return verified.fillAccountFields(username: username, nickname: nickname, password: password)
    }

    @discardableResult
    func verifyBySMS(phone: String, code: String) -> RegistrationPage {
        if entryMode == .inlineSMS {
            let phoneField = app.textFields["sms.inline.phone.field"]
            XCTAssertTrue(phoneField.waitForExistence(timeout: 10), "未找到短信登录手机号输入框")
            UITestSync.clearAndType(phoneField, text: phone)

            ensureInlineAgreementIfNeeded()

            let sendCodeButton = app.buttons["sms.inline.send.button"]
            XCTAssertTrue(sendCodeButton.waitForExistence(timeout: 6), "未找到发送验证码按钮")
            if sendCodeButton.isEnabled {
                sendCodeButton.tap()
            }

            let codeField = app.textFields["sms.inline.code.field"]
            XCTAssertTrue(codeField.waitForExistence(timeout: 10), "未找到短信登录验证码输入框")
            UITestSync.clearAndType(codeField, text: code)

            return RegistrationPage(app: app, currentStep: 1, entryMode: .inlineSMS)
        }

        let phoneField = app.textFields["register.phone.field"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10), "未找到手机号输入框")
        UITestSync.clearAndType(phoneField, text: phone)

        let sendCodeButton = app.buttons["register.sms.send.button"]
        if sendCodeButton.waitForExistence(timeout: 3), sendCodeButton.isHittable {
            sendCodeButton.tap()
        }

        let codeField = app.textFields["register.smsCode.field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "未找到验证码输入框")
        UITestSync.clearAndType(codeField, text: code)

        let verifyButton = app.buttons["register.verify.button"]
        XCTAssertTrue(verifyButton.waitForExistence(timeout: 10), "未找到验证码校验按钮")
        verifyButton.tap()
        return RegistrationPage(app: app, currentStep: 1, entryMode: .registrationFlow)
    }

    @discardableResult
    func fillAccountInfo(username: String, nickname: String, password: String) -> RegistrationPage {
        fillSMSRegistration(
            phone: makeRandomPhone(),
            code: "123456",
            username: username,
            nickname: nickname,
            password: password
        )
    }

    @discardableResult
    func fillAccountFields(username: String, nickname: String, password: String) -> RegistrationPage {
        if entryMode == .inlineSMS {
            _ = username
            _ = nickname
            _ = password
            return RegistrationPage(app: app, currentStep: currentStep, entryMode: .inlineSMS)
        }

        let usernameField = app.textFields["register.username.field"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 12), "未找到用户名输入框")
        UITestSync.clearAndType(usernameField, text: username)

        let nicknameField = app.textFields["register.nickname.field"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 10), "未找到昵称输入框")
        UITestSync.clearAndType(nicknameField, text: nickname)

        let passwordField = resolveInputField(primary: app.secureTextFields["register.password.field"], fallback: app.textFields["register.password.field"])
        let confirmField = resolveInputField(primary: app.secureTextFields["register.confirmPassword.field"], fallback: app.textFields["register.confirmPassword.field"])
        XCTAssertTrue(passwordField.exists && confirmField.exists, "未找到密码输入框")
        UITestSync.clearAndType(passwordField, text: password)
        UITestSync.clearAndType(confirmField, text: password)
        UITestSync.dismissKeyboardIfNeeded(app: app)

        return RegistrationPage(app: app, currentStep: 1, entryMode: .registrationFlow)
    }

    @discardableResult
    func selectGender(_ gender: String) -> RegistrationPage {
        _ = gender
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectHeight(_ height: String) -> RegistrationPage {
        _ = height
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectSize(_ size: String) -> RegistrationPage {
        _ = size
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectZodiac(_ zodiac: String) -> RegistrationPage {
        _ = zodiac
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectMBTI(_ mbti: String) -> RegistrationPage {
        _ = mbti
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectColor(_ color: String) -> RegistrationPage {
        _ = color
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func selectWeight(_ weight: String) -> RegistrationPage {
        _ = weight
        return RegistrationPage(app: app, currentStep: currentStep, entryMode: entryMode)
    }

    @discardableResult
    func tapNext() -> RegistrationPage {
        let nextButton = app.buttons["register.next.button"]
        if nextButton.waitForExistence(timeout: 1), nextButton.isHittable {
            nextButton.tap()
        }
        return RegistrationPage(app: app, currentStep: currentStep + 1, entryMode: entryMode)
    }

    func tapComplete() -> ProfilePage {
        if entryMode == .inlineSMS {
            UITestSync.dismissKeyboardIfNeeded(app: app)

            let submitButton = app.buttons["sms.inline.submit.button"]
            XCTAssertTrue(submitButton.waitForExistence(timeout: 10), "未找到验证码登录按钮")
            if !submitButton.isEnabled {
                tryEnableInlineSubmitButton(submitButton: submitButton)
            }
            XCTAssertTrue(submitButton.isEnabled, "验证码登录按钮未启用")
            submitButton.tap()

            declineSavePasswordPromptIfNeeded()
            dismissProfileCompletionIfNeeded()
            XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 15), "短信注册后未进入登录态")
            return ProfilePage(app: app)
        }

        UITestSync.dismissKeyboardIfNeeded(app: app)

        let completeButton = app.buttons["register.complete.button"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 10), "未找到完成注册按钮")
        XCTAssertTrue(completeButton.isEnabled, "完成注册按钮未启用")
        completeButton.tap()

        declineSavePasswordPromptIfNeeded()
        _ = app.buttons["profile.logout.button"].waitForExistence(timeout: 12)
        return ProfilePage(app: app)
    }

    func tapBack() -> Any {
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "未找到返回按钮")
        backButton.tap()
        if app.buttons["profile.register.button"].waitForExistence(timeout: 3)
            || app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 2) {
            return ProfilePage(app: app)
        }
        return RegistrationPage(app: app, currentStep: max(1, currentStep - 1), entryMode: entryMode)
    }

    func isNextButtonEnabled() -> Bool {
        let completeButton = app.buttons["register.complete.button"]
        if completeButton.waitForExistence(timeout: 2) {
            return completeButton.isEnabled
        }
        let nextButton = app.buttons["register.next.button"]
        return nextButton.waitForExistence(timeout: 2) && nextButton.isEnabled
    }

    func getCurrentStepTitle() -> String {
        let registerTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "手机号短信注册")).firstMatch
        if registerTitle.waitForExistence(timeout: 2) {
            return registerTitle.label
        }
        return ""
    }

    private func resolveInputField(primary: XCUIElement, fallback: XCUIElement) -> XCUIElement {
        if primary.waitForExistence(timeout: 0.8) {
            return primary
        }
        _ = fallback.waitForExistence(timeout: 3)
        return fallback
    }

    private func declineSavePasswordPromptIfNeeded(timeout: TimeInterval = 2.5) {
        UITestSync.declineSavePasswordPromptIfNeeded(app: app, timeout: timeout)
    }

    private func dismissProfileCompletionIfNeeded() {
        let completionTitle = app.navigationBars["完善资料"]
        if completionTitle.waitForExistence(timeout: 4) {
            let skipButton = app.buttons["稍后完善"]
            if skipButton.waitForExistence(timeout: 3), skipButton.isHittable {
                skipButton.tap()
            }
        }
    }

    private func ensureInlineAgreementIfNeeded() {
        let agreeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        let sendCodeButton = app.buttons["sms.inline.send.button"]
        if sendCodeButton.waitForExistence(timeout: 1), sendCodeButton.isEnabled {
            return
        }
        if agreeButton.waitForExistence(timeout: 2), agreeButton.isHittable {
            agreeButton.tap()
        }
    }

    private func tryEnableInlineSubmitButton(submitButton: XCUIElement) {
        let agreeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        guard agreeButton.waitForExistence(timeout: 2), agreeButton.isHittable else { return }

        for _ in 0..<2 {
            if submitButton.isEnabled { return }
            agreeButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
    }

    private func makeRandomPhone() -> String {
        return "18888888888"
    }
}
