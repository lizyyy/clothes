// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试基础层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// UITest 基类
/// 提供通用的应用启动、辅助方法和页面操作封装
/// 所有 UITest 类应继承此类
class BaseTestCase: XCTestCase {

    // MARK: - Properties

    /// 应用实例，所有测试使用此实例进行 UI 操作
    var app: XCUIApplication!

    /// 是否启用离线认证短路（默认开启，保证常规 UI 用例稳定）
    var useOfflineAuthShortcut: Bool { true }

    /// 额外启动参数（子类可覆盖以注入环境参数）
    var extraLaunchArguments: [String] { [] }

    // MARK: - Lifecycle

    /// 测试前的设置
    /// 配置应用启动参数并启动应用
    override func setUp() {
        super.setUp()

        // 测试失败时立即停止，避免级联错误
        continueAfterFailure = false

        // 初始化应用实例
        app = XCUIApplication()

        // 配置启动参数
        app.launchArguments = buildLaunchArguments()

        // 启动应用
        app.launch()
    }

    /// 测试后的清理
    /// 终止应用并释放资源
    override func tearDown() {
        // 终止应用
        app?.terminate()
        app = nil

        super.tearDown()
    }

    private func buildLaunchArguments() -> [String] {
        var arguments = ["-uiTesting", "-resetAuth", "-uiTesting-disable-animations"]
        if useOfflineAuthShortcut {
            arguments.append("-uiTesting-offline")
        }
        arguments.append(contentsOf: extraLaunchArguments)
        return arguments
    }

    // MARK: - Element Wait Methods

    /// 等待指定 accessibility identifier 的元素出现
    /// - Parameters:
    ///   - identifier: 元素的 accessibility identifier
    ///   - timeout: 超时时间（秒）
    /// - Returns: 找到的元素
    /// - Note: 使用 waitForExistence，严禁使用 sleep
    func waitForElement(_ identifier: String, timeout: TimeInterval = 10) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "等待元素超时: \(identifier)"
        )
        return element
    }

    /// 等待包含指定文本的元素出现
    /// - Parameters:
    ///   - text: 要查找的文本内容
    ///   - timeout: 超时时间（秒）
    /// - Returns: 是否找到文本
    /// - Note: 使用 waitForExistence，严禁使用 sleep
    @discardableResult
    func waitForText(_ text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let element = app.staticTexts.matching(predicate).firstMatch

        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            takeScreenshot(name: "wait-for-text-failed-\(text)")
            XCTFail("未找到包含文本『\(text)』的元素")
        }
        return exists
    }

    // MARK: - Action Methods

    /// 点击指定 accessibility identifier 的按钮
    /// - Parameter identifier: 按钮的 accessibility identifier
    /// - Note: 自动等待元素出现后再点击
    func tapButton(_ identifier: String) {
        let button = waitForElement(identifier, timeout: 10)
        XCTAssertTrue(button.isHittable, "按钮不可点击: \(identifier)")
        button.tap()
    }

    /// 在指定输入框中输入文本
    /// - Parameters:
    ///   - identifier: 输入框的 accessibility identifier
    ///   - text: 要输入的文本
    /// - Note: 自动等待元素出现、点击聚焦后输入
    func inputText(_ identifier: String, text: String) {
        let field = waitForElement(identifier, timeout: 10)
        field.tap()
        field.typeText(text)
    }

    /// 清除输入框内容并输入新文本
    /// - Parameters:
    ///   - identifier: 输入框的 accessibility identifier
    ///   - text: 要输入的新文本
    /// - Note: 先清除现有内容，再输入新文本
    func clearAndInputText(_ identifier: String, text: String) {
        let field = waitForElement(identifier, timeout: 10)
        field.tap()

        // 清除现有文本
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            field.typeText(deleteString)
        }

        field.typeText(text)
    }

    /// 关闭键盘
    /// - Note: 尝试点击"完成"按钮，如果不存在则点击屏幕空白处
    func dismissKeyboard() {
        let doneButton = app.buttons["完成"]
        if doneButton.exists && doneButton.isHittable {
            doneButton.tap()
        } else {
            // 点击屏幕左上角空白处关闭键盘
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        }
    }

    /// 从选择器轮盘中选择值
    /// - Parameters:
    ///   - value: 要选择的值
    ///   - timeout: 超时时间（秒）
    /// - Note: 适用于性别、身高、星座等选择
    func selectFromPickerWheel(_ value: String, timeout: TimeInterval = 10) {
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(
            wheel.waitForExistence(timeout: timeout),
            "未找到选择器轮盘"
        )
        wheel.adjust(toPickerWheelValue: value)
    }

    // MARK: - Screenshot Methods

    /// 截取屏幕截图并添加到测试报告
    /// - Parameter name: 截图名称
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Navigation Helpers

    /// 导航到"我的"标签页（个人中心）
    /// - Note: 点击底部 TabBar 的"设置"按钮
    func goToProfileTab() {
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(
            settingsTab.waitForExistence(timeout: 10),
            "找不到底部『设置』Tab"
        )
        settingsTab.tap()
    }

    // MARK: - System Alert Handlers

    /// 处理"保存密码"提示
    /// - Parameter timeout: 超时时间（秒）
    /// - Note: 自动点击"不保存"或"Not Now"等拒绝按钮
    func declineSavePasswordPrompt(timeout: TimeInterval = 3) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyLabels = ["不保存", "否", "稍后", "以后", "取消", "Not Now", "Don't Save", "Don\u{2019}t Save", "Never"]

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for host in [app, springboard] {
                guard let hostApp = host else { continue }
                for label in denyLabels {
                    let button = hostApp.buttons[label]
                    if button.exists && button.isHittable {
                        button.tap()
                        return
                    }
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    /// 处理系统弹窗（如权限请求）
    /// - Parameters:
    ///   - buttonLabel: 要点击的按钮文本
    ///   - timeout: 超时时间（秒）
    func handleSystemAlert(buttonLabel: String, timeout: TimeInterval = 5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let button = springboard.buttons[buttonLabel]

        if button.waitForExistence(timeout: timeout) {
            button.tap()
        }
    }
}
