# iOS 访问 Go 服务使用说明

## 配置说明

### 1. API 基础 URL 配置

在 `SharedConstants.swift` 中配置 Go 服务的地址：

- **iOS 模拟器/真机测试**：统一使用 Mac 的局域网 IP，例如 `http://192.168.124.17:8080`

> 说明：模拟器虽然也经常用 `http://localhost:8080`（映射到 Mac），但为了和真机/多设备一致，建议直接用同一个 IP。

获取 Mac IP 地址的方法：
```bash
# 在终端运行
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### 2. 网络权限配置

如果使用 HTTP（非 HTTPS）连接，需要在 Xcode 项目中配置 App Transport Security：

1. 打开项目设置
2. 选择 Target → Info
3. 添加 `App Transport Security Settings`
4. 添加 `Allow Arbitrary Loads` 并设置为 `YES`（仅开发环境）

或者更安全的方式，只允许特定域名：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.124.17</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 使用示例

### 1. 注册用户

```swift
Task {
    do {
        let response = try await ClothesAPIService.shared.register(
            email: "user@example.com",
            password: "password123",
            name: "用户名"
        )
        print("注册成功，Token: \(response.token)")
    } catch {
        print("注册失败: \(error.localizedDescription)")
    }
}
```

### 2. 登录

```swift
Task {
    do {
        let response = try await ClothesAPIService.shared.login(
            email: "user@example.com",
            password: "password123"
        )
        print("登录成功，Token: \(response.token)")
    } catch {
        print("登录失败: \(error.localizedDescription)")
    }
}
```

### 3. 创建穿搭

```swift
Task {
    do {
        let items = [
            OutfitItem(name: "白衬衫", category: "上衣", image_url: "https://..."),
            OutfitItem(name: "牛仔裤", category: "长裤", image_url: "https://...")
        ]
        
        let response = try await ClothesAPIService.shared.createOutfit(
            title: "周末穿搭",
            items: items,
            imageURL: "https://...",
            shared: false
        )
        print("创建成功，ID: \(response.id)")
    } catch {
        print("创建失败: \(error.localizedDescription)")
    }
}
```

### 4. 获取我的穿搭列表

```swift
Task {
    do {
        let outfits = try await ClothesAPIService.shared.getMyOutfits()
        print("获取到 \(outfits.count) 个穿搭")
    } catch {
        print("获取失败: \(error.localizedDescription)")
    }
}
```

### 5. 获取公开穿搭列表

```swift
Task {
    do {
        let outfits = try await ClothesAPIService.shared.getPublicOutfits()
        print("获取到 \(outfits.count) 个公开穿搭")
    } catch {
        print("获取失败: \(error.localizedDescription)")
    }
}
```

### 6. 分享穿搭

```swift
Task {
    do {
        try await ClothesAPIService.shared.shareOutfit(id: 123)
        print("分享成功")
    } catch {
        print("分享失败: \(error.localizedDescription)")
    }
}
```

### 7. 健康检查

```swift
Task {
    do {
        let isHealthy = try await ClothesAPIService.shared.healthCheck()
        print("服务状态: \(isHealthy ? "正常" : "异常")")
    } catch {
        print("检查失败: \(error.localizedDescription)")
    }
}
```

## 注意事项

1. **Token 管理**：登录或注册成功后，Token 会自动保存。如果需要持久化，可以结合 `@AppStorage` 或 Keychain 使用。

2. **错误处理**：所有 API 调用都可能抛出 `APIError`，建议使用 `do-catch` 进行错误处理。

3. **网络连接**：确保 Go 服务正在运行，并且 iOS 设备/模拟器能够访问到服务地址。

4. **真机测试**：真机测试时，确保 Mac 和 iOS 设备在同一局域网内，并且防火墙允许 8080 端口的连接。
