> 一旦我所属的文件夹有所变化，请更新我。
文件夹：Pages｜地位：UI 测试页面对象层
功能：封装页面操作/同步等待/断言，当前已适配短信注册页字段、短信登录入口与忘记密码入口的稳定标识与兼容操作
- 2026-03-03: `ProfilePage.swift` 新增未登录态入口兼容（`profile.login/register.button` 与 `sms.inline.phone.field` 双分支）；`LoginPage.swift` 与 `RegistrationPage.swift` 支持内联短信登录/自动注册流程，避免依赖旧登录页导致测试中断。
