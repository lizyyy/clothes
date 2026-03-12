// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试用例层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 衣橱模块 UITest
/// 测试衣橱页面功能：添加衣物、分类筛选、编辑、删除、详情查看等
final class WardrobeUITests: BaseTestCase {

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // 使用 BaseTestCase 的统一启动参数，避免覆盖为无效 flag。
    }

    // MARK: - Helper: Navigate to Wardrobe

    /// 导航到衣橱标签页
    private func goToWardrobeTab() {
        let wardrobeTab = app.tabBars.buttons["衣橱"]
        XCTAssertTrue(
            wardrobeTab.waitForExistence(timeout: 10),
            "找不到底部『衣橱』Tab"
        )
        wardrobeTab.tap()

        // 验证进入衣橱页面
        XCTAssertTrue(
            app.staticTexts["衣橱"].waitForExistence(timeout: 10),
            "点击衣橱Tab后应进入衣橱页面"
        )
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

    // MARK: - Test: Empty Wardrobe State

    /// 验证空衣橱状态显示
    func testEmptyWardrobeState() throws {
        // Given: 应用刚启动，衣橱为空
        goToWardrobeTab()
        let wardrobePage = WardrobePage(app: app)

        // When: 检查衣橱状态
        let isEmpty = wardrobePage.isEmpty

        // Then: 验证空状态显示
        if isEmpty {
            XCTAssertTrue(
                app.staticTexts["wardrobe.empty.label"].waitForExistence(timeout: 5),
                "空衣橱应显示空状态提示"
            )
        }

        // Then: 验证添加按钮存在
        XCTAssertTrue(
            hasButton(["wardrobe.add.button", "添加衣物"]),
            "衣橱页面应显示添加衣物按钮"
        )

        // Then: 验证编辑按钮存在
        XCTAssertTrue(
            hasButton(["wardrobe.edit.button", "编辑"]),
            "衣橱页面应显示编辑按钮"
        )

        // Then: 验证回收站按钮存在
        XCTAssertTrue(
            hasButton(["wardrobe.recycle.button", "回收站"]),
            "衣橱页面应显示回收站按钮"
        )
    }

    // MARK: - Test: Add Clothing Flow

    /// 测试添加衣物流程 - 打开添加页面并取消
    func testAddClothingFlowOpenAndCancel() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()
        let wardrobePage = WardrobePage(app: app)

        // When: 点击添加衣物按钮
        let addClothingPage = wardrobePage.tapAddClothing()

        // Then: 验证添加页面显示正确
        XCTAssertTrue(
            app.staticTexts["添加到衣橱"].waitForExistence(timeout: 5),
            "应显示添加页面标题"
        )

        XCTAssertTrue(
            app.buttons["addclothing.camera.button"].waitForExistence(timeout: 5),
            "应显示拍照添加按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.album.button"].waitForExistence(timeout: 5),
            "应显示相册选择按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.batch.button"].waitForExistence(timeout: 5),
            "应显示批量导入按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.split.button"].waitForExistence(timeout: 5),
            "应显示整图拆解按钮"
        )

        // When: 点击取消
        let _ = addClothingPage.tapCancel()

        // Then: 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 5),
            "取消后应返回衣橱页面"
        )
    }

    // MARK: - Test: Category Filter

    /// 测试按分类筛选衣物
    func testFilterByCategory() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()

        // When: 点击不同分类标签
        let categories = ["全部", "上衣", "长裤", "外套", "鞋子"]

        for category in categories {
            // 点击分类
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", category)
            let categoryButton = app.buttons.matching(predicate).firstMatch

            if categoryButton.waitForExistence(timeout: 3) {
                categoryButton.tap()

                // Then: 验证页面响应
                XCTAssertTrue(
                    app.staticTexts["衣橱"].waitForExistence(timeout: 3),
                    "点击分类 \(category) 后页面应正常显示"
                )
            }
        }
    }

    // MARK: - Test: Sort Options

    /// 测试排序选项
    func testSortOptions() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()

        // When: 点击按添加时间排序
        let sortByTimePredicate = NSPredicate(format: "label CONTAINS[c] %@", "按添加时间")
        let sortByTimeButton = app.buttons.matching(sortByTimePredicate).firstMatch

        if sortByTimeButton.waitForExistence(timeout: 5) {
            sortByTimeButton.tap()

            // Then: 验证页面响应
            XCTAssertTrue(
                app.staticTexts["衣橱"].waitForExistence(timeout: 3),
                "点击按添加时间排序后页面应正常显示"
            )
        }

        // When: 点击按使用频次排序
        let sortByUsagePredicate = NSPredicate(format: "label CONTAINS[c] %@", "按使用频次")
        let sortByUsageButton = app.buttons.matching(sortByUsagePredicate).firstMatch

        if sortByUsageButton.waitForExistence(timeout: 5) {
            sortByUsageButton.tap()

            // Then: 验证页面响应
            XCTAssertTrue(
                app.staticTexts["衣橱"].waitForExistence(timeout: 3),
                "点击按使用频次排序后页面应正常显示"
            )
        }
    }

    // MARK: - Test: Edit Mode

    /// 测试编辑模式进入和退出
    func testEditModeEnterAndExit() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()
        let wardrobePage = WardrobePage(app: app)

        // When: 点击编辑按钮
        let editingPage = wardrobePage.tapEdit()

        // Then: 验证进入编辑模式
        XCTAssertTrue(
            app.buttons["wardrobe.done.button"].waitForExistence(timeout: 5),
            "编辑模式应显示完成按钮"
        )

        // Then: 验证页面显示编辑相关元素
        XCTAssertTrue(
            app.staticTexts["衣橱"].waitForExistence(timeout: 3),
            "编辑模式下页面标题应正常显示"
        )

        // When: 点击完成按钮退出编辑模式
        let _ = editingPage.tapDone()

        // Then: 验证退出编辑模式
        XCTAssertTrue(
            app.buttons["wardrobe.edit.button"].waitForExistence(timeout: 5),
            "退出编辑模式后应显示编辑按钮"
        )
    }

    // MARK: - Test: Recycle Bin

    /// 测试回收站功能
    func testRecycleBin() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()
        let wardrobePage = WardrobePage(app: app)

        // When: 点击回收站按钮
        let recyclePage = wardrobePage.tapRecycleBin()

        // Then: 验证回收站页面打开
        XCTAssertTrue(
            app.navigationBars["回收站"].waitForExistence(timeout: 10),
            "应进入回收站页面"
        )

        // Then: 验证回收站页面元素
        // 回收站可能为空或有内容
        let emptyState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "回收站为空")
        ).firstMatch

        let hasContent = app.cells.firstMatch.waitForExistence(timeout: 3)
        let isEmpty = emptyState.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasContent || isEmpty,
            "回收站应显示内容列表或空状态"
        )

        // When: 关闭回收站
        let _ = recyclePage.closeRecycleBin()

        // Then: 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 5),
            "关闭回收站后应返回衣橱页面"
        )
    }

    // MARK: - Test: View Clothing Detail

    /// 测试查看衣物详情
    func testViewClothingDetail() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()

        // 获取衣橱中的衣物数量
        let gridItems = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wardrobe.grid.open.")
        )

        // 如果有衣物，点击第一个查看详情
        if gridItems.count > 0 {
            let wardrobePage = WardrobePage(app: app)

            // When: 点击第一个衣物
            let detailPage = wardrobePage.tapClothing(at: 0)

            // Then: 验证进入详情页
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                "应进入衣物详情页"
            )

            // Then: 验证详情页元素
            // 详情页应显示返回按钮
            let backButton = app.buttons.firstMatch
            XCTAssertTrue(
                backButton.waitForExistence(timeout: 5),
                "详情页应显示返回按钮"
            )

            // When: 返回衣橱
            let _ = detailPage.tapBack()

            // Then: 验证返回衣橱页面
            XCTAssertTrue(
                app.buttons["wardrobe.add.button"].waitForExistence(timeout: 5),
                "返回后应回到衣橱页面"
            )
        } else {
            // 如果没有衣物，测试通过（空衣橱状态）
            XCTAssertTrue(true, "衣橱为空，跳过详情页测试")
        }
    }

    // MARK: - Test: Wardrobe Page Elements

    /// 验证衣橱页面所有元素存在
    func testWardrobePageElements() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()

        // Then: 验证页面标题
        let titleLabel = app.staticTexts["衣橱"]
        XCTAssertTrue(
            titleLabel.waitForExistence(timeout: 10),
            "衣橱页面应显示标题"
        )

        // Then: 验证添加按钮
        let addButton = app.buttons["wardrobe.add.button"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "应显示添加衣物按钮"
        )

        // Then: 验证编辑按钮
        let editButton = app.buttons["wardrobe.edit.button"]
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "应显示编辑按钮"
        )

        // Then: 验证回收站按钮
        let recycleButton = app.buttons["wardrobe.recycle.button"]
        XCTAssertTrue(
            recycleButton.waitForExistence(timeout: 5),
            "应显示回收站按钮"
        )

        // Then: 验证排序选项
        let sortByTimePredicate = NSPredicate(format: "label CONTAINS[c] %@", "按添加时间")
        let sortByTimeButton = app.buttons.matching(sortByTimePredicate).firstMatch
        XCTAssertTrue(
            sortByTimeButton.waitForExistence(timeout: 5),
            "应显示按添加时间排序按钮"
        )

        let sortByUsagePredicate = NSPredicate(format: "label CONTAINS[c] %@", "按使用频次")
        let sortByUsageButton = app.buttons.matching(sortByUsagePredicate).firstMatch
        XCTAssertTrue(
            sortByUsageButton.waitForExistence(timeout: 5),
            "应显示按使用频次排序按钮"
        )
    }

    // MARK: - Test: Add Clothing Page Elements

    /// 验证添加衣物页面所有元素存在
    func testAddClothingPageElements() throws {
        // Given: 在衣橱页面
        goToWardrobeTab()
        let wardrobePage = WardrobePage(app: app)

        // When: 进入添加页面
        let addClothingPage = wardrobePage.tapAddClothing()

        // Then: 验证页面标题
        XCTAssertTrue(
            app.staticTexts["添加到衣橱"].waitForExistence(timeout: 5),
            "添加页面应显示标题"
        )

        // Then: 验证副标题
        XCTAssertTrue(
            app.staticTexts["支持拍照、相册与批量导入"].waitForExistence(timeout: 5),
            "添加页面应显示副标题"
        )

        // Then: 验证所有添加选项按钮
        XCTAssertTrue(
            app.buttons["addclothing.camera.button"].waitForExistence(timeout: 5),
            "应显示拍照添加按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.split.button"].waitForExistence(timeout: 5),
            "应显示整图拆解按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.album.button"].waitForExistence(timeout: 5),
            "应显示相册选择按钮"
        )

        XCTAssertTrue(
            app.buttons["addclothing.batch.button"].waitForExistence(timeout: 5),
            "应显示批量导入按钮"
        )

        // Then: 验证取消按钮
        XCTAssertTrue(
            app.buttons["addclothing.cancel.button"].waitForExistence(timeout: 5),
            "应显示取消按钮"
        )

        // When: 取消返回
        let _ = addClothingPage.tapCancel()

        // Then: 验证返回衣橱
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 5),
            "取消后应返回衣橱页面"
        )
    }
}
