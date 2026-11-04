# 跨平台统一界面与账户同步

## 当前状态

当前 `v0.10.0` 已发布的 iOS、Android、Windows 客户端仍为本地优先，通过完整 JSON 备份手动互通。本分支新增共享品牌常量、Swift/Dart 同步传输层和可本地测试的服务端内核。**尚未提供可用的账户登录或自动同步**：缺少 HTTPS 域名、运行中的服务、Apple 开发者配置及国内登录平台的应用审核与密钥。客户端不会展示无法完成的登录按钮，也不会把本机健康资料上传到未配置的服务器。

## 统一界面

`DesignSystem/tokens.json` 是两端共有的颜色、卡片圆角和内容间距源文件。运行 `python Tools/generate_design_tokens.py` 生成 SwiftUI 与 Flutter 常量；CI 运行 `--check` 防止两端偏离。主强调色采用系统蓝的明暗变体，卡片、分组背景、留白和信息层级一致。训练计时、逐组输入、计划、日历和肌群图仍使用同一记录语义。

导航容器、字体渲染、触觉和无障碍遵循各平台系统：iOS 继续用 SwiftUI 与系统玻璃控件，Android 用系统 Material 组件，Windows 用窗口边框与侧栏。统一的是内容结构和品牌视觉，不模拟另一平台的系统控件。

## 账户目标与依赖

| 登录方式 | 目标客户端 | 必要外部配置 | 当前代码状态 |
| --- | --- | --- | --- |
| Apple 账户 | iOS 原生；Android/Windows 浏览器授权 | Apple Developer Team、App ID、Services ID、HTTPS 域名和回调、私钥 | 服务端原生身份令牌验签、一次性 nonce、授权码交换和刷新令牌撤销内核已实现；客户端授权界面与跨平台网页回调待配置 |
| 微信登录 | iOS/Android 移动应用；Windows 扫码 | 微信开放平台移动/网站应用审核、AppID/Secret、同平台关联 | 服务端授权码交换、UnionID 校验与显式绑定已实现；移动 SDK 和 Windows 扫码授权界面待配置，不能把不同应用的 `openid` 当成同一个人 |
| 手机验证码 | 全平台 | 国内短信服务、号码验证、防刷及费用预算 | 待配置，不会在客户端伪造验证码登录 |
| QQ / 支付宝 | 适用平台 | 各自开放平台应用审核与密钥 | 后续独立适配；不会把它们的邮箱或昵称自动并入现有账户 |

Apple 账户的 `sub` 与微信等平台的标识只在本服务端映射到 TrainLog 账户。不同登录方式必须由已登录用户再次授权后显式绑定；不按邮箱、昵称或手机号自动合并账户。Apple 在非 Apple 平台需要 Services ID 与 HTTPS 回调，不能仅靠 iOS 的系统登录按钮。

## 数据协议

服务端位于 `SyncService/`，使用 Node 24 内置 SQLite 与 AES-256-GCM；文件中不明文保存训练备份或 Apple 刷新令牌。公开部署前必须配置 32 字节加密密钥、HTTPS 反向代理、数据库持久化、备份、监控和密钥轮换计划。服务默认只监听 `127.0.0.1`，未提供必要环境变量会拒绝启动。

账户会话是随机令牌，数据库只存 SHA-256 摘要；Apple/微信身份标识使用服务端密钥的 HMAC 保存，API 不信任客户端传来的账户 ID。已登录用户可以用另一个平台重新授权后显式绑定，若该身份已有账户则返回冲突，不自动合并。同步使用与现有 iOS/Flutter 互通的 JSON schema 1–5，`GET /v1/snapshot` 返回版本，`PUT /v1/snapshot` 必须带 `If-Match` 版本。版本冲突返回 `409`，客户端保留本地记录，不静默覆盖、删除或自动合并。之后要把离线编辑同步得更顺畅，应增加实体级修订及删除墓碑，再启用后台自动上传。账户删除接口要求明确确认，并先撤销 Apple 令牌。

Swift/Dart 传输层默认拒绝上传包含体重或 Apple Watch 测量值的完整备份，只有明确的健康资料同步选择才能解除；当前没有该用户界面，因此未启用上传。正式上线前还需完成隐私告知、数据保存地区与期限、健康资料单独同意、应用内账户删除、备份恢复和真机测试。HealthKit 资料不能被用于广告，也不能存入 iCloud 个人健康信息。

## 验证

`cd SyncService && node --test` 验证加密持久化、账户隔离、Apple JWT 签名/受众/nonce/时效、微信 UnionID、平台显式绑定、一次性挑战、版本冲突、退出和账户删除。跨平台构建会编译 Swift 与 Dart 传输层，并运行 Flutter 网络契约测试。没有开发者账号或公网服务时，无法执行真实 Apple/微信授权、跨设备网络同步与生产环境隐私验收。

## 官方资料

- [Apple：跨平台登录的 Services ID、域名和私钥](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)
- [Apple：验证身份令牌和 nonce](https://developer.apple.com/documentation/signinwithapple/verifying-a-user)
- [Apple：App Review 登录与账户删除规则](https://developer.apple.com/app-store/review/guidelines/)
- [微信开放平台](https://open.weixin.qq.com/)
- [支付宝开放平台网页/移动应用](https://open.alipay.com/module/webApp)
- [《中华人民共和国个人信息保护法》](https://www.miit.gov.cn/jgsj/zfs/fl/art/2022/art_515a4b20c12f430eab54bb4f56d89f56.html)
