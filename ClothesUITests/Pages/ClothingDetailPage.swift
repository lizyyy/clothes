// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 衣物详情页面封装
/// 提供衣物详情页面的元素访问和操作封装
struct ClothingDetailPage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查是否在详情页面
    var isOnDetailPage: Bool {
        return app.navigationBars["我的服饰详情"].waitForExistence(timeout: 3)
    }

    /// 获取衣物名称
    var clothingName: String {
        // 从页面文本中查找衣物名称
        let namePredicate = NSPredicate(format: "label CONTAINS[c] %@", "名称")
        let nameLabel = app.staticTexts.matching(namePredicate).firstMatch
        if nameLabel.waitForExistence(timeout: 5) {
            return nameLabel.label
        }
        return ""
    }

    /// 获取衣物分类
    var clothingCategory: String {
        let categoryPredicate = NSPredicate(format: "label CONTAINS[c] %@", "品类")
        let categoryLabel = app.staticTexts.matching(categoryPredicate).firstMatch
        if categoryLabel.waitForExistence(timeout: 5) {
            return categoryLabel.label
        }
        return ""
    }

    // MARK: - Navigation Methods

    /// 点击完成按钮，返回衣橱页面
    /// - Returns: WardrobePage 实例
    func tapDone() -> WardrobePage {
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "未找到完成按钮"
        )
        doneButton.tap()

        // 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 10),
            "返回后应回到衣橱页面"
        )

        return WardrobePage(app: app)
    }

    /// 点击返回按钮，返回衣橱页面
    /// - Returns: WardrobePage 实例
    func tapBack() -> WardrobePage {
        // 尝试找到导航栏返回按钮
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "未找到返回按钮"
        )
        backButton.tap()

        // 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 10),
            "返回后应回到衣橱页面"
        )

        return WardrobePage(app: app)
    }

    // MARK: - Tab Methods

    /// 切换到信息标签
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapInfoTab() -> ClothingDetailPage {
        let infoTab = app.buttons["信息"]
        XCTAssertTrue(
            infoTab.waitForExistence(timeout: 10),
            "未找到信息标签"
        )
        infoTab.tap()

        return ClothingDetailPage(app: app)
    }

    /// 切换到穿搭方案标签
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapOutfitTab() -> ClothingDetailPage {
        let outfitTab = app.buttons["穿搭方案"]
        XCTAssertTrue(
            outfitTab.waitForExistence(timeout: 10),
            "未找到穿搭方案标签"
        )
        outfitTab.tap()

        return ClothingDetailPage(app: app)
    }

    // MARK: - Edit Methods

    /// 点击品类行进行编辑
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapCategoryRow() -> ClothingDetailPage {
        let categoryPredicate = NSPredicate(format: "label CONTAINS[c] %@", "品类")
        let categoryRow = app.buttons.matching(categoryPredicate).firstMatch

        XCTAssertTrue(
            categoryRow.waitForExistence(timeout: 10),
            "未找到品类选择行"
        )
        categoryRow.tap()

        // 验证选择器出现
        XCTAssertTrue(
            app.staticTexts["选择品类"].waitForExistence(timeout: 5),
            "应显示品类选择器"
        )

        return ClothingDetailPage(app: app)
    }

    /// 点击季节行进行编辑
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapSeasonRow() -> ClothingDetailPage {
        let seasonPredicate = NSPredicate(format: "label CONTAINS[c] %@", "季节")
        let seasonRow = app.buttons.matching(seasonPredicate).firstMatch

        XCTAssertTrue(
            seasonRow.waitForExistence(timeout: 10),
            "未找到季节选择行"
        )
        seasonRow.tap()

        // 验证选择器出现
        XCTAssertTrue(
            app.staticTexts["选择季节"].waitForExistence(timeout: 5),
            "应显示季节选择器"
        )

        return ClothingDetailPage(app: app)
    }

    /// 点击适用场景行进行编辑
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapOccasionRow() -> ClothingDetailPage {
        let occasionPredicate = NSPredicate(format: "label CONTAINS[c] %@", "适用场景")
        let occasionRow = app.buttons.matching(occasionPredicate).firstMatch

        XCTAssertTrue(
            occasionRow.waitForExistence(timeout: 10),
            "未找到适用场景选择行"
        )
        occasionRow.tap()

        // 验证选择器出现
        XCTAssertTrue(
            app.staticTexts["选择适用场景"].waitForExistence(timeout: 5),
            "应显示适用场景选择器"
        )

        return ClothingDetailPage(app: app)
    }

    /// 从选择器中选择值
    /// - Parameter value: 要选择的值
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func selectFromPicker(_ value: String) -> ClothingDetailPage {
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(
            wheel.waitForExistence(timeout: 10),
            "未找到选择器轮盘"
        )
        wheel.adjust(toPickerWheelValue: value)

        // 点击完成
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "未找到完成按钮"
        )
        doneButton.tap()

        return ClothingDetailPage(app: app)
    }

    // MARK: - Photo Methods

    /// 点击图片预览
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func tapPhoto() -> ClothingDetailPage {
        let photoImage = app.images.firstMatch
        XCTAssertTrue(
            photoImage.waitForExistence(timeout: 10),
            "未找到衣物图片"
        )
        photoImage.tap()

        return ClothingDetailPage(app: app)
    }

    /// 关闭图片预览
    /// - Returns: ClothingDetailPage 实例
    @discardableResult
    func closePhotoPreview() -> ClothingDetailPage {
        // 通常点击屏幕或找到关闭按钮
        let closeButton = app.buttons["关闭"]
        if closeButton.waitForExistence(timeout: 5) {
            closeButton.tap()
        } else {
            // 点击屏幕中央关闭
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        return ClothingDetailPage(app: app)
    }

    // MARK: - Verification Methods

    /// 验证是否显示指定分类
    /// - Parameter category: 期望的分类
    /// - Returns: true 如果显示该分类
    func isDisplayingCategory(_ category: String) -> Bool {
        let categoryPredicate = NSPredicate(format: "label CONTAINS[c] %@", category)
        let categoryLabel = app.staticTexts.matching(categoryPredicate).firstMatch
        return categoryLabel.waitForExistence(timeout: 5)
    }

    /// 验证是否显示图片
    /// - Returns: true 如果显示图片
    func isDisplayingImage() -> Bool {
        let photoSection = app.images.firstMatch
        return photoSection.waitForExistence(timeout: 5)
    }

    /// 验证是否在信息标签
    /// - Returns: true 如果在信息标签
    func isOnInfoTab() -> Bool {
        // 信息标签下应该显示"品类"行
        let categoryPredicate = NSPredicate(format: "label CONTAINS[c] %@", "品类")
        let categoryRow = app.buttons.matching(categoryPredicate).firstMatch
        return categoryRow.waitForExistence(timeout: 3)
    }

    /// 验证是否在穿搭方案标签
    /// - Returns: true 如果在穿搭方案标签
    func isOnOutfitTab() -> Bool {
        // 穿搭方案标签下应该显示穿搭相关内容
        let outfitPredicate = NSPredicate(format: "label CONTAINS[c] %@", "穿搭")
        let outfitLabel = app.staticTexts.matching(outfitPredicate).firstMatch
        return outfitLabel.waitForExistence(timeout: 3)
    }
}
