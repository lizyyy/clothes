// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS UI 测试页面对象层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import XCTest

/// 添加衣物页面封装
/// 提供添加衣物流程的元素访问和操作封装
/// 支持拍照、相册选择和批量导入
struct AddClothingPage {

    // MARK: - Properties

    /// 应用实例
    let app: XCUIApplication

    // MARK: - State Properties

    /// 检查是否在源选择页面（初始页面）
    var isOnSourceSelection: Bool {
        return app.buttons["addclothing.camera.button"].waitForExistence(timeout: 3)
    }

    /// 检查是否在编辑页面（已有草稿）
    var isOnEditor: Bool {
        return app.buttons["addclothing.save.button"].waitForExistence(timeout: 3)
    }

    /// 获取当前草稿数量
    var draftCount: Int {
        // 通过缩略图数量判断草稿数量
        let thumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "addclothing.thumbnail."))
        return thumbnails.count
    }

    // MARK: - Source Selection Methods

    /// 点击拍照添加按钮
    /// - Note: 会打开相机，需要在真机或支持相机的模拟器上测试
    func tapTakePhoto() {
        let cameraButton = app.buttons["addclothing.camera.button"]
        XCTAssertTrue(
            cameraButton.waitForExistence(timeout: 10),
            "未找到拍照添加按钮: addclothing.camera.button"
        )
        cameraButton.tap()

        // 验证相机界面打开
        XCTAssertTrue(
            app.otherElements["CameraView"].waitForExistence(timeout: 5) ||
            app.alerts.firstMatch.waitForExistence(timeout: 3),
            "点击拍照后应打开相机或显示权限提示"
        )
    }

    /// 点击相册选择按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapSelectFromAlbum() -> AddClothingPage {
        let albumButton = app.buttons["addclothing.album.button"]
        XCTAssertTrue(
            albumButton.waitForExistence(timeout: 10),
            "未找到相册选择按钮: addclothing.album.button"
        )
        albumButton.tap()

        // 验证照片选择器打开
        XCTAssertTrue(
            app.otherElements["PhotosPicker"].waitForExistence(timeout: 10),
            "点击相册选择后应打开照片选择器"
        )

        return AddClothingPage(app: app)
    }

    /// 点击批量导入按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapBatchImport() -> AddClothingPage {
        let batchButton = app.buttons["addclothing.batch.button"]
        XCTAssertTrue(
            batchButton.waitForExistence(timeout: 10),
            "未找到批量导入按钮: addclothing.batch.button"
        )
        batchButton.tap()

        // 验证照片选择器打开
        XCTAssertTrue(
            app.otherElements["PhotosPicker"].waitForExistence(timeout: 10),
            "点击批量导入后应打开照片选择器"
        )

        return AddClothingPage(app: app)
    }

    /// 点击整图拆解按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapSplitPhoto() -> AddClothingPage {
        let splitButton = app.buttons["addclothing.split.button"]
        XCTAssertTrue(
            splitButton.waitForExistence(timeout: 10),
            "未找到整图拆解按钮: addclothing.split.button"
        )
        splitButton.tap()

        // 验证照片选择器打开
        XCTAssertTrue(
            app.otherElements["PhotosPicker"].waitForExistence(timeout: 10),
            "点击整图拆解后应打开照片选择器"
        )

        return AddClothingPage(app: app)
    }

    // MARK: - Editor Methods

    /// 选择分类
    /// - Parameter category: 分类名称（如 "上衣", "长裤" 等）
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func selectCategory(_ category: String) -> AddClothingPage {
        // 点击分类行
        let categoryRow = app.buttons["addclothing.category.row"]
        XCTAssertTrue(
            categoryRow.waitForExistence(timeout: 10),
            "未找到分类选择行"
        )
        categoryRow.tap()

        // 验证选择器出现
        XCTAssertTrue(
            app.staticTexts["选择品类"].waitForExistence(timeout: 5),
            "应显示品类选择器"
        )

        // 选择指定分类
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(
            wheel.waitForExistence(timeout: 10),
            "未找到分类选择器轮盘"
        )
        wheel.adjust(toPickerWheelValue: category)

        // 点击完成
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "未找到完成按钮"
        )
        doneButton.tap()

        return AddClothingPage(app: app)
    }

    /// 选择季节
    /// - Parameter season: 季节名称（如 "春", "夏", "秋", "冬", "四季"）
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func selectSeason(_ season: String) -> AddClothingPage {
        // 点击季节行
        let seasonRow = app.buttons["addclothing.season.row"]
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

        // 选择指定季节
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(
            wheel.waitForExistence(timeout: 10),
            "未找到季节选择器轮盘"
        )
        wheel.adjust(toPickerWheelValue: season)

        // 点击完成
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "未找到完成按钮"
        )
        doneButton.tap()

        return AddClothingPage(app: app)
    }

    /// 选择适用场景
    /// - Parameter occasion: 场景名称（如 "工作", "休闲", "运动" 等）
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func selectOccasion(_ occasion: String) -> AddClothingPage {
        // 点击场景行
        let occasionRow = app.buttons["addclothing.occasion.row"]
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

        // 选择指定场景
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(
            wheel.waitForExistence(timeout: 10),
            "未找到适用场景选择器轮盘"
        )
        wheel.adjust(toPickerWheelValue: occasion)

        // 点击完成
        let doneButton = app.buttons["完成"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "未找到完成按钮"
        )
        doneButton.tap()

        return AddClothingPage(app: app)
    }

    /// 选择颜色
    /// - Parameter colorName: 颜色名称（如 "白色系", "黑色系" 等）
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func selectColor(_ colorName: String) -> AddClothingPage {
        // 颜色选择是通过颜色圆圈直接点击
        let colorPredicate = NSPredicate(format: "label CONTAINS[c] %@", colorName)
        let colorButton = app.buttons.matching(colorPredicate).firstMatch

        XCTAssertTrue(
            colorButton.waitForExistence(timeout: 10),
            "未找到颜色选项: \(colorName)"
        )
        colorButton.tap()

        return AddClothingPage(app: app)
    }

    /// 输入衣物名称
    /// - Parameter name: 衣物名称
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func inputName(_ name: String) -> AddClothingPage {
        let nameField = app.textFields["addclothing.name.field"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 10),
            "未找到名称输入框"
        )

        nameField.tap()
        nameField.typeText(name)

        // 关闭键盘
        dismissKeyboard()

        return AddClothingPage(app: app)
    }

    /// 点击保存按钮
    /// - Returns: WardrobePage 实例
    func tapSave() -> WardrobePage {
        let saveButton = app.buttons["addclothing.save.button"]
        XCTAssertTrue(
            saveButton.waitForExistence(timeout: 10),
            "未找到保存按钮: addclothing.save.button"
        )

        XCTAssertTrue(
            saveButton.isEnabled,
            "保存按钮未启用"
        )

        saveButton.tap()

        // 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 15),
            "保存后应返回衣橱页面"
        )

        return WardrobePage(app: app)
    }

    /// 点击取消按钮
    /// - Returns: WardrobePage 实例
    func tapCancel() -> WardrobePage {
        let cancelButton = app.buttons["addclothing.cancel.button"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 10),
            "未找到取消按钮: addclothing.cancel.button"
        )
        cancelButton.tap()

        // 验证返回衣橱页面
        XCTAssertTrue(
            app.buttons["wardrobe.add.button"].waitForExistence(timeout: 10),
            "取消后应返回衣橱页面"
        )

        return WardrobePage(app: app)
    }

    /// 点击手动抹除按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapManualErase() -> AddClothingPage {
        let eraseButton = app.buttons["addclothing.erase.button"]
        XCTAssertTrue(
            eraseButton.waitForExistence(timeout: 10),
            "未找到手动抹除按钮"
        )
        eraseButton.tap()

        // 验证手动抹除页面打开
        XCTAssertTrue(
            app.navigationBars["手动抹除"].waitForExistence(timeout: 5) ||
            app.staticTexts["手动抹除"].waitForExistence(timeout: 5),
            "应打开手动抹除页面"
        )

        return AddClothingPage(app: app)
    }

    /// 点击旋转左按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapRotateLeft() -> AddClothingPage {
        let rotateButton = app.buttons["addclothing.rotate.left"]
        XCTAssertTrue(
            rotateButton.waitForExistence(timeout: 10),
            "未找到旋转左按钮"
        )
        rotateButton.tap()

        return AddClothingPage(app: app)
    }

    /// 点击旋转右按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapRotateRight() -> AddClothingPage {
        let rotateButton = app.buttons["addclothing.rotate.right"]
        XCTAssertTrue(
            rotateButton.waitForExistence(timeout: 10),
            "未找到旋转右按钮"
        )
        rotateButton.tap()

        return AddClothingPage(app: app)
    }

    /// 点击整理美化按钮
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func tapFlatten() -> AddClothingPage {
        let flattenButton = app.buttons["addclothing.flatten.button"]
        XCTAssertTrue(
            flattenButton.waitForExistence(timeout: 10),
            "未找到整理美化按钮"
        )
        flattenButton.tap()

        // 等待处理完成或显示加载状态
        let progress = app.progressIndicators.firstMatch
        _ = progress.waitForExistence(timeout: 3)

        return AddClothingPage(app: app)
    }

    /// 选择草稿（在批量导入时）
    /// - Parameter index: 草稿索引
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func selectDraft(at index: Int) -> AddClothingPage {
        let thumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "addclothing.thumbnail."))
        XCTAssertTrue(
            thumbnails.count > index,
            "草稿数量不足，无法选择第 \(index) 个"
        )

        let thumbnail = thumbnails.element(boundBy: index)
        XCTAssertTrue(
            thumbnail.waitForExistence(timeout: 5),
            "应找到第 \(index) 个草稿缩略图"
        )
        thumbnail.tap()

        return AddClothingPage(app: app)
    }

    /// 切换"应用到全部"开关
    /// - Parameter enabled: 是否启用
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func toggleApplyToAll(_ enabled: Bool) -> AddClothingPage {
        let toggle = app.switches["addclothing.applyToAll.toggle"]
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 10),
            "未找到'应用到全部'开关"
        )

        let currentValue = toggle.value as? String
        let isOn = currentValue == "1"

        if isOn != enabled {
            toggle.tap()
        }

        return AddClothingPage(app: app)
    }

    // MARK: - Navigation Methods

    /// 关闭手动抹除页面
    /// - Returns: AddClothingPage 实例
    @discardableResult
    func closeManualErase() -> AddClothingPage {
        let closeButton = app.buttons["完成"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 10),
            "未找到完成按钮"
        )
        closeButton.tap()

        return AddClothingPage(app: app)
    }

    // MARK: - Private Helpers

    /// 关闭键盘
    private func dismissKeyboard() {
        let doneButton = app.buttons["完成"]
        if doneButton.exists && doneButton.isHittable {
            doneButton.tap()
        } else {
            // 点击屏幕空白处关闭键盘
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        }
    }
}
