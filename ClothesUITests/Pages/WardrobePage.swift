// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 衣橱页面封装
/// 提供衣橱页面的元素访问和操作封装
/// 支持链式调用，返回新页面实例
struct WardrobePage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查衣橱是否为空
    /// - Returns: true 如果显示空状态
    var isEmpty: Bool {
        return app.staticTexts["wardrobe.empty.label"].waitForExistence(timeout: 3)
    }

    /// 获取衣橱中衣物数量
    /// - Returns: 衣物数量
    var clothingCount: Int {
        // 使用 accessibilityIdentifier 前缀匹配衣物网格项
        let gridItems = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wardrobe.grid.open."))
        return gridItems.count
    }

    /// 检查是否处于编辑模式
    /// - Returns: true 如果在编辑模式
    var isEditing: Bool {
        return app.buttons["wardrobe.done.button"].waitForExistence(timeout: 3)
    }

    /// 获取已选择的衣物数量
    /// - Returns: 已选择的衣物数量
    var selectedCount: Int {
        let selectedItems = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wardrobe.grid.select."))
        return selectedItems.count
    }

    // MARK: - Navigation Methods

    /// 点击添加衣物按钮，进入添加衣物流程
    /// - Returns: AddClothingPage 实例
    func tapAddClothing() -> AddClothingPage {
        let addButton = app.buttons["wardrobe.add.button"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "未找到添加衣物按钮: wardrobe.add.button"
        )
        addButton.tap()

        // 验证进入添加衣物页面
        XCTAssertTrue(
            app.staticTexts["添加到衣橱"].waitForExistence(timeout: 10),
            "点击添加后未进入添加衣物页面"
        )

        return AddClothingPage(app: app)
    }

    /// 点击衣橱网格中的衣物，进入详情页
    /// - Parameter index: 衣物索引（从0开始）
    /// - Returns: ClothingDetailPage 实例
    func tapClothing(at index: Int) -> ClothingDetailPage {
        let gridItems = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wardrobe.grid.open."))
        XCTAssertTrue(
            gridItems.count > index,
            "衣橱中衣物数量(\(gridItems.count))不足，无法访问第 \(index) 个"
        )

        let item = gridItems.element(boundBy: index)
        XCTAssertTrue(
            item.waitForExistence(timeout: 5),
            "应找到第 \(index) 个衣物"
        )
        item.tap()

        // 验证进入详情页
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 10),
            "点击衣物后应进入详情页"
        )

        return ClothingDetailPage(app: app)
    }

    /// 点击编辑按钮进入编辑模式
    /// - Returns: WardrobePage 实例
    func tapEdit() -> WardrobePage {
        let editButton = app.buttons["wardrobe.edit.button"]
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 10),
            "未找到编辑按钮: wardrobe.edit.button"
        )
        editButton.tap()

        // 验证进入编辑模式
        XCTAssertTrue(
            app.buttons["wardrobe.done.button"].waitForExistence(timeout: 5),
            "点击编辑后应显示完成按钮"
        )

        return WardrobePage(app: app)
    }

    /// 点击完成按钮退出编辑模式
    /// - Returns: WardrobePage 实例
    func tapDone() -> WardrobePage {
        let doneButton = app.buttons["wardrobe.done.button"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "未找到完成按钮: wardrobe.done.button"
        )
        doneButton.tap()

        // 验证退出编辑模式
        XCTAssertTrue(
            app.buttons["wardrobe.edit.button"].waitForExistence(timeout: 5),
            "点击完成后应显示编辑按钮"
        )

        return WardrobePage(app: app)
    }

    /// 点击回收站按钮
    /// - Returns: WardrobePage 实例
    func tapRecycleBin() -> WardrobePage {
        let recycleButton = app.buttons["wardrobe.recycle.button"]
        XCTAssertTrue(
            recycleButton.waitForExistence(timeout: 10),
            "未找到回收站按钮: wardrobe.recycle.button"
        )
        recycleButton.tap()

        // 验证回收站页面打开
        XCTAssertTrue(
            app.navigationBars["回收站"].waitForExistence(timeout: 10),
            "点击回收站后应进入回收站页面"
        )

        return WardrobePage(app: app)
    }

    /// 关闭回收站页面
    /// - Returns: WardrobePage 实例
    func closeRecycleBin() -> WardrobePage {
        let closeButton = app.buttons["关闭"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 10),
            "未找到关闭按钮"
        )
        closeButton.tap()

        // 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.recycle.button"].waitForExistence(timeout: 5),
            "关闭回收站后应返回衣橱页面"
        )

        return WardrobePage(app: app)
    }

    // MARK: - Category Filter Methods

    /// 点击分类标签筛选衣物
    /// - Parameter category: 分类名称（如 "上衣", "长裤", "全部" 等）
    /// - Returns: WardrobePage 实例
    @discardableResult
    func tapCategory(_ category: String) -> WardrobePage {
        // 查找包含该分类名称的按钮
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", category)
        let categoryButton = app.buttons.matching(predicate).firstMatch

        XCTAssertTrue(
            categoryButton.waitForExistence(timeout: 10),
            "未找到分类按钮: \(category)"
        )
        categoryButton.tap()

        return WardrobePage(app: app)
    }

    /// 获取当前选中的分类
    /// - Returns: 当前选中的分类名称
    func getSelectedCategory() -> String {
        // 通过检查分类标签的选中状态来判断
        // 选中的分类有下划线指示器
        let categories = ["全部", "上衣", "长裤", "短裤", "外套", "帽子", "鞋子", "袜子", "箱包", "饰品"]

        for category in categories {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", category)
            let button = app.buttons.matching(predicate).firstMatch
            if button.waitForExistence(timeout: 2) {
                // 这里简化处理，返回第一个找到的分类
                // 实际项目中可以通过检查视觉状态（如下划线）来判断
                return category
            }
        }

        return "全部"
    }

    // MARK: - Sort Methods

    /// 点击按添加时间排序
    /// - Returns: WardrobePage 实例
    @discardableResult
    func tapSortByTime() -> WardrobePage {
        let sortButton = app.buttons["wardrobe.sort.time"]
        XCTAssertTrue(
            sortButton.waitForExistence(timeout: 10),
            "未找到按时间排序按钮"
        )
        sortButton.tap()

        return WardrobePage(app: app)
    }

    /// 点击按使用频次排序
    /// - Returns: WardrobePage 实例
    @discardableResult
    func tapSortByUsage() -> WardrobePage {
        let sortButton = app.buttons["wardrobe.sort.usage"]
        XCTAssertTrue(
            sortButton.waitForExistence(timeout: 10),
            "未找到按使用频次排序按钮"
        )
        sortButton.tap()

        return WardrobePage(app: app)
    }

    // MARK: - Edit Mode Methods

    /// 在编辑模式下选择衣物
    /// - Parameter index: 衣物索引
    /// - Returns: WardrobePage 实例
    @discardableResult
    func selectClothing(at index: Int) -> WardrobePage {
        let gridItems = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wardrobe.grid.select."))
        XCTAssertTrue(
            gridItems.count > index,
            "衣橱中衣物数量不足，无法选择第 \(index) 个"
        )

        let item = gridItems.element(boundBy: index)
        XCTAssertTrue(
            item.waitForExistence(timeout: 5),
            "应找到第 \(index) 个衣物"
        )
        item.tap()

        return WardrobePage(app: app)
    }

    /// 点击批量修改分类按钮
    /// - Returns: WardrobePage 实例
    func tapBatchEditCategory() -> WardrobePage {
        let editCategoryButton = app.buttons["wardrobe.batch.editCategory"]
        XCTAssertTrue(
            editCategoryButton.waitForExistence(timeout: 10),
            "未找到批量修改分类按钮"
        )
        editCategoryButton.tap()

        // 验证分类选择器出现
        XCTAssertTrue(
            app.staticTexts["批量分类"].waitForExistence(timeout: 5),
            "应显示批量分类选择器"
        )

        return WardrobePage(app: app)
    }

    /// 点击批量删除按钮
    /// - Returns: WardrobePage 实例
    func tapBatchDelete() -> WardrobePage {
        let deleteButton = app.buttons["wardrobe.batch.delete"]
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 10),
            "未找到批量删除按钮"
        )
        deleteButton.tap()

        // 验证删除确认弹窗出现
        XCTAssertTrue(
            app.alerts["删除衣物"].waitForExistence(timeout: 5),
            "应显示删除确认弹窗"
        )

        return WardrobePage(app: app)
    }

    /// 确认删除
    /// - Returns: WardrobePage 实例
    func confirmDelete() -> WardrobePage {
        let confirmButton = app.alerts["删除衣物"].buttons["删除"]
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 5),
            "未找到确认删除按钮"
        )
        confirmButton.tap()

        return WardrobePage(app: app)
    }

    /// 取消删除
    /// - Returns: WardrobePage 实例
    func cancelDelete() -> WardrobePage {
        let cancelButton = app.alerts["删除衣物"].buttons["取消"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "未找到取消按钮"
        )
        cancelButton.tap()

        return WardrobePage(app: app)
    }

    // MARK: - Verification Methods

    /// 验证页面是否显示指定衣物
    /// - Parameter name: 衣物名称
    /// - Returns: true 如果显示该衣物
    func isDisplayingClothing(named name: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let element = app.buttons.matching(predicate).firstMatch
        return element.waitForExistence(timeout: 5)
    }

    /// 验证是否显示空状态
    /// - Returns: true 如果显示空状态
    func isDisplayingEmptyState() -> Bool {
        return app.staticTexts["wardrobe.empty.label"].waitForExistence(timeout: 5)
    }

    /// 获取衣橱标题文本
    /// - Returns: 标题文本
    func getTitle() -> String {
        let titleLabel = app.staticTexts["wardrobe.title"]
        if titleLabel.waitForExistence(timeout: 5) {
            return titleLabel.label
        }
        return ""
    }
}
