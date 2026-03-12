// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 创建/编辑搭配页面封装
/// 提供搭配创建和编辑页面的元素访问和操作封装
/// 支持链式调用，返回 self 或新页面实例
struct CreateOutfitPage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查是否正在生成中
    /// - Returns: true 如果显示生成中状态
    var isGenerating: Bool {
        return app.staticTexts["AI 正在生成效果图…"].waitForExistence(timeout: 3)
    }

    /// 检查是否已生成预览图
    /// - Returns: true 如果显示预览图
    var hasPreviewImage: Bool {
        // 通过检查是否存在预览区域的图片来判断
        let heroCard = app.otherElements["outfit.preview.hero"]
        return heroCard.waitForExistence(timeout: 5)
    }

    /// 检查是否已选择衣物
    /// - Returns: true 如果已选择至少一件衣物
    var hasSelectedItems: Bool {
        let itemTile = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "outfit.item.tile")).firstMatch
        return itemTile.waitForExistence(timeout: 3)
    }

    /// 获取已选衣物数量
    /// - Returns: 已选衣物数量
    var selectedItemCount: Int {
        let items = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "outfit.item.tile"))
        return items.count
    }

    // MARK: - Input Methods

    /// 输入搭配名称
    /// - Parameter name: 搭配名称
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func inputOutfitName(_ name: String) -> CreateOutfitPage {
        let nameField = app.textFields["outfit.name.field"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 10),
            "未找到搭配名称输入框: outfit.name.field"
        )

        nameField.tap()
        nameField.typeText(name)

        return self
    }

    /// 清除搭配名称
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func clearOutfitName() -> CreateOutfitPage {
        let nameField = app.textFields["outfit.name.field"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 10),
            "未找到搭配名称输入框"
        )

        nameField.tap()

        // 清除现有文本
        if let currentValue = nameField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nameField.typeText(deleteString)
        }

        return self
    }

    // MARK: - Wardrobe Selection Methods

    /// 点击添加衣物按钮，打开衣橱选择器
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapAddClothingItem() -> CreateOutfitPage {
        let addButton = app.buttons["outfit.add.item.button"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "未找到添加衣物按钮: outfit.add.item.button"
        )
        addButton.tap()

        // 验证衣橱选择器打开
        XCTAssertTrue(
            app.navigationBars["选择衣物"].waitForExistence(timeout: 10),
            "点击添加衣物后应打开衣橱选择器"
        )

        return self
    }

    /// 在衣橱选择器中选择指定索引的衣物
    /// - Parameter index: 衣物索引（从0开始）
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func selectWardrobeItem(at index: Int) -> CreateOutfitPage {
        let itemCard = app.buttons["wardrobe.select.card.\(index)"]
        XCTAssertTrue(
            itemCard.waitForExistence(timeout: 10),
            "未找到索引为 \(index) 的衣物卡片"
        )
        itemCard.tap()
        return self
    }

    /// 在衣橱选择器中选择第一个衣物
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func selectFirstWardrobeItem() -> CreateOutfitPage {
        return selectWardrobeItem(at: 0)
    }

    /// 关闭衣橱选择器
    /// - Returns: CreateOutfitPage 实例
    @discardableResult
    func closeWardrobePicker() -> CreateOutfitPage {
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "未找到完成按钮"
        )
        doneButton.tap()

        // 验证返回创建搭配页面
        XCTAssertTrue(
            app.navigationBars["搭配"].waitForExistence(timeout: 5),
            "关闭衣橱选择器后应返回创建搭配页面"
        )

        return self
    }

    /// 移除指定索引的已选衣物
    /// - Parameter index: 衣物索引（从0开始）
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func removeSelectedItem(at index: Int) -> CreateOutfitPage {
        let removeButton = app.buttons["outfit.item.remove.\(index)"]
        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 10),
            "未找到索引为 \(index) 的衣物移除按钮"
        )
        removeButton.tap()
        return self
    }

    // MARK: - Photo Methods

    /// 点击上传本人照片区域
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapAddPersonPhoto() -> CreateOutfitPage {
        let photoCard = app.buttons["outfit.photo.card"]
        XCTAssertTrue(
            photoCard.waitForExistence(timeout: 10),
            "未找到上传照片区域: outfit.photo.card"
        )
        photoCard.tap()

        // 等待照片选择器出现
        let photoPicker = app.otherElements["PhotosPicker"]
        XCTAssertTrue(
            photoPicker.waitForExistence(timeout: 10),
            "点击上传照片后应打开照片选择器"
        )

        return self
    }

    /// 预览已上传的照片
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapPreviewPhoto() -> CreateOutfitPage {
        let previewButton = app.buttons["outfit.photo.preview"]
        XCTAssertTrue(
            previewButton.waitForExistence(timeout: 10),
            "未找到照片预览按钮: outfit.photo.preview"
        )
        previewButton.tap()
        return self
    }

    /// 关闭照片预览
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func closePhotoPreview() -> CreateOutfitPage {
        // 点击空白区域或查找关闭按钮
        let dismissArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        dismissArea.tap()
        return self
    }

    // MARK: - Generate Methods

    /// 点击虚拟试穿按钮开始生成
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapGenerateTryOn() -> CreateOutfitPage {
        let generateButton = app.buttons["outfit.generate.button"]
        XCTAssertTrue(
            generateButton.waitForExistence(timeout: 10),
            "未找到虚拟试穿按钮: outfit.generate.button"
        )

        // 验证按钮可点击（未禁用）
        XCTAssertTrue(
            generateButton.isEnabled,
            "虚拟试穿按钮应处于可点击状态"
        )

        generateButton.tap()
        return self
    }

    /// 等待生成完成
    /// - Parameter timeout: 超时时间（秒）
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func waitForGeneration(timeout: TimeInterval = 70) -> CreateOutfitPage {
        // 等待生成中状态消失
        let generatingText = app.staticTexts["AI 正在生成效果图…"]
        let startTime = Date()

        while generatingText.exists && Date().timeIntervalSince(startTime) < timeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        // 验证生成完成（显示预览图或保存按钮）
        let previewExists = app.otherElements["outfit.preview.hero"].waitForExistence(timeout: 5)
        XCTAssertTrue(
            previewExists || app.buttons["保存到相册"].waitForExistence(timeout: 5),
            "生成完成后应显示预览图或保存按钮"
        )

        return self
    }

    // MARK: - Action Methods

    /// 点击保存到相册
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapSaveToPhotos() -> CreateOutfitPage {
        let saveButton = app.buttons["保存到相册"]
        XCTAssertTrue(
            saveButton.waitForExistence(timeout: 10),
            "未找到保存到相册按钮"
        )
        saveButton.tap()

        // 等待保存完成提示
        let successText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "已保存")).firstMatch
        _ = successText.waitForExistence(timeout: 5)

        return self
    }

    /// 点击加入日历
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapAddToCalendar() -> CreateOutfitPage {
        let calendarButton = app.buttons["加入日历"]
        XCTAssertTrue(
            calendarButton.waitForExistence(timeout: 10),
            "未找到加入日历按钮"
        )
        calendarButton.tap()

        // 等待添加成功提示
        let successText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "已添加")).firstMatch
        _ = successText.waitForExistence(timeout: 5)

        return self
    }

    /// 点击删除穿搭
    /// - Returns: OutfitPage 实例（删除后返回搭配列表）
    func tapDeleteOutfit() -> OutfitPage {
        let deleteButton = app.buttons["删除穿搭"]
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 10),
            "未找到删除穿搭按钮"
        )
        deleteButton.tap()

        // 确认删除弹窗
        let confirmDelete = app.buttons["删除"]
        XCTAssertTrue(
            confirmDelete.waitForExistence(timeout: 5),
            "应显示删除确认弹窗"
        )
        confirmDelete.tap()

        // 验证返回搭配列表
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 10),
            "删除后应返回搭配列表页面"
        )

        return OutfitPage(app: app)
    }

    /// 点击设为私密/公开我的穿搭
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapToggleVisibility() -> CreateOutfitPage {
        // 查找公开/私密按钮（文本可能不同）
        let visibilityButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "公开", "私密")).firstMatch
        XCTAssertTrue(
            visibilityButton.waitForExistence(timeout: 10),
            "未找到公开/私密切换按钮"
        )
        visibilityButton.tap()
        return self
    }

    // MARK: - Navigation Methods

    /// 点击完成按钮保存搭配并返回
    /// - Returns: OutfitPage 实例
    func tapDone() -> OutfitPage {
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "未找到完成按钮"
        )
        doneButton.tap()

        // 验证返回搭配列表
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 10),
            "点击完成后应返回搭配列表页面"
        )

        return OutfitPage(app: app)
    }

    /// 点击返回按钮（不保存）
    /// - Returns: OutfitPage 实例
    func tapBack() -> OutfitPage {
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "未找到返回按钮"
        )
        backButton.tap()

        // 验证返回搭配列表
        XCTAssertTrue(
            app.staticTexts["搭配"].waitForExistence(timeout: 10),
            "点击返回后应返回搭配列表页面"
        )

        return OutfitPage(app: app)
    }

    /// 预览生成的效果图（点击预览区域）
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func tapPreviewImage() -> CreateOutfitPage {
        let heroCard = app.otherElements["outfit.preview.hero"]
        XCTAssertTrue(
            heroCard.waitForExistence(timeout: 10),
            "未找到预览图区域: outfit.preview.hero"
        )
        heroCard.tap()

        // 验证全屏预览打开
        XCTAssertTrue(
            app.otherElements["fullscreen.image.view"].waitForExistence(timeout: 5),
            "点击预览图后应打开全屏预览"
        )

        return self
    }

    /// 关闭全屏预览
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func closeFullscreenPreview() -> CreateOutfitPage {
        // 点击空白区域关闭
        let dismissArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        dismissArea.tap()
        return self
    }

    // MARK: - Error Handling

    /// 检查是否显示错误提示
    /// - Returns: true 如果显示错误提示
    func isErrorDisplayed() -> Bool {
        let errorPredicates = [
            "请先登录",
            "请先上传本人照片",
            "请选择至少一件衣物",
            "生成失败",
            "错误"
        ]

        for errorText in errorPredicates {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", errorText)
            let errorElement = app.staticTexts.matching(predicate).firstMatch
            if errorElement.waitForExistence(timeout: 3) {
                return true
            }
        }

        // 检查是否有警告弹窗
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            return true
        }

        return false
    }

    /// 获取错误消息文本
    /// - Returns: 错误消息文本
    func getErrorMessage() -> String {
        // 优先检查弹窗
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            let message = alert.staticTexts.element(boundBy: 1)
            if message.exists {
                return message.label
            }
        }

        // 检查页面上的错误文本
        let errorPredicates = [
            "请先登录",
            "请先上传本人照片",
            "请选择至少一件衣物",
            "生成失败"
        ]

        for errorText in errorPredicates {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", errorText)
            let errorElement = app.staticTexts.matching(predicate).firstMatch
            if errorElement.waitForExistence(timeout: 2) {
                return errorElement.label
            }
        }

        return ""
    }

    /// 点击知道了关闭错误弹窗
    /// - Returns: CreateOutfitPage 实例（支持链式调用）
    @discardableResult
    func dismissErrorAlert() -> CreateOutfitPage {
        let okButton = app.alerts.buttons["知道了"]
        if okButton.waitForExistence(timeout: 5) {
            okButton.tap()
        }
        return self
    }
}
