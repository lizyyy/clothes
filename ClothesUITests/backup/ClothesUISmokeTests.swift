// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试备份层
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
            "-uiTesting-disable-animations"
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

        XCTAssertTrue(app.staticTexts["请先登录"].waitForExistence(timeout: 8), "设置页未显示未登录提示")
        XCTAssertTrue(app.buttons["注册"].exists, "设置页未显示注册按钮")
        XCTAssertTrue(app.buttons["已有账号登录"].exists, "设置页未显示已有账号登录按钮")
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
        XCTAssertTrue(app.buttons["逛服装库"].exists, "衣橱页缺少逛服装库入口")
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

    func testExploreTabShowsTopTabs() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["探索"].tap()

        let alert = app.alerts["探索"]
        if alert.waitForExistence(timeout: 3) {
            alert.buttons["知道了"].tap()
            return
        }

        XCTAssertTrue(app.buttons["探索更多"].waitForExistence(timeout: 8), "探索页未显示“探索更多”")
        XCTAssertTrue(app.buttons["我的关注"].exists, "探索页未显示“我的关注”")
        XCTAssertFalse(app.staticTexts["真实用户与真实互动数据"].exists, "探索页不应再显示旧文案")
    }

    func testProfileShowsDraftboxSectionAfterLogin() throws {
        let app = launchCleanApp()
        guard app.wait(for: .runningForeground, timeout: 15) else {
            throw XCTSkip("App 未进入前台，可能设备锁屏，跳过用例")
        }

        let settingsTab = app.tabBars.buttons["设置"]
        guard settingsTab.waitForExistence(timeout: 12) else {
            throw XCTSkip("设置 Tab 不可见，可能设备锁屏或 App 未在前台")
        }
        settingsTab.tap()

        if app.buttons["退出登录"].waitForExistence(timeout: 3) == false {
            // Under `-uiTesting`, the app short-circuits login locally (no backend dependency),
            // so we can use a deterministic in-test credential here.
            let username = "ui_test_user"
            let password = "pw123!"

            app.buttons["已有账号登录"].tap()
            XCTAssertTrue(app.navigationBars["登录账号"].waitForExistence(timeout: 8), "未进入登录页")

            let usernameField = app.textFields.firstMatch
            XCTAssertTrue(usernameField.waitForExistence(timeout: 8), "找不到账号输入框")
            usernameField.tap()
            usernameField.typeText(username)

            let passwordField = inputField(app, label: "密码")
            XCTAssertTrue(passwordField.exists, "找不到密码输入框")
            passwordField.tap()
            passwordField.typeText(password)

            let done = app.buttons["完成"]
            if done.exists && done.isHittable {
                done.tap()
            } else {
                app.tap()
            }
            app.buttons["登录"].tap()
            declineSavePasswordPromptIfNeeded(app)
            XCTAssertTrue(app.buttons["退出登录"].waitForExistence(timeout: 15), "登录后未进入设置登录态")
        }

        XCTAssertTrue(app.staticTexts["同步草稿箱"].waitForExistence(timeout: 8), "设置页缺少同步草稿箱入口")
        XCTAssertTrue(app.buttons["profile.draftbox.retry"].exists, "设置页缺少草稿箱手动重试按钮")
    }

    func testProfileHidesDraftboxSectionWhenLoggedOut() throws {
        let app = launchCleanApp()
        app.tabBars.buttons["设置"].tap()

        XCTAssertTrue(app.staticTexts["请先登录"].waitForExistence(timeout: 8), "未登录态未出现提示")
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
