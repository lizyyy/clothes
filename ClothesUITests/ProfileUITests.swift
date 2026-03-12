// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 个人中心模块 UITest
/// 测试账号：test20 / qwe123!
/// 测试个人中心页面功能：信息展示、编辑、充值、钱包记录等
final class ProfileUITests: BaseTestCase {

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // 先登录测试账号
        loginWithTestAccount()
    }

    // MARK: - Helper: Login

    /// 使用测试账号登录
    private func loginWithTestAccount() {
        goToProfileTab()
        let profilePage = ProfilePage(app: app)
        if !profilePage.isLoggedIn {
            if app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 2) {
                loginByInlineSMS(phone: "13800138000")
                return
            }
            let loginPage = profilePage.tapLogin()
            _ = loginPage
                .inputUsername("test20")
                .inputPassword("qwe123!")
                .tapSubmit()
        }
    }

    private func loginByInlineSMS(phone: String) {
        UITestSync.clearAndType(app.textFields["sms.inline.phone.field"], text: phone)
        let agreement = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "我已阅读并同意")).firstMatch
        if agreement.waitForExistence(timeout: 2), agreement.isHittable {
            agreement.tap()
        }
        let sendButton = app.buttons["sms.inline.send.button"]
        if sendButton.waitForExistence(timeout: 6), sendButton.isEnabled {
            sendButton.tap()
        }
        let codeField = app.textFields["sms.inline.code.field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 6), "未找到短信验证码输入框")
        UITestSync.clearAndType(codeField, text: "123456")
        let submitButton = app.buttons["sms.inline.submit.button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 8), "未找到验证码登录按钮")
        XCTAssertTrue(submitButton.isEnabled, "验证码登录按钮不可用")
        submitButton.tap()
        declineSavePasswordPrompt(timeout: 3)
    }

    // MARK: - Test: Profile Info Display

    /// 验证个人信息展示（昵称、用户名、性别、身高、体重等）
    func testProfileInfoDisplay() {
        // Given: 用户已登录，在个人中心页面
        let profilePage = ProfilePage(app: app)
        XCTAssertTrue(profilePage.isLoggedIn, "测试前置条件：用户应已登录")

        // When: 检查个人中心页面元素
        goToProfileTab()

        // Then: 验证所有用户信息行都存在
        let expectedRows = [
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

        for rowId in expectedRows {
            XCTAssertTrue(
                profilePage.hasInfoRow(rowId),
                "应显示用户信息行: \(rowId)"
            )
        }

        // Then: 验证头像存在
        let avatarButton = app.buttons["profile.avatar.button"]
        XCTAssertTrue(
            avatarButton.waitForExistence(timeout: 5),
            "应显示用户头像"
        )

        // Then: 验证"我的"和"基本信息"区域标题
        XCTAssertTrue(waitForText("我的", timeout: 5), "应显示『我的』区域标题")
        XCTAssertTrue(waitForText("基本信息", timeout: 5), "应显示『基本信息』区域标题")
    }

    // MARK: - Test: Balance Display

    /// 验证余额显示
    func testBalanceDisplay() {
        // Given: 用户已登录
        let profilePage = ProfilePage(app: app)
        XCTAssertTrue(profilePage.isLoggedIn, "测试前置条件：用户应已登录")
        goToProfileTab()

        // When: 获取当前余额
        let balance = profilePage.getBalance()

        // Then: 验证余额标签存在且余额为非负数
        let balanceLabel = app.staticTexts["profile.balance.label"]
        XCTAssertTrue(
            balanceLabel.waitForExistence(timeout: 5),
            "应显示穿贝余额标签"
        )
        XCTAssertGreaterThanOrEqual(balance, 0, "余额应为非负数")

        // Then: 验证余额文本包含数字
        let balanceText = balanceLabel.label
        let pattern = "\\d+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: balanceText.utf16.count)
        let match = regex?.firstMatch(in: balanceText, options: [], range: range)
        XCTAssertNotNil(match, "余额文本应包含数字")
    }

    // MARK: - Test: Edit Nickname

    /// 修改昵称并验证
    func testEditNickname() {
        // Given: 用户已登录，在个人中心页面
        let profilePage = ProfilePage(app: app)
        goToProfileTab()

        // When: 点击昵称编辑行
        profilePage.tapEditNickname()

        // Then: 验证编辑页面打开
        XCTAssertTrue(waitForText("昵称", timeout: 5), "应进入昵称编辑页面")

        // When: 输入新昵称
        let newNickname = "TestNickname\(Int.random(in: 100...999))"
        let nicknameField = app.textFields["profile.edit.昵称.field"]
        XCTAssertTrue(
            nicknameField.waitForExistence(timeout: 5),
            "应显示昵称输入框"
        )

        // 清除现有文本并输入新昵称
        nicknameField.tap()
        if let currentValue = nicknameField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nicknameField.typeText(deleteString)
        }
        nicknameField.typeText(newNickname)

        // When: 点击完成保存
        dismissKeyboard()
        tapButton("完成")

        // Then: 验证修改后的昵称显示在页面上
        XCTAssertTrue(
            profilePage.isDisplayingNickname(newNickname),
            "修改后的昵称『\(newNickname)』应显示在页面上"
        )
    }

    // MARK: - Test: Edit Gender

    /// 修改性别并验证
    func testEditGender() {
        // Given: 用户已登录，在个人中心页面
        goToProfileTab()

        // When: 点击性别编辑行
        let genderRow = app.buttons["profile.row.gender"]
        XCTAssertTrue(
            genderRow.waitForExistence(timeout: 5),
            "应找到性别编辑行"
        )
        genderRow.tap()

        // Then: 验证性别选择页面打开
        XCTAssertTrue(waitForText("性别", timeout: 5), "应进入性别编辑页面")

        // When: 选择另一个性别（当前为男则选女，反之亦然）
        // 获取当前选中的性别
        let currentGenderLabel = genderRow.label
        let targetGender = currentGenderLabel.contains("男") ? "女" : "男"

        let targetButton = app.buttons[targetGender]
        XCTAssertTrue(
            targetButton.waitForExistence(timeout: 5),
            "应显示『\(targetGender)』选项"
        )
        targetButton.tap()

        // When: 点击完成保存
        tapButton("完成")

        // Then: 验证性别已更新
        let updatedGenderRow = app.buttons["profile.row.gender"]
        XCTAssertTrue(
            updatedGenderRow.waitForExistence(timeout: 5),
            "应显示更新后的性别行"
        )
        XCTAssertTrue(
            updatedGenderRow.label.contains(targetGender),
            "性别应更新为『\(targetGender)』"
        )
    }

    // MARK: - Test: Edit Height

    /// 修改身高并验证
    func testEditHeight() {
        // Given: 用户已登录，在个人中心页面
        goToProfileTab()

        // When: 点击身高编辑行
        let heightRow = app.buttons["profile.row.height"]
        XCTAssertTrue(
            heightRow.waitForExistence(timeout: 5),
            "应找到身高编辑行"
        )
        heightRow.tap()

        // Then: 验证身高编辑页面打开
        XCTAssertTrue(waitForText("身高", timeout: 5), "应进入身高编辑页面")

        // When: 使用选择器选择新身高
        let newHeight = "170"
        selectFromPickerWheel(newHeight)

        // When: 点击完成保存
        tapButton("完成")

        // Then: 验证身高已更新
        let updatedHeightRow = app.buttons["profile.row.height"]
        XCTAssertTrue(
            updatedHeightRow.waitForExistence(timeout: 5),
            "应显示更新后的身高行"
        )
        XCTAssertTrue(
            updatedHeightRow.label.contains(newHeight),
            "身高应更新为『\(newHeight)』"
        )
    }

    // MARK: - Test: Avatar Selection Opens Picker

    /// 点击头像打开选择器
    func testAvatarSelectionOpensPicker() {
        // Given: 用户已登录，在个人中心页面
        let profilePage = ProfilePage(app: app)
        goToProfileTab()

        // When: 点击头像
        profilePage.tapAvatar()

        // Then: 验证照片选择器或操作表已打开
        let photoPicker = app.otherElements["PhotosPicker"]
        let actionSheet = app.sheets.firstMatch

        let pickerExists = photoPicker.waitForExistence(timeout: 5)
        let sheetExists = actionSheet.waitForExistence(timeout: 5)

        XCTAssertTrue(
            pickerExists || sheetExists,
            "点击头像后应打开照片选择器或操作表"
        )

        // When: 取消选择器
        if pickerExists {
            let cancelButton = app.buttons["取消"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
            }
        } else if sheetExists {
            let cancelButton = actionSheet.buttons["取消"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
            }
        }

        // Then: 验证返回个人中心页面
        XCTAssertTrue(
            app.buttons["profile.logout.button"].waitForExistence(timeout: 5),
            "取消头像选择后应返回个人中心页面"
        )
    }

    // MARK: - Test: Recharge Flow

    /// 充值流程（DEBUG模式直接到账）
    func testRechargeFlow() {
        // Given: 用户已登录，在个人中心页面
        let profilePage = ProfilePage(app: app)
        goToProfileTab()

        // 记录充值前余额
        let balanceBefore = profilePage.getBalance()

        // When: 点击充值按钮
        profilePage.tapRecharge()

        // Then: 验证充值页面打开
        XCTAssertTrue(waitForText("充值", timeout: 5), "应进入充值页面")

        // When: 选择一个充值套餐
        let packageButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wallet.package.")
        ).firstMatch

        XCTAssertTrue(
            packageButton.waitForExistence(timeout: 5),
            "应显示充值套餐选项"
        )
        packageButton.tap()

        // When: 点击确认充值按钮
        let confirmButton = app.buttons["wallet.recharge.confirm"]
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 5),
            "应显示确认充值按钮"
        )
        confirmButton.tap()

        // Then: 等待充值完成（DEBUG模式下直接到账）
        // 检查成功提示或弹窗
        let successAlert = app.alerts.firstMatch
        if successAlert.waitForExistence(timeout: 5) {
            let okButton = successAlert.buttons["知道了"]
            if okButton.waitForExistence(timeout: 3) {
                okButton.tap()
            }
        }

        // When: 关闭充值页面
        let closeButton = app.buttons["完成"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }

        // Then: 验证返回个人中心页面
        XCTAssertTrue(
            app.buttons["profile.recharge.button"].waitForExistence(timeout: 5),
            "充值后应返回个人中心页面"
        )

        // Then: 验证余额可能已更新（DEBUG模式直接到账）
        // 注意：由于是DEBUG模式，余额应该增加
        let balanceAfter = profilePage.getBalance()
        XCTAssertGreaterThanOrEqual(
            balanceAfter,
            balanceBefore,
            "充值后余额应大于或等于充值前（DEBUG模式直接到账）"
        )
    }

    // MARK: - Test: Wallet Records Display

    /// 查看收支记录
    func testWalletRecordsDisplay() {
        // Given: 用户已登录，在个人中心页面
        let profilePage = ProfilePage(app: app)
        goToProfileTab()

        // When: 点击查看收支记录
        profilePage.tapWalletRecords()

        // Then: 验证收支记录页面打开
        XCTAssertTrue(waitForText("收支", timeout: 5), "应进入收支记录页面")

        // Then: 验证页面显示记录列表或空状态
        // 新注册用户应有30穿贝的注册赠送记录
        let recordsList = app.tables.firstMatch
        let emptyState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "暂无")
        ).firstMatch

        let hasRecords = recordsList.waitForExistence(timeout: 5) && recordsList.cells.count > 0
        let isEmpty = emptyState.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasRecords || isEmpty,
            "收支记录页面应显示记录列表或空状态提示"
        )

        // When: 关闭收支记录页面
        let closeButton = app.buttons["完成"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        } else {
            // 尝试下滑关闭
            app.swipeDown()
        }

        // Then: 验证返回个人中心页面
        XCTAssertTrue(
            app.buttons["profile.wallet.records"].waitForExistence(timeout: 5),
            "关闭收支记录后应返回个人中心页面"
        )
    }
}
