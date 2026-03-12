// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 个人中心页面封装
/// 提供个人中心页面的元素访问和操作封装
/// 支持链式调用，返回新页面实例
struct ProfilePage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查用户是否已登录
    /// - Returns: true 如果显示退出登录按钮，表示已登录
    var isLoggedIn: Bool {
        return app.buttons["profile.logout.button"].waitForExistence(timeout: 3)
    }

    /// 检查是否显示登录按钮
    /// - Returns: true 如果显示登录按钮，表示未登录
    var isDisplayingLoginButton: Bool {
        return app.buttons["profile.login.button"].waitForExistence(timeout: 2)
            || app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 2)
    }

    /// 检查是否显示注册按钮
    /// - Returns: true 如果显示注册按钮
    var isDisplayingRegisterButton: Bool {
        return app.buttons["profile.register.button"].waitForExistence(timeout: 2)
            || app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 2)
    }

    // MARK: - Navigation Methods

    /// 点击登录按钮，进入登录页面
    /// - Returns: LoginPage 实例
    /// - Precondition: 用户未登录状态
    func tapLogin() -> LoginPage {
        let loginButton = app.buttons["profile.login.button"]
        if loginButton.waitForExistence(timeout: 5) {
            loginButton.tap()
            XCTAssertTrue(
                app.navigationBars["登录账号"].waitForExistence(timeout: 10),
                "点击登录后未进入登录页面"
            )
            return LoginPage(app: app)
        }

        XCTAssertTrue(
            app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 10),
            "未找到登录入口（profile.login.button / sms.inline.phone.field）"
        )

        return LoginPage(app: app)
    }

    /// 点击退出登录按钮
    /// - Returns: ProfilePage 实例（刷新后的页面状态）
    /// - Precondition: 用户已登录状态
    func tapLogout() -> ProfilePage {
        let logoutButton = app.buttons["profile.logout.button"]
        XCTAssertTrue(
            logoutButton.waitForExistence(timeout: 10),
            "未找到退出登录按钮: profile.logout.button"
        )
        logoutButton.tap()

        let loggedOut = UITestSync.waitUntil(timeout: 8) {
            app.buttons["profile.register.button"].exists
                || app.buttons["profile.login.button"].exists
                || app.textFields["sms.inline.phone.field"].exists
        }
        XCTAssertTrue(loggedOut, "退出登录后应显示未登录态入口")

        return ProfilePage(app: app)
    }

    /// 点击注册按钮，进入注册页面
    /// - Returns: RegistrationPage 实例
    /// - Precondition: 用户未登录状态
    func tapRegister() -> RegistrationPage {
        let registerButton = app.buttons["profile.register.button"]
        if registerButton.waitForExistence(timeout: 5) {
            registerButton.tap()

            XCTAssertTrue(
                app.navigationBars["注册"].waitForExistence(timeout: 10),
                "点击注册后未进入注册页面"
            )

            let phoneField = app.textFields["register.phone.field"]
            XCTAssertTrue(
                phoneField.waitForExistence(timeout: 10),
                "注册页面未显示手机号输入框"
            )

            return RegistrationPage(app: app, currentStep: 1, entryMode: .registrationFlow)
        }

        XCTAssertTrue(
            app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 10),
            "未找到注册入口（profile.register.button / sms.inline.phone.field）"
        )
        return RegistrationPage(app: app, currentStep: 1, entryMode: .inlineSMS)
    }

    // MARK: - Info Methods

    /// 获取当前穿贝余额
    /// - Returns: 余额数值（整数）
    /// - Note: 从 balance label 的文本中提取数字
    func getBalance() -> Int {
        let balanceLabel = app.staticTexts["profile.balance.label"]
        XCTAssertTrue(
            balanceLabel.waitForExistence(timeout: 10),
            "未找到余额标签: profile.balance.label"
        )

        let balanceText = balanceLabel.label

        // 支持 "1000" 与 "1,000" 两种展示格式，取最后一个数字片段作为余额
        let pattern = "\\d[\\d,]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            XCTFail("余额正则初始化失败")
            return 0
        }
        let matches = regex.matches(
            in: balanceText,
            range: NSRange(location: 0, length: balanceText.utf16.count)
        )
        guard let match = matches.last else {
            XCTFail("无法从余额文本中提取数字: \(balanceText)")
            return 0
        }

        if let range = Range(match.range, in: balanceText) {
            let numberString = String(balanceText[range]).replacingOccurrences(of: ",", with: "")
            return Int(numberString) ?? 0
        }

        return 0
    }

    /// 获取当前用户昵称
    /// - Returns: 用户昵称文本
    func getNickname() -> String {
        // 昵称显示在用户信息区域，通过静态文本查找
        // 由于昵称是动态的，我们通过检查 profile.row.nickname 行来获取
        let nicknameRow = app.buttons["profile.row.nickname"]
        XCTAssertTrue(
            nicknameRow.waitForExistence(timeout: 10),
            "未找到昵称行"
        )

        // 返回行的标签文本
        return nicknameRow.label
    }

    // MARK: - Action Methods

    /// 点击充值按钮
    /// - Note: 打开充值页面
    func tapRecharge() {
        let rechargeButton = app.buttons["profile.recharge.button"]
        XCTAssertTrue(
            rechargeButton.waitForExistence(timeout: 10),
            "未找到充值按钮: profile.recharge.button"
        )
        rechargeButton.tap()

        // 验证充值页面打开
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "充值")
        let title = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "点击充值后未显示充值页面"
        )
    }

    /// 点击编辑昵称
    /// - Note: 打开昵称编辑页面
    func tapEditNickname() {
        let nicknameRow = app.buttons["profile.row.nickname"]
        XCTAssertTrue(
            nicknameRow.waitForExistence(timeout: 10),
            "未找到昵称编辑行: profile.row.nickname"
        )
        nicknameRow.tap()

        // 验证编辑页面打开
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "昵称")
        let title = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "点击昵称行后未进入编辑页面"
        )
    }

    /// 点击头像
    /// - Note: 打开头像选择器或操作表
    func tapAvatar() {
        let avatarButton = app.buttons["profile.avatar.button"]
        XCTAssertTrue(
            avatarButton.waitForExistence(timeout: 10),
            "未找到头像按钮: profile.avatar.button"
        )
        avatarButton.tap()

        // 等待照片选择器或操作表出现
        let photoPicker = app.otherElements["PhotosPicker"]
        let actionSheet = app.sheets.firstMatch

        let pickerExists = photoPicker.waitForExistence(timeout: 5)
        let sheetExists = actionSheet.waitForExistence(timeout: 5)

        XCTAssertTrue(
            pickerExists || sheetExists,
            "点击头像后未打开照片选择器或操作表"
        )
    }

    /// 点击切换账号
    /// - Note: 打开账号切换器
    func tapSwitchAccount() {
        let switchButton = app.buttons["profile.switch.account"]
        XCTAssertTrue(
            switchButton.waitForExistence(timeout: 10),
            "未找到切换账号按钮: profile.switch.account"
        )
        switchButton.tap()
    }

    /// 点击查看收支记录
    /// - Note: 打开钱包收支记录页面
    func tapWalletRecords() {
        let recordsButton = app.buttons["profile.wallet.records"]
        XCTAssertTrue(
            recordsButton.waitForExistence(timeout: 10),
            "未找到收支记录按钮: profile.wallet.records"
        )
        recordsButton.tap()

        // 验证记录页面打开
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "收支")
        let title = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "点击收支记录后未显示记录页面"
        )
    }

    // MARK: - Verification Methods

    /// 验证页面是否显示指定用户信息行
    /// - Parameter rowId: 用户信息的 accessibility identifier
    /// - Returns: true 如果该行存在
    func hasInfoRow(_ rowId: String) -> Bool {
        return app.descendants(matching: .any)[rowId].waitForExistence(timeout: 5)
    }

    /// 验证是否显示指定昵称
    /// - Parameter nickname: 期望显示的昵称
    /// - Returns: true 如果显示该昵称
    func isDisplayingNickname(_ nickname: String) -> Bool {
        let nicknameText = app.staticTexts[nickname]
        return nicknameText.waitForExistence(timeout: 5)
    }

    /// 读取指定信息行的可访问性文本
    /// - Parameter rowId: 信息行 accessibility identifier
    /// - Returns: 信息行文本
    func getInfoRowLabel(_ rowId: String) -> String {
        let row = app.descendants(matching: .any)[rowId]
        XCTAssertTrue(row.waitForExistence(timeout: 8), "未找到信息行: \(rowId)")
        return row.label
    }

    /// 验证收支记录列表首条是否匹配预期
    /// - Parameters:
    ///   - reasonKeyword: 原因关键字
    ///   - amountText: 金额文本（例如 +30）
    /// - Returns: true 表示首条记录匹配
    func firstWalletRecordMatches(reasonKeyword: String, amountText: String?) -> Bool {
        let firstCell = firstWalletRecordCell()
        guard firstCell.exists else { return false }
        guard containsText(reasonKeyword, in: firstCell) else { return false }
        return amountMatches(amountText, in: firstCell)
    }

    /// 关闭当前弹出的页面（钱包、收支记录等）
    func closePresentedViewIfNeeded() {
        let closeTitles = ["关闭", "完成", "知道了"]
        for title in closeTitles {
            let button = app.buttons[title]
            if button.waitForExistence(timeout: 1.5), button.isHittable {
                button.tap()
                return
            }
        }
        app.swipeDown()
    }

    private func firstWalletRecordCell() -> XCUIElement {
        let table = app.tables.firstMatch
        guard table.waitForExistence(timeout: 8) else {
            return app.cells["profile.wallet.missing"]
        }
        let firstCell = table.cells.element(boundBy: 0)
        _ = firstCell.waitForExistence(timeout: 8)
        return firstCell
    }

    private func containsText(_ keyword: String, in cell: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", keyword)
        return cell.staticTexts.matching(predicate).firstMatch.exists
    }

    private func amountMatches(_ amountText: String?, in cell: XCUIElement) -> Bool {
        guard let amountText else { return true }
        if cell.staticTexts[amountText].exists { return true }
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", amountText)
        return cell.staticTexts.matching(predicate).firstMatch.exists
    }
}
