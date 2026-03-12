# 上架前待办事项（需 Apple Developer Program）

> 以下内容需要购买 Apple Developer Program（$99/年）后才能完成。

---

## 1. Sign In with Apple

**相关文件**: `Clothes/Clothes.entitlements`

- [ ] 取消注释 `com.apple.developer.applesignin` 配置
- [ ] 在 Xcode → Signing & Capabilities 中重新添加 "Sign In with Apple"
- [ ] 在 App Store Connect → Identifiers 中启用 Apple Sign In

---

## 2. App Store 应用内购买 (IAP)

**相关文件**: `Clothes/IAPManager.swift`、`Clothes/ProfileWalletViews.swift`、`clothes-go/go-service/handler/iap_handler.go`

- [ ] 在 App Store Connect → App内购买项目 中创建 5 个产品：

| 套餐 | 产品ID | 价格 | 穿贝 |
|------|--------|------|------|
| 新手包 | `com.clothes.coin.starter` | ¥10 | 100 |
| 日常包 | `com.clothes.coin.daily` | ¥30 | 300 |
| 人气包 | `com.clothes.coin.popular` | ¥68 | 680 |
| 尊享包 | `com.clothes.coin.vip` | ¥128 | 1280 |
| 臻选包 | `com.clothes.coin.pro` | ¥300 | 3000 |

- [ ] 确保产品ID与 `RechargeProductCatalog`、后端 `IAP_PRODUCTS_JSON` 完全一致
- [ ] 提交 IAP 审核（通常需要与 App 一起提交）
- [ ] 如需上架 App Store，评估是否移除 `dev + DEBUG` 下的后端直充测试兜底

**代码位置**:
```swift
// ProfileWalletViews.swift 中搜索 "allowsDebugDirectRechargeFallback"
#if DEBUG
print("[DEBUG] IAP产品未加载，使用 dev 测试模式直接充值")
// ... 测试代码
#endif
```

**后端环境变量**:

```bash
# online 正式环境
IAP_SANDBOX=false
IAP_PRODUCTS_JSON={"com.clothes.coin.starter":100,"com.clothes.coin.daily":300,"com.clothes.coin.popular":680,"com.clothes.coin.vip":1280,"com.clothes.coin.pro":3000}
```

---

## 3. 开发者账号配置

- [ ] 购买 Apple Developer Program（$99/年）
  - 网址: https://developer.apple.com/programs/
- [ ] 创建 App ID（Bundle Identifier: `x.Clothes`）
- [ ] 配置 Provisioning Profiles
- [ ] 在 App Store Connect 创建 App 记录
- [ ] 准备 App 截图（iPhone 各尺寸）
- [ ] 填写 App 元数据（描述、关键词、隐私政策等）

---

## 4. 测试验证

- [ ] Apple Sign In 功能测试
- [ ] IAP 购买流程测试（沙盒环境）
- [ ] 收据验证测试
- [ ] 充值到账验证

---

## 5. 当前开发模式说明

目前代码包含以下临时处理：

1. **Apple Sign In**: 已注释，DEBUG 模式下可用普通登录
2. **充值功能**: 只有 `dev + DEBUG` 才会在商品未加载时跳过 Apple Pay 直连后端充值
3. **正式环境**: `online` 强制走正式商品与 Apple 收据验证流程

**重要**: 上架前务必移除 DEBUG 模式代码，确保符合 Apple 审核规范。

---

## 相关文档

- [Apple Developer Program](https://developer.apple.com/programs/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [IAP 配置指南](https://developer.apple.com/in-app-purchase/)
- [Sign In with Apple](https://developer.apple.com/sign-in-with-apple/)
