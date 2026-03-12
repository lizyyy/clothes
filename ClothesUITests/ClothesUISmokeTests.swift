// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

final class ClothesUISmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchCleanApp() -> XCUIApplication {
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

    private func inputField(_ app: XCUIApplication, label: String, timeout: TimeInterval = 8) -> XCUIElement {
        // Under `-uiTesting`, password inputs are rendered as TextField (not SecureField) for stability.
        // Still try secure first in case the UI changes.
        let secure = app.secureTextFields[label]
        if secure.waitForExistence(timeout: 0.8) {
            return secure
        }
        let text = app.textFields[label]
        _ = text.waitForExistence(timeout: timeout)
        return text
    }

    private func launchSeededTwoUsersApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTesting",
            "-uiTesting-clear-state",
            "-uiTesting-disable-animations",
            "-uiTesting-offline",
            "-uiTesting-seed-two-users"
        ]
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }

    func testTabBarContainsFiveMainTabs() throws {
        let app = launchCleanApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "未找到底部 TabBar")

        let expectedTabs = ["衣橱", "搭配", "AI场景搭配", "探索", "设置"]
        for title in expectedTabs {
            XCTAssertTrue(tabBar.buttons[title].exists, "Tab 缺失：\(title)")
        }
    }

    func testSettingsShowsRegisterAndLoginActionsWhenLoggedOut() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["设置"].tap()

        let hasLegacyEntry = app.staticTexts["请先登录"].waitForExistence(timeout: 4)
            && app.buttons["注册"].exists
            && app.buttons["已有账号登录"].exists
        let hasInlineSMS = app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 4)
            && app.textFields["sms.inline.code.field"].exists
            && app.buttons["sms.inline.submit.button"].exists

        XCTAssertTrue(hasLegacyEntry || hasInlineSMS, "设置页未显示可用的未登录入口（旧登录卡片或内联短信卡片）")
    }

    func testExploreTabAsGuestShowsLoginAlert() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["探索"].tap()

        let alert = app.alerts["探索"]
        XCTAssertTrue(alert.waitForExistence(timeout: 8), "未登录进入探索页时未出现提示")
        XCTAssertTrue(alert.staticTexts["请先登录后再查看探索页。"].exists, "提示文案不符合预期")
    }

    func testCreateTabShowsTwoCoreCards() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["AI场景搭配"].tap()

        XCTAssertTrue(app.navigationBars["AI场景搭配"].waitForExistence(timeout: 8), "未进入 AI 场景搭配页")
        XCTAssertTrue(app.staticTexts["DIY 穿搭"].waitForExistence(timeout: 8), "未显示 DIY 穿搭入口")
        XCTAssertTrue(app.staticTexts["AI 智能搭配"].waitForExistence(timeout: 8), "未显示 AI 智能搭配入口")
    }

    func testWardrobeTabShowsPrimaryActions() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["衣橱"].tap()

        XCTAssertTrue(app.staticTexts["衣橱"].waitForExistence(timeout: 8), "未进入衣橱页")
        XCTAssertTrue(app.buttons["添加衣物"].waitForExistence(timeout: 8), "衣橱页缺少添加衣物按钮")
        XCTAssertTrue(app.buttons["回收站"].exists, "衣橱页缺少回收站入口")
    }

    func testOutfitsTabShowsAddOutfitEntry() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["搭配"].tap()

        XCTAssertTrue(app.staticTexts["搭配"].waitForExistence(timeout: 8), "未进入搭配页")
        XCTAssertTrue(app.buttons["添加穿搭"].waitForExistence(timeout: 8), "搭配页缺少添加穿搭入口")
    }

    func testSwitchAccountShouldNotShowPreviousUsersWardrobeOrOutfits() throws {
        let app = launchSeededTwoUsersApp()

        // User A should see A data only.
        app.tabBars.buttons["衣橱"].tap()
        XCTAssertTrue(app.staticTexts["衣橱"].waitForExistence(timeout: 8), "未进入衣橱页")
        XCTAssertTrue(app.buttons["A_上衣"].waitForExistence(timeout: 8), "用户 A 未看到自己的衣物")
        XCTAssertFalse(app.buttons["B_上衣"].exists, "用户 A 不应看到用户 B 的衣物")

        app.tabBars.buttons["搭配"].tap()
        XCTAssertTrue(app.staticTexts["搭配"].waitForExistence(timeout: 8), "未进入搭配页")
        XCTAssertTrue(app.staticTexts["A_穿搭"].waitForExistence(timeout: 8), "用户 A 未看到自己的穿搭")
        XCTAssertFalse(app.staticTexts["B_穿搭"].exists, "用户 A 不应看到用户 B 的穿搭")

        // Switch to user B via account switcher UI.
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["切换账号"].waitForExistence(timeout: 8), "设置页缺少切换账号入口")
        app.buttons["切换账号"].tap()
        XCTAssertTrue(app.navigationBars["切换账号"].waitForExistence(timeout: 8), "未打开切换账号页")

        let bRow = app.buttons.containing(.staticText, identifier: "test0002").firstMatch
        XCTAssertTrue(bRow.waitForExistence(timeout: 8), "账号列表缺少 test0002")
        bRow.tap()

        // After switching, User B should see B data only.
        app.tabBars.buttons["衣橱"].tap()
        XCTAssertTrue(app.buttons["B_上衣"].waitForExistence(timeout: 8), "切换到用户 B 后未看到 B 的衣物")
        XCTAssertFalse(app.buttons["A_上衣"].exists, "切换到用户 B 后仍看到 A 的衣物")

        app.tabBars.buttons["搭配"].tap()
        XCTAssertTrue(app.staticTexts["B_穿搭"].waitForExistence(timeout: 8), "切换到用户 B 后未看到 B 的穿搭")
        XCTAssertFalse(app.staticTexts["A_穿搭"].exists, "切换到用户 B 后仍看到 A 的穿搭")
    }

    func testSwitchAccountListShowsNicknameAndLoginUsernameField() throws {
        let app = launchSeededTwoUsersApp()
        app.tabBars.buttons["设置"].tap()

        XCTAssertTrue(app.buttons["切换账号"].waitForExistence(timeout: 8), "设置页缺少切换账号入口")
        app.buttons["切换账号"].tap()
        XCTAssertTrue(app.navigationBars["切换账号"].waitForExistence(timeout: 8), "未打开切换账号页")

        let rowA = app.buttons["account.switch.test0001"]
        let rowB = app.buttons["account.switch.test0002"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 8), "账号列表缺少 test0001")
        XCTAssertTrue(rowB.waitForExistence(timeout: 8), "账号列表缺少 test0002")

        XCTAssertTrue(rowA.staticTexts["登录用户名（手机号）"].exists, "test0001 行应展示登录用户名字段标题")
        XCTAssertTrue(rowA.staticTexts["test0001"].exists, "test0001 行应展示登录用户名值")

        XCTAssertTrue(rowB.staticTexts["登录用户名（手机号）"].exists, "test0002 行应展示登录用户名字段标题")
        XCTAssertTrue(rowB.staticTexts["test0002"].exists, "test0002 行应展示登录用户名值")
    }

    func testExploreTabShowsTopTabs() throws {
        let app = launchSeededTwoUsersApp()
        app.tabBars.buttons["探索"].tap()

        XCTAssertTrue(app.buttons["我的关注"].waitForExistence(timeout: 8), "探索页缺少『我的关注』筛选")
        XCTAssertTrue(app.buttons["探索更多"].exists, "探索页缺少『探索更多』筛选")
    }

    func testExploreCreatorHomeAndDetailRespectLatestUIWhenFeedAvailable() throws {
        let app = launchSeededTwoUsersApp()
        app.tabBars.buttons["探索"].tap()
        XCTAssertTrue(app.buttons["探索更多"].waitForExistence(timeout: 8), "探索页缺少『探索更多』筛选")
        app.buttons["探索更多"].tap()

        let creatorButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "explore.creator.open.")
        ).firstMatch
        guard creatorButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("探索 feed 暂无可用分享数据，跳过他人主页链路校验")
        }
        creatorButton.tap()

        XCTAssertTrue(app.navigationBars["主页"].waitForExistence(timeout: 8), "未进入他人主页")
        XCTAssertFalse(app.staticTexts["登录用户名（手机号）"].exists, "他人主页不应展示登录用户名（手机号）文案")
        XCTAssertTrue(app.staticTexts["粉丝"].exists, "他人主页缺少粉丝指标")
        XCTAssertTrue(app.staticTexts["关注"].exists, "他人主页缺少关注指标")
        XCTAssertTrue(app.staticTexts["获赞"].exists, "他人主页缺少获赞指标")

        let outfitButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "explore.user.home.outfit.")
        ).firstMatch
        guard outfitButton.waitForExistence(timeout: 8) else {
            throw XCTSkip("他人主页暂无分享穿搭，跳过详情页验证")
        }
        outfitButton.tap()

        XCTAssertTrue(app.navigationBars["穿搭详情"].waitForExistence(timeout: 8), "未进入分享穿搭详情")
        XCTAssertTrue(app.staticTexts["评论区"].exists, "分享详情页应预留评论区")

        let mmddText = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-1][0-9][0-3][0-9]$")
        ).firstMatch
        XCTAssertTrue(mmddText.waitForExistence(timeout: 6), "详情页应展示 MMdd 时间码")
    }

    func testProfileDoesNotShowDraftboxSectionAfterLogin() throws {
        let app = launchSeededTwoUsersApp()
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["profile.logout.button"].waitForExistence(timeout: 10), "登录后未进入设置登录态")
        XCTAssertFalse(app.staticTexts["同步草稿箱"].exists, "登录态不应展示同步草稿箱入口")
        XCTAssertFalse(app.buttons["profile.draftbox.retry"].exists, "登录态不应展示草稿箱手动重试按钮")
    }

    func testProfileDoesNotShowDraftboxSectionWhenLoggedOut() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["设置"].tap()

        let hasLegacyEntry = app.staticTexts["请先登录"].waitForExistence(timeout: 4)
            || app.buttons["注册"].exists
            || app.buttons["已有账号登录"].exists
        let hasInlineSMS = app.textFields["sms.inline.phone.field"].waitForExistence(timeout: 4)
            || app.textFields["sms.inline.code.field"].exists
            || app.buttons["sms.inline.submit.button"].exists
        XCTAssertTrue(hasLegacyEntry || hasInlineSMS, "未登录态未展示可用登录入口")
        XCTAssertFalse(app.staticTexts["同步草稿箱"].exists, "未登录态不应展示同步草稿箱")
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
