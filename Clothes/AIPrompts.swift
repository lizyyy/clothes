// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation

enum AIPrompts {
    static let flatLay = """
    请将我上传的衣服图片处理为「平铺展示图（flat lay）」风格：
    衣服整体保持自然平铺状态，方向端正、不倾斜
    保留衣服真实版型、比例，不拉伸、不夸张
    自动抚平褶皱，但不要过度磨皮或改变材质质感
    去除原有背景，仅保留衣物主体，背景保持纯净，真实清晰。
    不添加模特、不添加道具、不添加文字或水印
    仅对衣服本身进行处理，颜色保持与原图一致
    输出清晰、适合用于衣橱管理和穿搭推荐的商品级图片
    """

    static let backgroundRemoval = "去除背景，仅保留衣物主体，背景保持纯净的白色或浅色，真实清晰。"

    static func baseModel(height: String, weight: String, size: String) -> String {
        """
        请基于我上传的真实人物照片生成一个虚拟模特形象，要求如下：

        (1). 保留原始人物的真实人脸特征，不要美化、卡通化或更换脸型，不要改变五官比例和肤色。
        (2). 根据我提供的身高、体重和服装尺码，重新生成符合真实人体比例的身体模型（真实成年人体态，不夸张，不瘦身，不健身化）。
        (3). 模特为站立姿势，正面站姿，从头到脚都展示。 自然放松。
        (4.) 穿着统一基础款服装：
           - 上身：纯白色短袖 T 恤（无图案、无文字、无品牌、无褶皱夸张）
           - 下身：纯黑色短裤（简洁、无装饰）
        (5). 不生成其他服饰或配饰：不戴帽子、不戴眼镜、不戴首饰、不背包。
        (6). 背景使用干净的纯色或浅灰色背景，类似电商模特拍摄环境。
        (7). 光线自然均匀，写实风格，接近真实摄影效果，不要插画风、二次元风或CG感。
        (8). 目标是用于后续虚拟试衣和穿搭展示，请确保身体比例准确、衣服贴合但不紧绷。

        身高：\(height) cm
        体重：\(weight) kg
        尺码：\(size)
        """
    }

    static func virtualTryOn(itemNames: [String]) -> String {
        let names = itemNames.isEmpty ? "未命名衣物" : itemNames.joined(separator: "、")
        return """
        请基于我上传的人物照片进行图像编辑，仅替换人物当前穿着的衣服，严格遵循以下规则：

        1. 保留人物的全部身体特征：
           - 人脸必须保持与原图完全一致，不允许重绘、更换或美化五官
           - 保留原始发型、肤色、性别、年龄特征
           - 保留人物原有的站姿、动作和身体比例，不改变体型

        2. 仅对“衣服”进行替换：
           - 使用我提供的衣服图片作为唯一参考
           - 替换人物身上的对应服饰（上衣 / 下装 / 外套等）
           - 不新增、不删除其他服饰或配件

        3. 衣服贴合规则：
           - 衣服需自然贴合人物身体结构
           - 符合真实穿着逻辑（肩线、袖口、裤腰、裤长合理）
           - 不出现悬浮、拉伸、扭曲、穿模或不合身情况

        4. 禁止修改以下内容：
           - 禁止修改人脸、头部、发型
           - 禁止修改身体姿势、手部位置、腿部位置
           - 禁止改变背景、光线和拍摄角度

        5. 风格要求：
           - 写实摄影风格
           - 光影与原始照片保持一致
           - 不要卡通风、插画风、CG风

        6. 目标用途：
           - 用于虚拟试衣和穿搭展示
           - 结果应看起来像真实拍摄照片

        衣物参考：\(names)
        """
    }

    static let outfitParsing = """
    请从照片中识别并分别输出以下类别（如果不存在则返回 null）：
    • 上衣（top）
    • 长裤（long_pants）
    • 短裤（shorts）
    • 外套（outerwear）
    • 帽子（hat）
    • 鞋子（shoes）
    • 袜子（socks）
    • 箱包（bag）
    • 饰品（accessories，如项链、耳环、手表、戒指等）

    兼容规则：
    • 半身裙（skirt）按长裤（long_pants）输出
    • 连体装（one_piece / jumpsuit / dress）按上衣（top）输出

    输出要求
    a. 每个类别需单独输出对应的图像区域（透明背景 PNG，保留原始分辨率比例）。
    b. 仅包含该类别本身，不包含人体皮肤或其他服饰。
    c. 边缘尽量贴合服饰轮廓，避免多余背景。
    d. 同一类别如存在多个实例（如左右鞋），合并为一张图。

    结果格式
    以 JSON 结构返回，每个字段对应一类服饰，字段值为该类别的图像结果（base64 PNG）。
    仅输出 JSON，不要包含解释文字或代码块。
    """

    static let styleSystemPrompt = "你是穿搭顾问，请输出严格 JSON，不要包含多余文本。"

    static func styleUserPrompt(profile: AIStyleProfile) -> String {
        """
        用户信息：
        身高: \(profile.height)cm
        体重: \(profile.weight)kg
        场合: \(profile.occasion)
        气候: \(profile.climate)
        颜色禁忌: \(profile.colorTaboos)
        风格偏好: \(profile.stylePreference)

        输出 JSON：
        {"style_tags":[""],"colors":[""],"categories":[""],"notes":""}
        categories 只允许：\(CategoryConfig.allowedCategoriesPrompt)
        """
    }

    static func dailyUserPrompt(profile: AIStyleProfile, context: DailyContext) -> String {
        """
        用户信息：
        昵称: \(context.name)
        身高: \(profile.height)
        常穿尺码/体型: \(profile.weight)
        常用场合: \(profile.occasion)
        色彩偏好: \(profile.stylePreference)
        今日位置: \(context.location)
        今日天气: \(context.weather)
        今日气温: \(context.temperature)°C
        今日类型: \(context.isWeekend ? "周末" : "工作日")
        日历: \(context.calendarSummary)
        衣橱已有颜色: \(context.availableColors.joined(separator: "、"))

        输出 JSON：
        {"title":"","style_tags":[""],"colors":[""],"categories":[""],"reasons":[""]}
        categories 只允许：\(CategoryConfig.allowedCategoriesPrompt)
        reasons 输出 2-4 条简短推荐理由
        colors 优先从衣橱已有颜色中选择，并考虑颜色搭配美学（邻近色/对比色）。
        """
    }
}
