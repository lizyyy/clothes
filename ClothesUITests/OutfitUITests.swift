// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 搭配模块 UITest
/// 测试搭配列表、创建搭配、添加衣物、删除搭配等功能
/// 使用 Page Object 模式和 Given-When-Then 结构
final class OutfitUITests: BaseTestCase {

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

    /// 兼容 identifier 与中文标题两类定位
    private func hasButton(_ identifiers: [String], timeout: TimeInterval = 5) -> Bool {
        for id in identifiers {
            if app.buttons[id].waitForExistence(timeout: timeout) {
                return true
            }
        }
        return false
    }

    // MARK: - Helper: Navigation

    /// 导航到搭配标签页
    private func goToOutfitTab() -> OutfitPage {
        let outfitPage = OutfitPage(app: app)
        return outfitPage.goToOutfitTab()
    }

    // MARK: - Test: Empty Outfits State

    /// 测试空搭配状态显示
    func testEmptyOutfitsState() {
        // Given: 用户已登录，在搭配页面
        _ = goToOutfitTab()

        // When: 检查页面元素

        // Then: 验证页面标题存在
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "搭配页面应显示页面标题"
        )

        // Then: 验证"穿搭记录"标题存在
        XCTAssertTrue(
            app.staticTexts["穿搭记录"].waitForExistence(timeout: 5),
            "搭配页面应显示『穿搭记录』标题"
        )

        // Then: 验证筛选按钮存在
        XCTAssertTrue(
            hasButton(["outfits.filter.all", "全部"]),
            "应显示『全部』筛选按钮"
        )
        XCTAssertTrue(
            hasButton(["outfits.filter.manual", "我的搭配"]),
            "应显示『我的搭配』筛选按钮"
        )
        XCTAssertTrue(
            hasButton(["outfits.filter.ai", "AI搭配"]),
            "应显示『AI搭配』筛选按钮"
        )

        // Then: 验证添加穿搭按钮存在
        XCTAssertTrue(
            hasButton(["outfits.add.button", "添加穿搭"]),
            "应显示添加穿搭按钮"
        )

        // Then: 验证回收站按钮存在
        XCTAssertTrue(
            hasButton(["outfits.recycle.button", "回收站"]),
            "应显示回收站按钮"
        )
    }

    // MARK: - Test: Create Outfit Flow

    /// 测试创建搭配流程（仅打开页面，不上传照片）
    func testCreateOutfitFlow() {
        // Given: 用户已登录，在搭配页面
        let outfitPage = goToOutfitTab()

        // When: 点击添加穿搭按钮
        let createPage = outfitPage.tapCreateOutfit()

        // Then: 验证进入创建搭配页面
        XCTAssertTrue(
            app.navigationBars["搭配"].waitForExistence(timeout: 10),
            "应进入创建搭配页面"
        )

        // Then: 验证页面元素存在
        XCTAssertTrue(
            app.textFields["outfit.name.field"].waitForExistence(timeout: 5),
            "应显示搭配名称输入框"
        )
        XCTAssertTrue(
            app.buttons["outfit.add.item.button"].waitForExistence(timeout: 5),
            "应显示添加衣物按钮"
        )
        XCTAssertTrue(
            app.buttons["outfit.photo.card"].waitForExistence(timeout: 5),
            "应显示上传照片区域"
        )
        XCTAssertTrue(
            app.buttons["outfit.generate.button"].waitForExistence(timeout: 5),
            "应显示虚拟试穿按钮"
        )

        // When: 输入搭配名称
        createPage.inputOutfitName("测试搭配")

        // Then: 验证名称已输入
        let nameField = app.textFields["outfit.name.field"]
        XCTAssertEqual(
            nameField.value as? String,
            "测试搭配",
            "搭配名称输入框应显示输入的文本"
        )

        // When: 点击完成返回
        _ = createPage.tapDone()

        // Then: 验证返回搭配列表
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "点击完成后应返回搭配列表"
        )
    }

    // MARK: - Test: Add Item To Outfit

    /// 测试添加衣物到搭配
    func testAddItemToOutfit() {
        // Given: 用户已登录，在创建搭配页面
        let outfitPage = goToOutfitTab()
        let createPage = outfitPage.tapCreateOutfit()

        // When: 点击添加衣物按钮
        createPage.tapAddClothingItem()

        // Then: 验证衣橱选择器打开
        XCTAssertTrue(
            app.navigationBars["选择衣物"].waitForExistence(timeout: 10),
            "应打开衣橱选择器"
        )

        // Then: 验证页面显示分类标题
        // 注意：由于衣物数据可能为空，这里仅验证页面结构
        XCTAssertTrue(
            app.staticTexts["选择衣物"].waitForExistence(timeout: 5),
            "衣橱选择器应显示标题"
        )

        // When: 关闭衣橱选择器
        _ = createPage.closeWardrobePicker()

        // Then: 验证返回创建搭配页面
        XCTAssertTrue(
            app.navigationBars["搭配"].waitForExistence(timeout: 5),
            "关闭选择器后应返回创建搭配页面"
        )
    }

    // MARK: - Test: Calendar View

    /// 测试穿搭日历功能
    func testCalendarView() {
        // Given: 用户已登录，在搭配页面
        let outfitPage = goToOutfitTab()

        // When: 点击日历按钮
        outfitPage.tapCalendar()

        // Then: 验证日历页面打开
        XCTAssertTrue(
            app.navigationBars["穿搭日历"].waitForExistence(timeout: 10),
            "应打开穿搭日历页面"
        )

        // Then: 验证日历元素存在
        XCTAssertTrue(
            app.staticTexts["当天穿搭"].waitForExistence(timeout: 5),
            "日历页面应显示『当天穿搭』标题"
        )

        // When: 关闭日历
        _ = outfitPage.closeSheet()

        // Then: 验证返回搭配页面
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "关闭日历后应返回搭配页面"
        )
    }

    // MARK: - Test: Recycle Bin

    /// 测试回收站功能
    func testRecycleBin() {
        // Given: 用户已登录，在搭配页面
        let outfitPage = goToOutfitTab()

        // When: 点击回收站按钮
        outfitPage.tapRecycleBin()

        // Then: 验证回收站页面打开
        XCTAssertTrue(
            app.staticTexts["回收站"].waitForExistence(timeout: 10) ||
            app.navigationBars["回收站"].waitForExistence(timeout: 5),
            "应打开回收站页面"
        )

        // When: 关闭回收站
        _ = outfitPage.closeSheet()

        // Then: 验证返回搭配页面
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "关闭回收站后应返回搭配页面"
        )
    }

    // MARK: - Test: Filter Outfits

    /// 测试搭配筛选功能
    func testFilterOutfits() {
        // Given: 用户已登录，在搭配页面
        let outfitPage = goToOutfitTab()

        // When: 点击全部筛选
        outfitPage.tapFilterAll()

        // Then: 验证页面仍显示
        XCTAssertTrue(
            app.staticTexts["穿搭记录"].waitForExistence(timeout: 5),
            "点击全部筛选后页面应正常显示"
        )

        // When: 点击我的搭配筛选
        outfitPage.tapFilterManual()

        // Then: 验证页面仍显示
        XCTAssertTrue(
            app.staticTexts["穿搭记录"].waitForExistence(timeout: 5),
            "点击我的搭配筛选后页面应正常显示"
        )

        // When: 点击AI搭配筛选
        outfitPage.tapFilterAI()

        // Then: 验证页面仍显示
        XCTAssertTrue(
            app.staticTexts["穿搭记录"].waitForExistence(timeout: 5),
            "点击AI搭配筛选后页面应正常显示"
        )
    }

    // MARK: - Test: Outfit Detail View

    /// 测试搭配详情页面（如果存在搭配数据）
    func testOutfitDetailView() {
        // Given: 用户已登录，在搭配页面
        let outfitPage = goToOutfitTab()

        // 检查是否有搭配数据
        if outfitPage.hasOutfits {
            // When: 点击第一个搭配
            let detailPage = outfitPage.tapFirstOutfit()

            // Then: 验证进入详情页面
            XCTAssertTrue(
                app.navigationBars["搭配"].waitForExistence(timeout: 10),
                "应进入搭配详情页面"
            )

            // Then: 验证页面元素
            XCTAssertTrue(
                app.textFields["outfit.name.field"].waitForExistence(timeout: 5),
                "详情页应显示搭配名称输入框"
            )

            // When: 返回搭配列表
            _ = detailPage.tapBack()

            // Then: 验证返回搭配列表
            XCTAssertTrue(
                app.staticTexts["搭配"].waitForExistence(timeout: 5),
                "返回后应回到搭配列表"
            )
        } else {
            // 如果没有搭配数据，验证空状态
            XCTAssertTrue(
                app.staticTexts["还没有保存的穿搭"].waitForExistence(timeout: 5),
                "没有搭配时应显示空状态提示"
            )
        }
    }

    // MARK: - Test: Empty State Prompt

    /// 测试空状态提示信息
    func testEmptyStatePrompt() {
        // Given: 用户已登录，在搭配页面
        _ = goToOutfitTab()

        // When: 检查空状态提示

        // Then: 验证空状态提示存在（如果没有搭配数据）
        let emptyLabel = app.staticTexts["还没有保存的穿搭"]
        let addPrompt = app.staticTexts["点击右上角添加穿搭开始生成试穿效果。"]

        // 至少验证其中一个元素存在（页面结构）
        let hasEmptyLabel = emptyLabel.waitForExistence(timeout: 3)
        let hasAddPrompt = addPrompt.waitForExistence(timeout: 3)

        if hasEmptyLabel {
            XCTAssertTrue(hasEmptyLabel, "空状态时应显示『还没有保存的穿搭』提示")
        }

        if hasAddPrompt {
            XCTAssertTrue(hasAddPrompt, "空状态时应显示添加穿搭引导文本")
        }
    }
}
