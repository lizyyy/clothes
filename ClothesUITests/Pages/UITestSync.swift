// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

enum UITestSync {

    static func clearAndType(_ field: XCUIElement, text: String) {
        field.tap()
        clearText(in: field)
        typeTextSlowly(field, text: text)
    }

    static func clearText(in field: XCUIElement) {
        guard let value = field.value as? String else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("Optional(") { return }
        let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        field.typeText(delete)
    }

    static func typeTextSlowly(_ field: XCUIElement, text: String) {
        for char in text {
            field.typeText(String(char))
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    static func waitUntil(timeout: TimeInterval, poll: TimeInterval = 0.2, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(poll))
        }
        return condition()
    }

    static func dismissKeyboardIfNeeded(app: XCUIApplication) {
        let done = app.buttons["完成"]
        if done.exists && done.isHittable {
            done.tap()
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
    }

    static func declineSavePasswordPromptIfNeeded(app: XCUIApplication, timeout: TimeInterval = 3) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyLabels = ["不保存", "否", "稍后", "以后", "取消", "Not Now", "Don't Save", "Don\u{2019}t Save", "Never"]

        _ = waitUntil(timeout: timeout) {
            for host in [app, springboard] {
                for label in denyLabels {
                    let button = host.buttons[label]
                    if button.exists && button.isHittable {
                        button.tap()
                        return true
                    }
                }
            }
            return false
        }
    }
}
