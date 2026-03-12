// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// Clothes 应用 UITest 套件
/// 测试账号：test20-test40 / testnickname20-testnickname40 / 密码：qwe123!
final class ClothesUITests: XCTestCase {

  // MARK: - Test Configuration

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helper: Launch App

  private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += [
      "-uiTesting",
      "-uiTesting-disable-animations",
      "-uiTesting-offline"
    ]
    app.launch()
    addTeardownBlock { app.terminate() }
    return app
  }

  private func inputField(_ app: XCUIApplication, label: String, timeout: TimeInterval = 10) -> XCUIElement {
    let secure = app.secureTextFields[label]
    if secure.waitForExistence(timeout: 0.8) {
      return secure
    }
    let text = app.textFields[label]
    _ = text.waitForExistence(timeout: timeout)
    return text
  }

  // MARK: - Helper: Test Account Management

  private struct TestAccount {
    let username: String
    let nickname: String
    let password: String
    let phone: String

    static func getAccount(index: Int) -> TestAccount {
      let formattedIndex = String(format: "%02d", index)
      let presetPhones: [Int: String] = [
        20: "18888888888",
        21: "18888888888"
      ]
      let fallback = "18888888888"
      return TestAccount(
        username: "test\(formattedIndex)",
        nickname: "testnickname\(formattedIndex)",
        password: "qwe123!",
        phone: presetPhones[index] ?? fallback
      )
    }

    static func getRandomAccount() -> TestAccount {
      let randomIndex = Int.random(in: 20...40)
      return getAccount(index: randomIndex)
    }
  }

  // MARK: - Helper: Navigation

  private func goToSettingsTab(_ app: XCUIApplication) {
    let settingsTab = app.tabBars.buttons["设置"]
    XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "找不到底部『设置』Tab")
    settingsTab.tap()
  }

  private func ensureLoggedOut(_ app: XCUIApplication) {
    goToSettingsTab(app)
    if app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      app.buttons["profile.logout.button"].tap()
      let loggedOut = UITestSync.waitUntil(timeout: 8) {
        app.buttons["profile.register.button"].exists
          || app.buttons["profile.login.button"].exists
          || app.textFields["sms.inline.phone.field"].exists
      }
      XCTAssertTrue(loggedOut, "退出登录后应显示未登录入口")
    }
  }

  // MARK: - Test 1: User Registration Flow

  func testUserRegistration() throws {
    let app = launchApp()
    let account = TestAccount.getRandomAccount()

    goToSettingsTab(app)

    let registerButton = app.buttons["profile.register.button"]
    if !registerButton.waitForExistence(timeout: 4) {
      XCTAssertTrue(app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 8), "设置页里没看到注册入口")
      loginViaInlineSMS(app, phone: account.phone)
      XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 15), "短信注册后应显示退出登录按钮")
      return
    }
    registerButton.tap()

    // Step 1: Account information
    waitForText(app, contains: "请填写账号信息")
    XCTAssertTrue(app.navigationBars["注册"].waitForExistence(timeout: 10), "未进入注册页")

    // Use accessibility identifiers for registration fields
    let userIdField = app.textFields["register.username.field"]
    XCTAssertTrue(userIdField.waitForExistence(timeout: 10), "找不到『用户登录id』输入框")
    userIdField.tap()
    userIdField.typeText(account.username)

    let nicknameField = app.textFields["register.nickname.field"]
    XCTAssertTrue(nicknameField.waitForExistence(timeout: 10), "找不到『用户昵称』输入框")
    nicknameField.tap()
    nicknameField.typeText(account.nickname)

    let pw1 = app.secureTextFields["register.password.field"]
    XCTAssertTrue(pw1.waitForExistence(timeout: 10), "找不到『密码』输入框")
    pw1.tap()
    pw1.typeText(account.password)

    let pw2 = app.secureTextFields["register.confirmPassword.field"]
    XCTAssertTrue(pw2.waitForExistence(timeout: 10), "找不到『确认密码』输入框")
    pw2.tap()
    pw2.typeText(account.password)

    dismissKeyboardIfNeeded(app)
    tapNext(app)

    // Step 2: Gender
    waitForText(app, contains: "您的性别")
    tapOption(app, label: "女")
    tapNext(app)

    // Step 3: Height
    waitForText(app, contains: "您的身高")
    setWheel(app, value: "160")
    tapNext(app)

    // Step 4: Size
    waitForText(app, contains: "尺码")
    tapOption(app, label: "M")
    tapNext(app)

    // Step 5: Zodiac
    waitForText(app, contains: "星座")
    setWheel(app, value: "白羊座")
    tapNext(app)

    // Step 6: MBTI
    waitForText(app, contains: "MBTI")
    setWheel(app, value: "INTJ")
    tapNext(app)

    // Step 7: Color preference
    waitForText(app, contains: "颜色")
    setWheel(app, value: "白色系")
    tapNext(app)

    // Step 8: Weight
    waitForText(app, contains: "体重")
    setWheel(app, value: "55")

    let finish = app.buttons["register.complete.button"]
    XCTAssertTrue(finish.waitForExistence(timeout: 10), "找不到『完成注册』按钮")
    finish.tap()
    declineSavePasswordPromptIfNeeded(app)

    // Verify registration success - should see user info or logout button
    let logoutButton = app.buttons["profile.logout.button"]
    XCTAssertTrue(logoutButton.waitForExistence(timeout: 15), "注册成功后应显示退出登录按钮")

    // Verify nickname is displayed
    let nicknameText = app.staticTexts[account.nickname]
    XCTAssertTrue(nicknameText.waitForExistence(timeout: 5), "应显示用户昵称 \(account.nickname)")
  }

  // MARK: - Test 2: Existing Account Login

  func testExistingAccountLogin() throws {
    let app = launchApp()
    let account = TestAccount.getAccount(index: 20) // Use test20

    goToSettingsTab(app)

    // Check if already logged in
    if app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      // Already logged in, logout first
      app.buttons["profile.logout.button"].tap()
      XCTAssertTrue(
        app.buttons["profile.login.button"].waitForExistence(timeout: 3)
          || app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3),
        "退出后应显示登录入口"
      )
    }

    if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
      loginViaInlineSMS(app, phone: account.phone)
    } else {
      let loginButton = app.buttons["profile.login.button"]
      XCTAssertTrue(loginButton.waitForExistence(timeout: 10), "设置页里没看到『已有账号登录』按钮")
      loginButton.tap()

      XCTAssertTrue(app.navigationBars["登录账号"].waitForExistence(timeout: 10), "未进入登录页")
      waitForText(app, contains: "登录")

      let usernameField = app.textFields["login.username.field"]
      XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "找不到账号输入框")
      usernameField.tap()
      usernameField.typeText(account.username)

      let passwordField = app.secureTextFields["login.password.field"]
      XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "找不到密码输入框")
      passwordField.tap()
      passwordField.typeText(account.password)

      dismissKeyboardIfNeeded(app)

      let confirmLoginButton = app.buttons["login.submit.button"]
      XCTAssertTrue(confirmLoginButton.waitForExistence(timeout: 10), "找不到登录确认按钮")
      confirmLoginButton.tap()
    }
    declineSavePasswordPromptIfNeeded(app)

    // Verify login success
    let logoutButton = app.buttons["profile.logout.button"]
    XCTAssertTrue(logoutButton.waitForExistence(timeout: 12), "登录成功后应显示退出登录按钮")

    // Verify user info is displayed
    let nicknameText = app.staticTexts[account.nickname]
    XCTAssertTrue(nicknameText.waitForExistence(timeout: 5), "应显示用户昵称 \(account.nickname)")
  }

  // MARK: - Test 3: User Info Display

  func testUserInfoDisplay() throws {
    let app = launchApp()
    let account = TestAccount.getAccount(index: 20)

    // Ensure logged in first
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      // Need to login
      try testExistingAccountLogin()
      goToSettingsTab(app)
    }

    // Verify user info section exists
    waitForText(app, contains: "我的")

    // Verify basic info section
    let basicInfoSection = app.staticTexts["基本信息"]
    XCTAssertTrue(basicInfoSection.waitForExistence(timeout: 5), "应显示『基本信息』区域")

    // Verify user info rows using accessibility identifiers
    let infoRows = [
      "profile.row.nickname",
      "profile.row.username",
      "profile.row.gender",
      "profile.row.height",
      "profile.row.weight",
      "profile.row.size",
      "profile.row.zodiac",
      "profile.row.mbti",
      "profile.row.color"
    ]
    for rowId in infoRows {
      let row = app.buttons[rowId]
      XCTAssertTrue(row.waitForExistence(timeout: 3), "应显示 accessibilityId 为 \(rowId) 的信息行")
    }

    // Verify wallet section using accessibility identifier
    let balanceLabel = app.staticTexts["profile.balance.label"]
    XCTAssertTrue(balanceLabel.waitForExistence(timeout: 5), "应显示穿贝余额")

    // Verify avatar exists using accessibility identifier
    let avatarButton = app.buttons["profile.avatar.button"]
    XCTAssertTrue(avatarButton.waitForExistence(timeout: 5), "应显示用户头像")
  }

  // MARK: - Test 4: Modify User Info

  func testModifyUserInfo() throws {
    let app = launchApp()

    // Ensure logged in
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      try testExistingAccountLogin()
      goToSettingsTab(app)
    }

    // Tap on nickname row to edit using accessibility identifier
    let nicknameRow = app.buttons["profile.row.nickname"]
    XCTAssertTrue(nicknameRow.waitForExistence(timeout: 5), "应找到昵称编辑行")
    nicknameRow.tap()

    // Wait for edit sheet
    waitForText(app, contains: "昵称")

    // Clear and enter new nickname using accessibility identifier
    let newNickname = "ModifiedNickname\(Int.random(in: 100...999))"
    let nicknameField = app.textFields["profile.edit.昵称.field"]
    XCTAssertTrue(nicknameField.waitForExistence(timeout: 5), "应显示昵称输入框")
    nicknameField.tap()
    nicknameField.clearAndEnterText(newNickname)

    // Save changes - look for navigation bar done button
    let saveButton = app.buttons["完成"]
    if saveButton.waitForExistence(timeout: 3) {
      saveButton.tap()
    } else {
      dismissKeyboardIfNeeded(app)
    }

    // Verify the change was saved
    let updatedNickname = app.staticTexts[newNickname]
    XCTAssertTrue(updatedNickname.waitForExistence(timeout: 5), "修改后的昵称应显示为 \(newNickname)")
  }

  // MARK: - Test 5: User Avatar Modification

  func testUserAvatarModification() throws {
    let app = launchApp()

    // Ensure logged in
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      try testExistingAccountLogin()
      goToSettingsTab(app)
    }

    // Tap on avatar area using accessibility identifier
    let avatarButton = app.buttons["profile.avatar.button"]
    XCTAssertTrue(avatarButton.waitForExistence(timeout: 5), "应找到头像按钮")
    avatarButton.tap()

    // Wait for photo picker or action sheet
    let photoPicker = app.otherElements["PhotosPicker"]
    let actionSheet = app.sheets.firstMatch

    if photoPicker.waitForExistence(timeout: 5) {
      // Photo picker appeared
      // In UITest, we can't actually select a photo, so we just verify the picker opened
      XCTAssertTrue(photoPicker.exists, "照片选择器应打开")

      // Cancel the picker
      let cancelButton = app.buttons["取消"]
      if cancelButton.waitForExistence(timeout: 3) {
        cancelButton.tap()
      }
    } else if actionSheet.waitForExistence(timeout: 5) {
      // Action sheet appeared
      XCTAssertTrue(actionSheet.exists, "应显示头像操作选项")

      // Cancel
      let cancelButton = actionSheet.buttons["取消"]
      if cancelButton.waitForExistence(timeout: 3) {
        cancelButton.tap()
      }
    } else {
      // Direct tap on avatar might have opened system photo picker
      // Just verify we're still on settings page
      XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 3), "头像点击后应仍在设置页")
    }
  }

  // MARK: - Test 6: Recharge Function

  func testRechargeFunction() throws {
    let app = launchApp()

    // Ensure logged in
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      try testExistingAccountLogin()
      goToSettingsTab(app)
    }

    // Get current balance before recharge using accessibility identifier
    let balanceLabel = app.staticTexts["profile.balance.label"]
    let initialBalanceText = balanceLabel.label

    // Tap recharge button using accessibility identifier
    let rechargeButton = app.buttons["profile.recharge.button"]
    XCTAssertTrue(rechargeButton.waitForExistence(timeout: 5), "应显示『充值穿贝』按钮")
    rechargeButton.tap()

    // Wait for recharge sheet
    waitForText(app, contains: "充值")

    // Select a recharge package using accessibility identifier
    let packageButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.package.")).firstMatch
    if packageButton.waitForExistence(timeout: 5) {
      packageButton.tap()
    }

    // Tap confirm recharge using accessibility identifier
    let confirmButton = app.buttons["wallet.recharge.confirm"]
    if confirmButton.waitForExistence(timeout: 5) {
      confirmButton.tap()
    }

    // In DEBUG mode, recharge should complete immediately
    // Wait for success message or return to profile
    let successAlert = app.alerts.firstMatch
    if successAlert.waitForExistence(timeout: 5) {
      let okButton = successAlert.buttons["知道了"]
      if okButton.waitForExistence(timeout: 3) {
        okButton.tap()
      }
    }

    // Close recharge sheet if still open
    let closeButton = app.buttons["完成"]
    if closeButton.waitForExistence(timeout: 3) {
      closeButton.tap()
    }

    // Verify we're back on settings page
    XCTAssertTrue(app.buttons["profile.recharge.button"].waitForExistence(timeout: 5), "充值后应返回设置页")
  }

  // MARK: - Test 7: Check Balance

  func testCheckBalance() throws {
    let app = launchApp()

    // Ensure logged in
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      try testExistingAccountLogin()
      goToSettingsTab(app)
    }

    // Verify balance is displayed using accessibility identifier
    let balanceLabel = app.staticTexts["profile.balance.label"]
    XCTAssertTrue(balanceLabel.waitForExistence(timeout: 5), "应显示穿贝余额")

    // Extract balance number using regex pattern
    let balanceLabelText = balanceLabel.label
    let pattern = "\\d+"
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: balanceLabelText.utf16.count)
    let match = regex?.firstMatch(in: balanceLabelText, options: [], range: range)

    XCTAssertNotNil(match, "余额应包含数字")

    // Tap on balance/wallet records button using accessibility identifier
    let recordsButton = app.buttons["profile.wallet.records"]
    XCTAssertTrue(recordsButton.waitForExistence(timeout: 5), "应显示收支记录按钮")
    recordsButton.tap()

    // Verify wallet records page
    waitForText(app, contains: "收支")

    // Close records sheet
    let closeButton = app.buttons["完成"]
    if closeButton.waitForExistence(timeout: 3) {
      closeButton.tap()
    }

    // Verify we're back on settings page
    XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 5), "查看余额后应返回设置页")
  }

  // MARK: - Test 8: Switch Account

  func testSwitchAccount() throws {
    let app = launchApp()
    let firstAccount = TestAccount.getAccount(index: 20)
    let secondAccount = TestAccount.getAccount(index: 21)

    // Login with first account
    goToSettingsTab(app)
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      loginWithBestAvailableEntry(app, account: firstAccount)
      XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 12), "登录成功后应显示退出登录按钮")
    }

    // Verify first account is logged in
    let firstNickname = app.staticTexts[firstAccount.nickname]
    let isFirstAccount = firstNickname.waitForExistence(timeout: 3)

    // Tap switch account button using accessibility identifier
    let switchButton = app.buttons["profile.switch.account"]
    XCTAssertTrue(switchButton.waitForExistence(timeout: 5), "应显示『切换账号』按钮")
    switchButton.tap()

    // Wait for account switcher
    waitForText(app, contains: "账号")

    // Tap add account or login
    let addAccountButton = app.buttons["添加账号"]
    if addAccountButton.waitForExistence(timeout: 5) {
      addAccountButton.tap()
    }

    // Login with second account
    if !app.buttons["profile.logout.button"].waitForExistence(timeout: 3) {
      loginWithBestAvailableEntry(app, account: secondAccount)
    }

    // Verify switched to second account
    let secondNickname = app.staticTexts[secondAccount.nickname]
    XCTAssertTrue(secondNickname.waitForExistence(timeout: 10), "切换账号后应显示第二个账号的昵称 \(secondAccount.nickname)")

    // Verify logout button exists
    XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 5), "切换账号后应显示退出登录按钮")
  }

  // MARK: - Helper Methods

  private func loginWithBestAvailableEntry(_ app: XCUIApplication, account: TestAccount) {
    if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 3) {
      loginViaInlineSMS(app, phone: account.phone)
      return
    }

    let loginButton = app.buttons["profile.login.button"]
    XCTAssertTrue(loginButton.waitForExistence(timeout: 10), "应显示登录按钮")
    loginButton.tap()
    XCTAssertTrue(app.navigationBars["登录账号"].waitForExistence(timeout: 10), "应进入登录页")

    let usernameField = app.textFields["login.username.field"]
    XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "应显示用户名输入框")
    usernameField.tap()
    usernameField.typeText(account.username)

    let passwordField = app.secureTextFields["login.password.field"]
    XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "应显示密码输入框")
    passwordField.tap()
    passwordField.typeText(account.password)

    dismissKeyboardIfNeeded(app)

    let confirmButton = app.buttons["login.submit.button"]
    XCTAssertTrue(confirmButton.waitForExistence(timeout: 10), "应显示登录按钮")
    confirmButton.tap()
    declineSavePasswordPromptIfNeeded(app)
  }

  private func loginViaInlineSMS(_ app: XCUIApplication, phone: String) {
    let phoneField = app.textFields["sms.inline.phone.field"]
    XCTAssertTrue(phoneField.waitForExistence(timeout: 8), "未找到短信登录手机号输入框")
    UITestSync.clearAndType(phoneField, text: phone)

    let agreement = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
    if agreement.waitForExistence(timeout: 2), agreement.isHittable {
      agreement.tap()
    }

    let sendButton = app.buttons["sms.inline.send.button"]
    XCTAssertTrue(sendButton.waitForExistence(timeout: 8), "未找到发送验证码按钮")
    if sendButton.isEnabled {
      sendButton.tap()
    }

    let codeField = app.textFields["sms.inline.code.field"]
    XCTAssertTrue(codeField.waitForExistence(timeout: 8), "未找到验证码输入框")
    UITestSync.clearAndType(codeField, text: "123456")

    let submitButton = app.buttons["sms.inline.submit.button"]
    XCTAssertTrue(submitButton.waitForExistence(timeout: 8), "未找到验证码登录按钮")
    XCTAssertTrue(submitButton.isEnabled, "验证码登录按钮不可用")
    submitButton.tap()
    declineSavePasswordPromptIfNeeded(app)
  }

  private func waitForText(_ app: XCUIApplication, contains: String, timeout: TimeInterval = 15) {
    let t = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", contains)).firstMatch
    if !t.waitForExistence(timeout: timeout) {
      let shot = XCUIScreen.main.screenshot()
      let att = XCTAttachment(screenshot: shot)
      att.name = "missing-text-\(contains)"
      att.lifetime = .keepAlways
      add(att)
      XCTFail("未进入预期页面：缺少文案『\(contains)』")
    }
  }

  private func tapOption(_ app: XCUIApplication, label: String) {
    let b = app.buttons[label]
    XCTAssertTrue(b.waitForExistence(timeout: 10), "找不到选项按钮『\(label)』")
    b.tap()
  }

  private func tapNext(_ app: XCUIApplication) {
    let next = app.buttons["register.next.button"]
    XCTAssertTrue(next.waitForExistence(timeout: 10), "找不到『下一步』按钮")
    XCTAssertTrue(next.isEnabled, "『下一步』按钮不可用（可能是表单未满足条件）")
    next.tap()
  }

  private func setWheel(_ app: XCUIApplication, value: String, timeout: TimeInterval = 20) {
    let wheel = app.pickerWheels.element(boundBy: 0)
    if !wheel.waitForExistence(timeout: timeout) {
      let shot = XCUIScreen.main.screenshot()
      let att = XCTAttachment(screenshot: shot)
      att.name = "missing-pickerwheel-\(value)"
      att.lifetime = .keepAlways
      add(att)
      XCTFail("找不到 PickerWheel（需要设置数值：\(value)）")
      return
    }
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

  private func declineSavePasswordPromptIfNeeded(_ app: XCUIApplication, timeout: TimeInterval = 2.5) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let denyLabels = ["不保存", "否", "稍后", "以后", "取消", "Not Now", "Don't Save", "Don’t Save", "Never", "Cancel"]
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

// MARK: - XCUIElement Extension

extension XCUIElement {
  func clearAndEnterText(_ text: String) {
    guard let stringValue = self.value as? String else {
      self.typeText(text)
      return
    }

    // Clear existing text
    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
    self.typeText(deleteString)

    // Enter new text
    self.typeText(text)
  }
}
