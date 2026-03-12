> 一旦我所属的文件夹有所变化，请更新我。
文件夹：ClothesUITests｜地位：iOS UI 自动化测试目录
功能：沉淀端到端/业务校验测试并组织页面对象协作，已覆盖短信注册、用户名/手机号密码登录、手机号验证码登录与忘记密码重置链路
- 2026-03-02: `AuthUITests.swift` 的忘记密码链路切换到分步式重置流程，并新增输入限制/倒计时/密码规则与二次确认不一致校验的 UI 覆盖。
- 2026-03-02: `ClothesUserFlowUITests.swift` 的 `testUserRegistration` 短信注册手机号更新为 `18600646073 / 19536108230 / 13723870267`，与真机验收口径保持一致。
- 2026-03-03: 登录流程适配为“内联短信卡片优先、旧登录入口兜底”：`AuthUITests.swift`、`AuthValidationUITests.swift`、`ProfileBusinessFlowUITests.swift`、`ProfileUITests.swift`、`OutfitUITests.swift`、`ClothesUserFlowUITests.swift` 均补充 `sms.inline.*` 分支，避免 `profile.login/register.button` 缺失导致用例失效。
- 2026-03-03: `ProfileBusinessFlowUITests.swift` 的后端资料校验补充 `gender=3 -> 中性` 映射，并扩展手机号字段解码（`phone/mobile/mobile_phone/phone_number`）以兼容短信登录校验。
- 2026-03-05: `ProfileBusinessFlowUITests.swift` 取消对固定 `lzy/qwe123` 账号的硬依赖，改为“优先固定账号，不可用则自动注册临时账号”策略，避免头像切换业务用例因前置账号失效被整体 `skip`。
- 2026-03-05: `Pages/RegistrationPage.swift` 的内联短信注册完成动作改为“仅在提交按钮禁用时尝试切换协议态”，修复发送验证码后再次误点协议导致 `sms.inline.submit.button` 被反向禁用的偶发失败。
- 2026-03-05: `ClothesUISmokeTests.swift` 新增两类覆盖：`testSwitchAccountListShowsNicknameAndLoginUsernameField` 校验切换账号卡片展示昵称+登录用户名（手机号字段）；`testExploreCreatorHomeAndDetailRespectLatestUIWhenFeedAvailable` 校验探索页“他人主页/分享详情”链路并确认主页不再展示手机号文案。
