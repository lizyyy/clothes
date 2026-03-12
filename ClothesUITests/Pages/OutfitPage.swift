// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 搭配页面封装
/// 提供搭配列表页面的元素访问和操作封装
/// 支持链式调用，返回 self 或新页面实例
struct OutfitPage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查是否显示空搭配状态
    /// - Returns: true 如果显示"还没有保存的穿搭"提示
    var isEmpty: Bool {
        return app.staticTexts["还没有保存的穿搭"].waitForExistence(timeout: 3)
    }

    /// 获取搭配数量
    /// - Returns: 搭配卡片数量
    var outfitCount: Int {
        // 通过识别搭配卡片中的标题文本或图片区域来计数
        let grid = app.scrollViews.firstMatch
        let cells = grid.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "outfit.cell"))
        return cells.count
    }

    /// 检查是否有搭配数据
    /// - Returns: true 如果存在搭配卡片
    var hasOutfits: Bool {
        let firstCell = app.otherElements["outfit.cell.0"]
        return firstCell.waitForExistence(timeout: 5)
    }

    // MARK: - Navigation Methods

    /// 导航到搭配标签页
    /// - Returns: OutfitPage 实例
    @discardableResult
    func goToOutfitTab() -> OutfitPage {
        let outfitTab = app.tabBars.buttons["搭配"]
        XCTAssertTrue(
            outfitTab.waitForExistence(timeout: 10),
            "未找到底部『搭配』Tab"
        )
        outfitTab.tap()

        // 验证页面加载完成
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "进入搭配页面后应显示页面标题"
        )

        return self
    }

    /// 点击添加穿搭按钮，进入创建搭配页面
    /// - Returns: CreateOutfitPage 实例
    func tapCreateOutfit() -> CreateOutfitPage {
        let addButton = app.buttons["outfits.add.button"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "未找到添加穿搭按钮: outfits.add.button"
        )
        addButton.tap()

        // 验证进入创建搭配页面
        XCTAssertTrue(
            app.navigationBars["搭配"].waitForExistence(timeout: 10),
            "点击添加穿搭后应进入创建搭配页面"
        )

        return CreateOutfitPage(app: app)
    }

    /// 点击指定索引的搭配卡片
    /// - Parameter index: 搭配卡片索引（从0开始）
    /// - Returns: CreateOutfitPage 实例（用于查看/编辑搭配详情）
    func tapOutfit(at index: Int) -> CreateOutfitPage {
        let cell = app.otherElements["outfit.cell.\(index)"]
        XCTAssertTrue(
            cell.waitForExistence(timeout: 10),
            "未找到索引为 \(index) 的搭配卡片"
        )
        cell.tap()

        // 验证进入搭配详情页
        XCTAssertTrue(
            app.navigationBars["搭配"].waitForExistence(timeout: 10),
            "点击搭配卡片后应进入搭配详情页"
        )

        return CreateOutfitPage(app: app)
    }

    /// 点击第一个搭配卡片
    /// - Returns: CreateOutfitPage 实例
    func tapFirstOutfit() -> CreateOutfitPage {
        return tapOutfit(at: 0)
    }

    /// 点击日历按钮，打开穿搭日历
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func tapCalendar() -> OutfitPage {
        let calendarButton = app.buttons["outfits.calendar.button"]
        XCTAssertTrue(
            calendarButton.waitForExistence(timeout: 10),
            "未找到日历按钮: outfits.calendar.button"
        )
        calendarButton.tap()

        // 验证日历页面打开
        XCTAssertTrue(
            app.navigationBars["穿搭日历"].waitForExistence(timeout: 10),
            "点击日历按钮后应打开穿搭日历"
        )

        return self
    }

    /// 点击回收站按钮
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func tapRecycleBin() -> OutfitPage {
        let recycleButton = app.buttons["outfits.recycle.button"]
        XCTAssertTrue(
            recycleButton.waitForExistence(timeout: 10),
            "未找到回收站按钮: outfits.recycle.button"
        )
        recycleButton.tap()

        // 验证回收站页面打开
        XCTAssertTrue(
            app.navigationBars["回收站"].waitForExistence(timeout: 10) ||
            app.staticTexts["回收站"].waitForExistence(timeout: 5),
            "点击回收站按钮后应打开回收站页面"
        )

        return self
    }

    // MARK: - Filter Methods

    /// 点击筛选按钮 - 全部
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func tapFilterAll() -> OutfitPage {
        let filterButton = app.buttons["outfits.filter.all"]
        XCTAssertTrue(
            filterButton.waitForExistence(timeout: 10),
            "未找到『全部』筛选按钮: outfits.filter.all"
        )
        filterButton.tap()
        return self
    }

    /// 点击筛选按钮 - 我的搭配
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func tapFilterManual() -> OutfitPage {
        let filterButton = app.buttons["outfits.filter.manual"]
        XCTAssertTrue(
            filterButton.waitForExistence(timeout: 10),
            "未找到『我的搭配』筛选按钮: outfits.filter.manual"
        )
        filterButton.tap()
        return self
    }

    /// 点击筛选按钮 - AI搭配
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func tapFilterAI() -> OutfitPage {
        let filterButton = app.buttons["outfits.filter.ai"]
        XCTAssertTrue(
            filterButton.waitForExistence(timeout: 10),
            "未找到『AI搭配』筛选按钮: outfits.filter.ai"
        )
        filterButton.tap()
        return self
    }

    // MARK: - Info Methods

    /// 获取指定索引搭配的标题
    /// - Parameter index: 搭配卡片索引
    /// - Returns: 搭配标题文本
    func getOutfitTitle(at index: Int) -> String {
        let titleLabel = app.staticTexts["outfit.title.\(index)"]
        XCTAssertTrue(
            titleLabel.waitForExistence(timeout: 5),
            "未找到索引为 \(index) 的搭配标题"
        )
        return titleLabel.label
    }

    /// 检查是否存在指定标题的搭配
    /// - Parameter title: 搭配标题
    /// - Returns: true 如果存在该搭配
    func hasOutfit(withTitle title: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", title)
        let titleLabel = app.staticTexts.matching(predicate).firstMatch
        return titleLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Calendar Methods

    /// 在日历中选择指定日期
    /// - Parameter day: 日期（1-31）
    /// - Returns: OutfitPage 实例（支持链式调用）
    @discardableResult
    func selectDateInCalendar(day: Int) -> OutfitPage {
        let dateButton = app.buttons["calendar.day.\(day)"]
        XCTAssertTrue(
            dateButton.waitForExistence(timeout: 5),
            "未找到日期 \(day) 的按钮"
        )
        dateButton.tap()
        return self
    }

    /// 关闭日历/回收站页面
    /// - Returns: OutfitPage 实例
    @discardableResult
    func closeSheet() -> OutfitPage {
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "未找到完成按钮"
        )
        doneButton.tap()

        // 验证返回搭配页面
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 5),
            "关闭页面后应返回搭配页面"
        )

        return self
    }
}
