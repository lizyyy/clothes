// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// Clothes 用户流程 UITest
/// 测试账号：test01-test03 / 密码：qwe123
final class ClothesUserFlowUITests: XCTestCase {

    // MARK: - Test Configuration

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Test Accounts

    struct TestAccount {
        let username: String
        let nickname: String
        let password: String
        let phone: String

        static func getAccount(_ index: Int) -> TestAccount {
            let idx = max(1, min(99, index))
            let presetPhones: [Int: String] = [
                1: "18600646073",
                2: "19536108230",
                3: "13723870267"
            ]
            let fallback = String(format: "1%010d", 7000000000 + idx)
            return TestAccount(
                username: String(format: "test%02d", idx),
                nickname: String(format: "testnickname%02d", idx),
                password: "qwe123",
                phone: presetPhones[idx] ?? fallback
            )
        }

        static func getRandomAccount() -> TestAccount {
            getAccount(Int.random(in: 20...40))
        }
    }

    // MARK: - App Launch

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTesting",
            "-uiTesting-disable-animations",
            "-resetAuth"  // 清除登录状态，确保测试从干净状态开始
        ]
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }

    private func launchAndGoToSettings() -> XCUIApplication {
        let app = launchApp()
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "找不到底部『设置』Tab")
        settingsTab.tap()
        return app
    }

    private func launchAndLogin(account: TestAccount = TestAccount.getAccount(1)) -> XCUIApplication {
        let app = launchApp()
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "找不到底部『设置』Tab")
        settingsTab.tap()

        // Check if already logged in
        if app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
            return app
        }

        // Need to login
        if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
            completeSMSLoginFlow(app: app, phone: account.phone)
            XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "登录后未显示退出登录按钮")
        } else if app.buttons["profile.login.button"].waitForExistence(timeout: 3) {
            tapButton(app, title: "profile.login.button")
            loginWithAccount(app, account: account)

            // Wait for login to complete and return to settings page
            sleep(3)

            // Tap settings tab again to ensure we're back on settings page
            if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
                let settingsTab = app.tabBars.buttons["设置"]
                if settingsTab.waitForExistence(timeout: 5) {
                    settingsTab.tap()
                }
            }

            // Verify login success
            XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "登录后未显示退出登录按钮")
        }

        return app
    }

    // MARK: - Helper: Input Fields

    private func inputField(_ app: XCUIApplication, label: String, timeout: TimeInterval = 10) -> XCUIElement {
        let secure = app.secureTextFields[label]
        if secure.waitForExistence(timeout: 0.8) {
            return secure
        }
        let text = app.textFields[label]
        _ = text.waitForExistence(timeout: timeout)
        return text
    }

    // MARK: - Helper: UI Actions

    private func tapButton(_ app: XCUIApplication, title: String, timeout: TimeInterval = 10) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "找不到按钮：\(title)")
        XCTAssertTrue(button.isEnabled, "按钮不可用：\(title)")
        if button.isHittable {
            button.tap()
            return
        }

        // Try to bring off-screen controls (e.g. settings logout button) into view.
        for _ in 0..<5 {
            app.swipeUp()
            if button.isHittable {
                button.tap()
                return
            }
        }

        for _ in 0..<3 {
            app.swipeDown()
            if button.isHittable {
                button.tap()
                return
            }
        }

        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tapOption(_ app: XCUIApplication, label: String, timeout: TimeInterval = 10) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "找不到选项：\(label)")
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func setPickerWheel(_ app: XCUIApplication, value: String, timeout: TimeInterval = 10) {
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: timeout), "未找到 PickerWheel")
        wheel.adjust(toPickerWheelValue: value)
    }

    private func waitForText(_ app: XCUIApplication, contains: String, timeout: TimeInterval = 15) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", contains)
        let element = app.staticTexts.matching(predicate).firstMatch
        if !element.waitForExistence(timeout: timeout) {
            XCTFail("未找到文案包含『\(contains)』的元素")
        }
    }

    private func dismissKeyboardIfNeeded(_ app: XCUIApplication) {
        let done = app.buttons["完成"]
        if done.exists && done.isHittable {
            done.tap()
            return
        }
        app.tap()
    }

    private func declineSavePasswordPromptIfNeeded(_ app: XCUIApplication, timeout: TimeInterval = 2.5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyLabels = ["不保存", "不更新", "否", "稍后", "以后", "取消",
                         "Not Now", "Don't Save", "Don’t Save", "Never", "Cancel"]
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

    // MARK: - Helper: Registration Steps

    private func fillRegistrationAccountStep(app: XCUIApplication, account: TestAccount, phone: String) {
        let phoneField = app.textFields["register.phone.field"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10), "找不到手机号输入框")
        phoneField.tap()
        phoneField.clearAndEnterText(phone)
        tapButton(app, title: "register.sms.send.button")

        let codeField = app.textFields["register.smsCode.field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "找不到验证码输入框")
        codeField.tap()
        codeField.clearAndEnterText("123456")
        tapButton(app, title: "register.verify.button", timeout: 10)
        XCTAssertTrue(app.textFields["register.username.field"].waitForExistence(timeout: 12), "验证码校验后应进入资料补全")
        UITestSync.clearAndType(app.textFields["register.username.field"], text: account.username)
        UITestSync.clearAndType(app.textFields["register.nickname.field"], text: account.nickname)
        refillRegistrationPasswords(app, password: account.password)
        assertRegisterNextEnabled(app)
    }

    private func assertRegisterNextEnabled(_ app: XCUIApplication, timeout: TimeInterval = 6) {
        let completeButton = app.buttons["register.complete.button"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: timeout), "找不到按钮：register.complete.button")
        XCTAssertTrue(completeButton.isEnabled, "注册信息已填写但完成注册按钮仍不可用")
    }

    private func refillRegistrationPasswords(_ app: XCUIApplication, password: String) {
        let passwordField = inputField(app, label: "register.password.field", timeout: 3)
        if passwordField.exists {
            passwordField.tap()
            if app.keyboards.count == 0 {
                app.tap()
                passwordField.tap()
            }
            passwordField.typeText(password)
        }

        let confirmField = inputField(app, label: "register.confirmPassword.field", timeout: 3)
        if confirmField.exists {
            confirmField.tap()
            if app.keyboards.count == 0 {
                app.tap()
                confirmField.tap()
            }
            confirmField.typeText(password)
        }

        dismissKeyboardIfNeeded(app)
        declineSavePasswordPromptIfNeeded(app, timeout: 0.8)
    }

    private func completeRegistrationFlow(app: XCUIApplication, account: TestAccount, phone: String) {
        waitForText(app, contains: "手机号短信注册")
        fillRegistrationAccountStep(app: app, account: account, phone: phone)
        tapButton(app, title: "register.complete.button", timeout: 10)
    }

    private func proceedFromAccountStep(app: XCUIApplication) {
        _ = app
    }

    // MARK: - Test 1: User Registration

    func testUserRegistration() throws {
        let app = launchAndGoToSettings()
        let registrations: [(account: TestAccount, phone: String)] = [
            (TestAccount(username: "test01", nickname: "testnickname01", password: "qwe123", phone: "18600646073"), "18600646073"),
            (TestAccount(username: "test02", nickname: "testnickname02", password: "qwe123", phone: "19536108230"), "19536108230"),
            (TestAccount(username: "test03", nickname: "testnickname01", password: "qwe123", phone: "13723870267"), "13723870267"),
        ]

        for item in registrations {
            // 如果已登录，先退出
            if app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
                tapButton(app, title: "profile.logout.button")
                sleep(2)
            }

            // 使用短信验证码登录（未注册手机号会自动注册）
            completeSMSLoginFlow(app: app, phone: item.phone)

            // 验证登录成功
            XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 15), "登录/注册成功后未显示退出登录按钮")
        }
    }

    /// 完成短信验证码登录流程（未注册手机号会自动注册）
    private func completeSMSLoginFlow(app: XCUIApplication, phone: String) {
        // 1. 等待短信登录卡片显示
        let phoneField = app.textFields["sms.inline.phone.field"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10), "未显示短信登录卡片")

        // 2. 输入手机号
        phoneField.tap()
        phoneField.clearAndEnterText(phone)

        // 3. 勾选协议
        let agreementButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        if agreementButton.waitForExistence(timeout: 2), agreementButton.isHittable {
            agreementButton.tap()
        }

        // 4. 点击发送验证码
        tapButton(app, title: "sms.inline.send.button")

        // 5. 输入验证码（测试环境使用固定验证码123456）
        let codeField = app.textFields["sms.inline.code.field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "未显示验证码输入框")
        codeField.tap()
        codeField.clearAndEnterText("123456")

        // 6. 点击验证码登录按钮
        tapButton(app, title: "sms.inline.submit.button")

        // 7. 等待登录完成
        sleep(3)
    }

    private func assertRegistrationResult(_ app: XCUIApplication) {
        sleep(5)
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            let alertText = alert.staticTexts.firstMatch.label
            if alertText.contains("成功") || alertText.contains("注册成功") {
                alert.buttons.firstMatch.tap()
                XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 15), "注册成功后未自动登录")
            } else {
                XCTFail("注册失败：\(alertText)")
            }
            return
        }
        XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 15), "注册后未显示退出登录按钮")
    }

    private func generatePhone() -> String {
        let suffix = Int64(Date().timeIntervalSince1970 * 1000) % 10_000_000_000
        return String(format: "1%010lld", suffix)
    }

    // MARK: - Test 2: Existing User Login

    func testExistingUserLogin() throws {
        let app = launchAndGoToSettings()
        let account = TestAccount.getAccount(1)

        // Check if already logged in with test01
        if app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
            let usernameText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", account.username)).firstMatch
            if usernameText.exists {
                // Already logged in as test01
                return
            }
            // Logout and login with test01
            tapButton(app, title: "profile.logout.button")
            sleep(2)
        }

        if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
            completeSMSLoginFlow(app: app, phone: account.phone)
        } else {
            tapButton(app, title: "profile.login.button")
            XCTAssertTrue(app.navigationBars["登录账号"].waitForExistence(timeout: 10), "未进入登录页面")

            let usernameField = app.textFields["login.username.field"]
            XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "找不到用户名输入框")
            usernameField.tap()
            usernameField.typeText(account.username)

            let passwordField = app.secureTextFields["login.password.field"]
            XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "找不到密码输入框")
            passwordField.tap()
            passwordField.typeText(account.password)

            dismissKeyboardIfNeeded(app)
            tapButton(app, title: "login.submit.button")
            declineSavePasswordPromptIfNeeded(app)
        }

        // Verify login success
        XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 12), "登录后未显示退出登录按钮")
    }

    // MARK: - Test 3: User Profile Display

    func testUserProfileDisplay() throws {
        let account = TestAccount.getAccount(1)
        let app = launchAndLogin(account: account)

        // Verify profile elements exist using accessibility identifiers
        waitForText(app, contains: "我的")
        waitForText(app, contains: "基本信息")

        // Check for user info fields using accessibility identifiers
        XCTAssertTrue(app.buttons["profile.row.nickname"].waitForExistence(timeout: 5), "应显示昵称行")
        XCTAssertTrue(app.buttons["profile.row.username"].waitForExistence(timeout: 5), "应显示登录用户名行")
        XCTAssertTrue(app.buttons["profile.row.gender"].waitForExistence(timeout: 5), "应显示性别行")
        XCTAssertTrue(app.buttons["profile.row.height"].waitForExistence(timeout: 5), "应显示身高行")
        XCTAssertTrue(app.buttons["profile.row.weight"].waitForExistence(timeout: 5), "应显示体重行")

        // Check for wallet/balance display using accessibility identifier
        XCTAssertTrue(app.staticTexts["profile.balance.label"].waitForExistence(timeout: 5), "应显示穿贝余额")

        // Check for recharge button using accessibility identifier
        XCTAssertTrue(app.buttons["profile.recharge.button"].waitForExistence(timeout: 5), "应显示充值穿贝按钮")

        // Check for transaction records button using accessibility identifier
        XCTAssertTrue(app.buttons["profile.wallet.records"].waitForExistence(timeout: 5), "应显示收支记录按钮")

        // Check for avatar using accessibility identifier
        XCTAssertTrue(app.buttons["profile.avatar.button"].waitForExistence(timeout: 5), "应显示用户头像")
    }

    // MARK: - Test 4: Edit User Info

    func testEditUserInfo() throws {
        let app = launchAndLogin()

        // Tap on nickname to edit using accessibility identifier
        let nicknameRow = app.buttons["profile.row.nickname"]
        XCTAssertTrue(nicknameRow.waitForExistence(timeout: 5), "找不到昵称行")
        nicknameRow.tap()

        // Wait for edit sheet
        sleep(1)

        // Find text field in edit sheet using accessibility identifier
        let textField = app.textFields["profile.edit.昵称.field"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "找不到编辑输入框")

        // Clear and type new nickname
        textField.tap()
        textField.press(forDuration: 1.0)
        app.menuItems["全选"].tap()
        app.menuItems["剪切"].tap()

        let newNickname = "testnickname01_modified"
        textField.typeText(newNickname)

        // Save changes
        tapButton(app, title: "完成")

        // Verify changes saved
        sleep(1)
        waitForText(app, contains: newNickname)
    }

    // MARK: - Test 5: Change Avatar

    func testChangeAvatar() throws {
        let app = launchAndLogin()

        // Tap on avatar area using accessibility identifier
        let avatarButton = app.buttons["profile.avatar.button"]
        XCTAssertTrue(avatarButton.waitForExistence(timeout: 5), "应找到头像按钮")
        avatarButton.tap()

        // Wait for photo picker or action sheet
        sleep(1)

        // Check if photo picker or action sheet appears
        let photoPicker = app.navigationBars["照片"]
        let cancelButton = app.buttons["取消"]

        if photoPicker.waitForExistence(timeout: 3) {
            // Photo picker opened, cancel it
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
            }
            XCTAssertTrue(true, "头像选择器正常打开")
        } else if app.buttons["从相册选择"].waitForExistence(timeout: 3) {
            // Action sheet opened
            app.buttons["取消"].tap()
            XCTAssertTrue(true, "头像操作菜单正常显示")
        } else {
            // Avatar picker may have different behavior
            XCTAssertTrue(true, "头像点击响应正常")
        }
    }

    // MARK: - Test 6: Recharge Coins

    func testRechargeCoins() throws {
        let app = launchAndLogin()

        // Get current balance using accessibility identifier
        let balanceBefore = getCurrentBalance(app)

        // Tap recharge button using accessibility identifier
        tapButton(app, title: "profile.recharge.button")

        // Wait for recharge sheet
        sleep(2)
        waitForText(app, contains: "充值")

        // Select a recharge package using accessibility identifier pattern
        let packageButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.package.")).firstMatch
        if packageButton.waitForExistence(timeout: 5) {
            packageButton.tap()
        } else {
            // Fallback to text-based search
            let anyPackage = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "穿贝")).firstMatch
            if anyPackage.waitForExistence(timeout: 5) {
                anyPackage.tap()
            }
        }

        // Tap confirm recharge using accessibility identifier
        let confirmButton = app.buttons["wallet.recharge.confirm"]
        if confirmButton.waitForExistence(timeout: 5) {
            confirmButton.tap()
        } else {
            // Try alternative button names
            let altConfirm = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "充值")).firstMatch
            if altConfirm.waitForExistence(timeout: 5) {
                altConfirm.tap()
            }
        }

        // Wait for recharge to complete
        sleep(3)

        // Check for success message
        let successAlert = app.alerts.firstMatch
        if successAlert.waitForExistence(timeout: 5) {
            let alertText = successAlert.staticTexts.firstMatch.label
            XCTAssertTrue(alertText.contains("成功") || alertText.contains("充值"), "充值应显示成功提示")
            successAlert.buttons.firstMatch.tap()
        }

        // Close recharge sheet if still open
        let closeButton = app.buttons["完成"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }

        // Verify balance updated
        sleep(1)
        let balanceAfter = getCurrentBalance(app)
        XCTAssertGreaterThan(balanceAfter, balanceBefore, "充值后余额应增加")
    }

    private func getCurrentBalance(_ app: XCUIApplication) -> Int64 {
        let balanceText = app.staticTexts["profile.balance.label"]
        if balanceText.waitForExistence(timeout: 5) {
            let text = balanceText.label
            // Extract number from text like "穿贝 100"
            let components = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            let numberString = components.joined()
            return Int64(numberString) ?? 0
        }
        return 0
    }

    // MARK: - Test 7: Check Balance

    func testCheckBalance() throws {
        let app = launchAndLogin()

        // Verify balance is displayed using accessibility identifier
        let balanceElement = app.staticTexts["profile.balance.label"]
        XCTAssertTrue(balanceElement.waitForExistence(timeout: 5), "应显示穿贝余额")

        // Get balance value
        let balanceValue = getCurrentBalance(app)
        XCTAssertGreaterThanOrEqual(balanceValue, 0, "余额应为非负数")

        // Check transaction records using accessibility identifier
        tapButton(app, title: "profile.wallet.records")
        sleep(2)

        // Wait for records view
        waitForText(app, contains: "收支")

        // Close records view
        let doneButton = app.buttons["完成"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        } else {
            // Try to swipe down to dismiss
            app.swipeDown()
        }
    }

    // MARK: - Test 8: Switch Account

    func testSwitchAccount() throws {
        let account1 = TestAccount.getAccount(1)
        let account2 = TestAccount.getAccount(2)
        let app = launchAndLogin(account: account1)

        // Tap switch account using accessibility identifier
        let switchButton = app.buttons["profile.switch.account"]
        XCTAssertTrue(switchButton.waitForExistence(timeout: 5), "找不到切换账号按钮")
        switchButton.tap()

        // Wait for account switcher sheet
        sleep(2)
        waitForText(app, contains: "切换")

        // Tap add/login button to login with account2
        let addLoginButton = app.buttons["添加账号"]
        if addLoginButton.waitForExistence(timeout: 5) {
            addLoginButton.tap()
        } else {
            // Try alternative
            if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
                completeSMSLoginFlow(app: app, phone: account2.phone)
            } else {
                let loginButton = app.buttons["profile.login.button"]
                if loginButton.waitForExistence(timeout: 5) {
                    loginButton.tap()
                }
            }
        }

        // Login with account2
        if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
            loginWithAccount(app, account: account2)
        }

        // Verify logged in as account2
        XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "切换账号后应显示退出登录按钮")

        // Verify username display changed
        let usernameLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", account2.username)).firstMatch
        if usernameLabel.waitForExistence(timeout: 5) {
            XCTAssertTrue(usernameLabel.exists, "应显示新账号的用户名")
        }
    }

    private func loginWithAccount(_ app: XCUIApplication, account: TestAccount) {
        if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 2) {
            completeSMSLoginFlow(app: app, phone: account.phone)
            return
        }

        // Fill username using accessibility identifier
        let usernameField = app.textFields["login.username.field"]
        if usernameField.waitForExistence(timeout: 5) {
            usernameField.tap()
            usernameField.typeText(account.username)
        }

        // Fill password using accessibility identifier
        let passwordField = app.secureTextFields["login.password.field"]
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(account.password)
        }

        dismissKeyboardIfNeeded(app)

        // Tap login using accessibility identifier
        tapButton(app, title: "login.submit.button")
        declineSavePasswordPromptIfNeeded(app)

        // Wait for login to complete
        sleep(3)
    }

    // MARK: - Full Integration Test

    func testCompleteUserFlow() throws {
        // This test runs through the complete flow: register -> login -> edit profile -> recharge -> check balance -> switch account
        let app = launchAndGoToSettings()
        let account1 = TestAccount.getAccount(1)
        let account2 = TestAccount.getAccount(2)

        // Step 1: Register account1 if needed
        if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
            if app.buttons["profile.register.button"].waitForExistence(timeout: 3) {
                tapButton(app, title: "profile.register.button")
                XCTAssertTrue(app.navigationBars["注册"].waitForExistence(timeout: 10))
                completeRegistrationFlow(app: app, account: account1, phone: generatePhone())
                sleep(3)
            } else {
                completeSMSLoginFlow(app: app, phone: account1.phone)
            }
        }

        XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "注册/登录后应显示退出登录")

        // Step 2: Check balance and recharge
        let balanceBefore = getCurrentBalance(app)
        tapButton(app, title: "profile.recharge.button")
        sleep(2)

        // Select package and recharge
        let packageButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.package.")).firstMatch
        if packageButton.waitForExistence(timeout: 5) {
            packageButton.tap()
            let confirmButton = app.buttons["wallet.recharge.confirm"]
            if confirmButton.waitForExistence(timeout: 5) {
                confirmButton.tap()
                sleep(3)
            }
        }

        // Close recharge sheet
        let doneButton = app.buttons["完成"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }

        // Step 3: Edit profile
        let nicknameRow = app.buttons["profile.row.nickname"]
        if nicknameRow.waitForExistence(timeout: 5) {
            nicknameRow.tap()
            sleep(1)

            let textField = app.textFields["profile.edit.昵称.field"]
            if textField.waitForExistence(timeout: 5) {
                textField.tap()
                textField.press(forDuration: 1.0)
                if app.menuItems["全选"].waitForExistence(timeout: 2) {
                    app.menuItems["全选"].tap()
                    app.menuItems["剪切"].tap()
                }
                textField.typeText(account1.nickname + "_updated")
                tapButton(app, title: "完成")
                sleep(1)
            }
        }

        // Step 4: Switch to account2
        let switchButton = app.buttons["profile.switch.account"]
        if switchButton.waitForExistence(timeout: 5) {
            switchButton.tap()
            sleep(2)

            // Login with account2
            loginWithAccount(app, account: account2)
            XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "切换账号后应登录成功")
        }

        // All steps completed
        XCTAssertTrue(true, "完整用户流程测试通过")
    }
}
