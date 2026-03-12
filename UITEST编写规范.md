<!-- 文件input：XCTest 官方能力、UI Testing Best Practices、项目现有 UI 测试目录结构 -->
<!-- 文件output：可执行的 iOS UI Test 编写规范、模板、门禁与反模式清单 -->
<!-- 文件pos：clothes-ios 根目录 UI 自动化测试规范 -->
<!-- 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。 -->

# Clothes iOS UI Test 编写规范

## 1. 目标与范围

- 目标：保证 UI 测试稳定、可维护、可读、可并行执行。
- 范围：`clothes-ios/ClothesUITests` 下所有测试用例、页面对象、测试基类。
- 结论优先：UI 测试是“用户路径守门员”，不是替代单元测试。

## 2. 设计原则（强制）

- `P1 可重复`：同一提交、同一设备配置下，结果必须可重复。
- `P2 可定位`：失败日志必须能快速定位页面与步骤。
- `P3 可维护`：UI 细节封装在 Page Object，测试仅表达业务流程。
- `P4 可演进`：页面变更时，只改 Page Object，不批量改测试逻辑。

## 3. 目录与命名规范

- 目录分层：
  - `ClothesUITests/Base`：测试基类、公共启动与清理逻辑。
  - `ClothesUITests/Pages`：Page Object（一个页面一个对象）。
  - `ClothesUITests/*UITests.swift`：业务场景测试。
- 文件命名：
  - 页面对象：`<PageName>Page.swift`（如 `LoginPage.swift`）。
  - 测试文件：`<Domain>UITests.swift`（如 `AuthUITests.swift`）。
- 方法命名：
  - XCTest 测试方法必须以 `test` 开头。
  - 推荐格式：`test_<场景>_<期望>`，例如 `test_Login_WithValidCredentials_ShouldEnterWardrobe`。

## 4. Page Object 规范（强制）

- Page Object 只负责：
  - 查找元素（统一定位策略）。
  - 页面内动作（tap/type/scroll）。
  - 页面状态判定（`isVisible`、`isLoaded`）。
- 测试用例负责：
  - 业务流程编排。
  - 断言业务结果。
- 禁止在测试里直接写裸选择器（`app.buttons["xxx"]`）反复出现。
- 禁止 Page Object 知道跨页面业务流程（跨页面跳转由测试层组织）。

### 4.1 Page Object 模板

```swift
import XCTest

final class LoginPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var isLoaded: Bool {
        app.textFields["login.username"].waitForExistence(timeout: 5)
    }

    func enterUsername(_ value: String) {
        let field = app.textFields["login.username"]
        field.tap()
        field.typeText(value)
    }

    func enterPassword(_ value: String) {
        let field = app.secureTextFields["login.password"]
        field.tap()
        field.typeText(value)
    }

    func tapLogin() {
        app.buttons["login.submit"].tap()
    }
}
```

## 5. 元素定位规范（强制）

- 统一使用 `accessibilityIdentifier`，禁止依赖文案文本定位。
- Identifier 命名建议：`<模块>.<页面>.<元素>`，如 `auth.login.submit`。
- 每个可交互元素必须有稳定 identifier。
- UI 重构时，优先保持 identifier 不变，避免测试脆断。

## 6. 用例编写规范（强制）

- 一个测试只验证一个业务目标，不做“大而全”链路。
- 测试之间禁止依赖执行顺序。
- 每个测试必须独立准备数据与状态。
- 断言必须明确业务意图，避免仅断言“元素存在”。

### 6.1 推荐结构（AAA）

1. Arrange：启动 App + 准备账号/数据/环境。
2. Act：执行用户动作。
3. Assert：断言预期结果。

### 6.2 用例模板

```swift
import XCTest

final class AuthUITests: BaseTestCase {
    func test_Login_WithValidCredentials_ShouldEnterWardrobe() {
        let login = LoginPage(app: app)
        XCTAssertTrue(login.isLoaded, "登录页未加载完成")

        login.enterUsername("uitest_user")
        login.enterPassword("123456")
        login.tapLogin()

        let wardrobe = WardrobePage(app: app)
        XCTAssertTrue(wardrobe.isLoaded, "登录成功后应进入衣橱页")
    }
}
```

## 7. 异步与等待规范（强制）

- 禁止使用固定睡眠：`sleep()`、`usleep()`。
- 必须使用显式等待：
  - `waitForExistence(timeout:)`
  - `XCTNSPredicateExpectation`
  - `XCTWaiter`
- 超时值建议：
  - 本地：3~5 秒
  - CI：5~10 秒（允许轻微放宽）

## 8. 测试数据与环境规范

- UI 测试账号必须专用，禁止使用个人账号。
- 测试前后要可重置（幂等）。
- 依赖外部服务的场景，优先采用可控测试环境与可复用数据集。
- 用启动参数/环境变量控制测试模式（如跳过引导页、注入测试 token）。

## 9. 失败诊断规范

- 失败时必须输出步骤上下文（建议用 `XCTContext.runActivity` 分段）。
- 关键失败点截图（XCTest 自动截图 + 关键页面手动补充）。
- Page Object 的 `isLoaded` 失败要给明确错误信息（不是笼统 `XCTFail`）。

## 10. CI 门禁建议

- 提交门禁至少执行：
  - Smoke UI Tests（核心 3~5 条链路）
  - 关键路径回归（登录、衣橱、新增、搭配、个人中心）
- 稳定性目标：
  - 主干分支 UI Test 成功率 >= 95%
  - 单条用例连续 flaky 2 次必须修复或下线并登记

## 11. 禁止事项（红线）

- 禁止固定等待时间掩盖异步问题。
- 禁止在测试中硬编码一次性数据导致重复运行失败。
- 禁止跨测试共享可变状态。
- 禁止在一个测试里覆盖多个业务目标。
- 禁止在测试层直接散落 UI 选择器。

## 12. 与本项目现状对齐要求

- 现有 `ClothesUITests/Pages` 继续作为唯一 Page Object 入口。
- 新增页面必须先补 Page Object，再写测试用例。
- 改动页面结构时，必须同步更新：
  - 对应 Page Object
  - `ClothesUITests` 相关用例
  - 所属目录 `ARCH.md`

## 13. 参考文献

- UI Testing Best Practices: <https://github.com/NoriSte/ui-testing-best-practices>
- Apple XCTest Documentation: <https://developer.apple.com/documentation/xctest>
- Page Object Pattern: <https://martinfowler.com/bliki/PageObject.html>
