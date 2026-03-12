// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试备份层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

final class ClothesUIFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchCleanApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTesting",
            "-uiTesting-disable-animations"
        ]
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }

    private func inputField(_ app: XCUIApplication, label: String, timeout: TimeInterval = 8) -> XCUIElement {
        // iOS/Springboard sometimes exposes SecureField as a normal TextField in accessibility snapshots.
        // Try secure first, then fall back to a regular text field.
        let secure = app.secureTextFields[label]
        if secure.waitForExistence(timeout: 0.8) {
            return secure
        }
        let text = app.textFields[label]
        _ = text.waitForExistence(timeout: timeout)
        return text
    }

    func testLoginFormShowsValidationErrorWhenEmpty() throws {
        let app = launchCleanApp()
        openSettings(app)

        app.buttons["已有账号登录"].tap()
        XCTAssertTrue(app.navigationBars["登录账号"].waitForExistence(timeout: 8), "未进入登录页")

        app.buttons["登录"].tap()

        let alert = app.alerts["操作失败"]
        XCTAssertTrue(alert.waitForExistence(timeout: 8), "空表单登录后未出现错误提示")
        XCTAssertTrue(alert.staticTexts["请输入用户名和密码。"].exists, "错误文案不符合预期")
    }

    func testRegistrationFlowCanMoveForwardAndBackward() throws {
        let app = launchCleanApp()
        openSettings(app)

        app.buttons["注册"].tap()
        XCTAssertTrue(app.navigationBars["注册"].waitForExistence(timeout: 8), "未进入注册流程")
        XCTAssertTrue(app.staticTexts["请填写账号信息"].waitForExistence(timeout: 8), "注册首屏文案缺失")

        let username = makeUniqueTestUsername(offset: 1)
        fillRegistrationAccountStep(app: app, username: username, nickname: username, password: "qwe123!")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的性别是？"].waitForExistence(timeout: 8), "未进入性别步骤")
        tapOptionByCenter(app, label: "女")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的身高是？"].waitForExistence(timeout: 8), "未进入身高步骤")

        let backButton = app.navigationBars["注册"].buttons.firstMatch
        XCTAssertTrue(backButton.exists, "缺少返回按钮")
        backButton.tap()

        XCTAssertTrue(app.staticTexts["您的性别是？"].waitForExistence(timeout: 8), "返回后未回到性别步骤")
    }

    func testRegistrationCanReachFinalWeightStepWithoutSubmitting() throws {
        let app = launchCleanApp()
        openSettings(app)

        app.buttons["注册"].tap()
        XCTAssertTrue(app.navigationBars["注册"].waitForExistence(timeout: 8), "未进入注册流程")

        let username = makeUniqueTestUsername(offset: 2)
        fillRegistrationAccountStep(app: app, username: username, nickname: username, password: "qwe123!")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的性别是？"].waitForExistence(timeout: 8), "未进入性别步骤")
        tapOptionByCenter(app, label: "男")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的身高是？"].waitForExistence(timeout: 8), "未进入身高步骤")
        setPickerWheel(app, value: "165")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您通常购买什么尺码？"].waitForExistence(timeout: 8), "未进入尺码步骤")
        tapOptionByCenter(app, label: "M")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的星座是？"].waitForExistence(timeout: 8), "未进入星座步骤")
        setPickerWheel(app, value: "白羊座")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的 MBTI 是？"].waitForExistence(timeout: 8), "未进入 MBTI 步骤")
        setPickerWheel(app, value: "INTJ")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您偏好的颜色是？"].waitForExistence(timeout: 8), "未进入颜色步骤")
        setPickerWheel(app, value: "白色系")
        tapPrimaryButton(app, title: "下一步")

        XCTAssertTrue(app.staticTexts["您的体重是？"].waitForExistence(timeout: 8), "未进入体重步骤")
        XCTAssertTrue(app.buttons["完成注册"].exists, "体重步骤缺少完成注册按钮")
    }

    private func openSettings(_ app: XCUIApplication) {
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8), "找不到设置 Tab")
        settingsTab.tap()
    }

    private func fillRegistrationAccountStep(app: XCUIApplication, username: String, nickname: String, password: String) {
        // Prefer stable accessibility labels over index-based lookup (the field ordering can shift).
        let usernameField = app.textFields["用户登录id（只能是字母和数字）"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 8), "找不到注册用户名输入框")
        usernameField.tap()
        usernameField.typeText(username)

        let nicknameField = app.textFields["用户昵称"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 8), "找不到注册昵称输入框")
        nicknameField.tap()
        nicknameField.typeText(nickname)

        let passwordField = inputField(app, label: "密码")
        XCTAssertTrue(passwordField.exists, "找不到注册密码输入框")
        passwordField.tap()
        passwordField.typeText(password)

        let confirmField = inputField(app, label: "确认密码")
        XCTAssertTrue(confirmField.exists, "找不到注册确认密码输入框")
        confirmField.tap()
        confirmField.typeText(password)

        dismissKeyboardIfNeeded(app)
        // Avoid iOS keychain overlays (e.g. "更新密码？") blocking subsequent taps.
        declineSavePasswordPromptIfNeeded(app, timeout: 1.2)
    }

    private func tapPrimaryButton(_ app: XCUIApplication, title: String) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "缺少按钮：\(title)")
        XCTAssertTrue(button.isEnabled, "按钮不可用：\(title)")
        button.tap()
    }

    private func setPickerWheel(_ app: XCUIApplication, value: String) {
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 8), "未找到滚轮选择器（目标值：\(value)）")
        wheel.adjust(toPickerWheelValue: value)
    }

    private func dismissKeyboardIfNeeded(_ app: XCUIApplication) {
        let done = app.buttons["完成"]
        if done.exists && done.isHittable {
            done.tap()
            return
        }
        app.tap()
    }

    private func tapOptionByCenter(_ app: XCUIApplication, label: String) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "缺少选项按钮：\(label)")

        if button.isHittable {
            button.tap()
            return
        }

        // SwiftUI option buttons can occasionally report "not hittable" to XCTest (e.g. transient overlays).
        // Using a coordinate tap bypasses XCTest's internal hit-point calculation.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func makeUniqueTestUsername(offset: Int = 0) -> String {
        // Use 4 digits per convention: lizyyy + 4 digits.
        let seed = (Int(Date().timeIntervalSince1970 * 1000) + offset) % 10000
        return String(format: "lizyyy%04d", seed)
    }

    private func declineSavePasswordPromptIfNeeded(_ app: XCUIApplication, timeout: TimeInterval = 2.5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyLabels = [
            "不保存", "不更新", "不更新密码", "否", "稍后", "以后", "取消",
            "Not Now", "Don't Save", "Don’t Save", "Never", "Cancel", "Don't Update", "Don’t Update"
        ]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            for host in [app, springboard] {
                for label in denyLabels {
                    let button = host.buttons[label]
                    if button.exists && button.isHittable {
                        button.tap()
                        return
                    }
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }
}
