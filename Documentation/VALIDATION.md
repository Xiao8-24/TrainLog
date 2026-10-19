# 验证记录

## 0.7.0 已批准 A、D 与原生体验交付

2026-10-19 11:26（上海时间），[Actions #33](https://github.com/Xiao8-24/TrainLog/actions/runs/39193170639) 对提交 `18ff8add916c90001136e128dde54f6be174f2cb` 完成验证并发布 [v0.7.0](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.7.0)。**64 项核心、35 项数据库/服务、12 项原生手机 UI，共111项通过，0失败**。Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式，iPhone Air / iOS 27.0 (24A434)。设备归档含 Widget 和 Watch，均为0.7.0 / build10，最低 iOS/watchOS27.0，使用各自27.0 SDK。

本轮实现已批准的明确关联手机/手表力量训练与原生 App Intents；每周安排/提醒和 iCloud 同步未开发。回归覆盖：同一条力量记录附加传感器摘要、重复接收、旧编辑快照不抹去附件、删除收据、未知请求不另建、乱序状态不回退、V2→V3迁移和冷启动读取、手表管理期间不额外导出手机健康副本、确认取消后恢复手机导出。恢复日志已存在但 recording 状态落盘失败时，放弃恢复仍保留手表管理状态，拒绝旧请求重放，避免误认尚未开始而重复写入。

保存与路由回归覆盖输入合并、关闭时写入、失败重试、非法数字、完成后旧任务不恢复草稿、历史观察隔离、退后台后重启恢复最后备注，以及训练主页、过期草稿、缺失模板和旧休息目标。JSON新导出为版本3并继续读1/2，CSV保留原32列并追加8列关联摘要；完整JSON超出32MB恢复上限会明确拒绝。

**截图复核范围：** 最终诊断附件包含16张手机截图和2张Watch截图。已目视核对关联摘要与平均心率、深色休息浮层、最大辅助字号的休息结束控件，以及 Watch 启动页和运动列表。关联界面由隔离测试种入模拟数据，备注明确为“非真实传感器测量”，没有访问真实健康数据库。名为心率图的截图停在摘要与图表上缘，不能据此声称完整曲线已目视验收。最大辅助字号下连接入口文案的完整呈现、全流程 VoiceOver 与其他辅助字号仍需走查。

Watch Ultra 4 (49mm) / watchOS27.0 (24R362) 上，最终App的值类型路径入口能显示实际运动列表和绿色选中勾，没有替换WindowGroup为另一套预览宿主；该次2秒进程采样中主线程处于系统事件等待。此结果不等于已验证手动选择/返回、真实传感器刷新期间的交互或真机帧率。最终诊断附件SHA256：`2baed13cd44dd229a9fc7efb0fc50c100fec788fa41d49f07f276c89fc1198a2`，已下载校验。

首轮[#31](https://github.com/Xiao8-24/TrainLog/actions/runs/39190034704)为较早快照，99项测试和归档通过；不能替代最终111项结论。[#32](https://github.com/Xiao8-24/TrainLog/actions/runs/39191801831)在复核恢复边界时，经用户明确授权取消，未发布，之前完成的部分测试不能计为一轮全量通过。最终发布只指向#33提交。

五个发布文件的大小、GitHub资产SHA256与发布校验单全部一致；源码ZIP的**127个文件**与测试提交逐字节一致。本地Delivery已更新这五个原生交付文件，Windows预览保持原演示范围。三个产品的版本、最低系统和SDK已核对，均无设备provisioning profile或代码签名。

| 发布文件 | 字节 | SHA256 |
|---|---:|---|
| BUILD-ENVIRONMENT.txt | 487 | `09f861dfb41c1f577ca7fc3ad56820db3e935dda44de304fc6fa367424c6b574` |
| INSTALLATION.txt | 1614 | `9330cba64ab990e8cb73ebc6371d236cf001fc53a1b4d94260949e4a5406be1e` |
| SHA256SUMS.txt | 349 | `262bcfd309a82fe41ba058efdb59c118a9fb2ef76c2db474aa54a7ddfd6d7147` |
| TrainLog-iOS-source.zip | 356445 | `fccfae61392a91460f28d5eb3cac386a126f27de1a0d818a8ebe8bf44d854158` |
| TrainLog-unsigned.ipa | 1988492 | `d976bb2b22e7af5c83f4ff4ca25fc4cb00e486bc863310a41337dbcd81a88e66` |

共享源码现在归入单一Shared工程组，最终日志未出现此前双组引用警告。仍有Text拼接和既有HKWorkout初始化弃用、SwiftData Predicate Sendable、无AppIntents依赖的目标跳过元数据提取等警告。两项UI输入用例出现框架尺寸警告并通过；本轮不是零警告、Swift6语言模式迁移或真机性能验收。

**仍待签名配对真机：** 健康授权、实际心率/距离/系统能量、断线/锁定/后台传输、保存或状态写入失败恢复、Apple健身展示、Siri与快捷指令身份验证、系统交互小组件、锁屏/灵动岛、真实帧率/功耗及大档案峰值内存。手机和手表计时分别保留，手机完成不结束手表。血氧和VO₂ max仅读取系统已有参考。IPA不能直接安装，主App、Widget、Watch需分别签名，健康与App Group能力按[功能说明](APPROVED_FEATURES.md)配置。

## 0.6.1 手表原生选择与最终交付

2026-10-18 12:08（上海时间），[Actions #24](https://github.com/Xiao8-24/TrainLog/actions/runs/39094961972) 验证提交 `f3955ee905a15c43c3269029408b7e48407f6434` 并发布 [v0.6.1](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.6.1)。52 项核心、22 项数据库/服务、9 项原生手机 UI，共 **83 项通过，0 失败**。Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式、iPhone Air / iOS 27.0 (24A434)；设备归档包含 Widget 与原生 Watch App，三个产品均为 0.6.1 / build 9，最低 iOS/watchOS 27.0，分别使用 iPhoneOS/watchOS 27.0 SDK。

修复 Watch 启动页的运动与泳池长度选择：改用系统导航和带当前选中状态的列表，避免滚动容器内的选择器压成细条。测试命令在当前 Xcode 支持时关闭额外诊断收集，保留显式截图与 xcresult；本轮没有此前测试通过后额外等待 600 秒的情况。

已下载核对全部五个发布资产的大小、GitHub SHA256 与发布校验单，源码 ZIP 的 **112 个文件**与上述提交逐字节一致。本地 `Delivery` 的五个原生交付文件已全部更新；Windows 预览维持其 README 所述演示范围。

| 发布文件 | 字节 | SHA256 |
|---|---:|---|
| BUILD-ENVIRONMENT.txt | 487 | `9fd015cc34c36a9d14cc3065fc482d28f00f16ab612d7ea9ffc30e34892cc735` |
| INSTALLATION.txt | 1614 | `9330cba64ab990e8cb73ebc6371d236cf001fc53a1b4d94260949e4a5406be1e` |
| SHA256SUMS.txt | 349 | `2edcb601a2f93bbfc7ab5f0b748cfaa3151a3d6def48c7afecc754e4c001576c` |
| TrainLog-iOS-source.zip | 323237 | `3afe4eb558850fa6a5cd55fa625b4f167a5004abc4337aac3eaefe23838d1ddd` |
| TrainLog-unsigned.ipa | 1695775 | `c63fd7e557ccd31f5c52bd71d4eaf8e42c8085648aab5644fe1d9b4994e95958` |

IPA 内三个产品的版本、部署系统、Watch companion ID、健康用途、实时活动与后台训练声明均已检查；无设备 provisioning profile，不能直接当作已签名安装包使用。

**截图验证范围：** #24 的可选 Watch 截图步骤因云端运行时路径缺失而未生成 PNG；不能根据该步骤的外层成功状态认定截图通过。隔离分支 `codex/watch-qa-v061` 对发布版 Watch、Shared、核心模块和工程执行差异检查。[专项验证 #25](https://github.com/Xiao8-24/TrainLog/actions/runs/39096310776) 的模拟器编译通过，但启动因运行时 profile 不可用失败；按 [Apple 的组件下载与导入流程](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)，重新导入已导出的 `.exportedBundle` 后运行时可用。

[专项验证 #27](https://github.com/Xiao8-24/TrainLog/actions/runs/39097357239)、[#28](https://github.com/Xiao8-24/TrainLog/actions/runs/39132257586)、[#29](https://github.com/Xiao8-24/TrainLog/actions/runs/39132743407) 已取得未改动 App 的实际启动页截图，目视确认运动名称与绿色开始按钮完整显示，原细条裁切问题已消除。设备为 Apple Watch Ultra 4 (49mm)，watchOS 27.0 (24R362)。但自动导航到列表的 DEBUG 截图入口即使等待 25 秒，仍停在系统启动画面；进程采样显示首帧中 SwiftUI 导航/列表布局反复更新，不能将工作流成功视为导航验收，也尚未确认手动进入是否复现。

原始截图与采样已下载并校验：#28 附件 SHA256 `71d9e76fce54f229385b7478220ab776cbcf509808e63d0c7dbfab4a7cbf36f7`，#29 `6f2fc356dacdfc46f756ebadbadd3ddc86fec8d769db99c452c8bce2c1e1b7c9`。自动导航截图入口仅在 DEBUG 执行，Release 不执行该入口；正常手动进入是否复现仍待确认。

[专项验证 #30](https://github.com/Xiao8-24/TrainLog/actions/runs/39133334897) 使用原生隔离调试宿主复核列表：只替换 QA 构建的 WindowGroup 入口，列表实现逐字节保留，宿主差异保存在附件；main 与已发布二进制未改动。已目视确认 422×514 原生截图中运动名称、系统行容器与绿色选中勾完整可见，采样时主线程处于正常事件等待。附件 SHA256 `3d1a96deb1482ef7068fcc7022c0874a18b81b0463dc10566e481c5c448dd1f4`，已下载核对。**这证明列表视图的原生布局，不替代发布 App 中点击进入、选择、返回等交互验证；也没有模拟传感器读数。**

**仍待配对真机：** 健康授权、实际心率/距离/系统能量、血氧/VO₂ max 可读性、熄屏后台、锁定/断线接收、意外退出恢复、健身摘要/圆环、帧率与电池。血氧是健康已有测量的参考值，不承诺运动中连续采集；VO₂ max 读取系统已有估算，不从单次训练推算。传感器与 WatchConnectivity 行为不能由模拟器或替代客户端测试证明。主 App、Widget、Watch 必须分别签名，主 App 与 Watch 启用 HealthKit。

## 0.6.0 有氧与 Apple Watch

2026-10-18 00:21（上海时间），[Actions #23](https://github.com/Xiao8-24/TrainLog/actions/runs/39046620313) 对提交 `97b25db107305254c9e3e0f936c41cd573a39e94` 完成验证并发布 [v0.6.0](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.6.0)。52 项核心、22 项数据库/服务、9 项原生手机 UI，共 **83 项通过，0 失败**。Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式、iPhone Air / iOS 27.0 (24A434)，Watch 使用 watchOS 27.0 (24R362) 模拟器。设备归档包含 Widget 与原生 Watch App，均为 0.6.0 / build 8，最低 iOS/watchOS 27.0。

2026-10-18 下载并核对五个发布资产的大小、GitHub SHA256 和发布校验单；112 个源码文件与测试提交逐字节一致。源码 ZIP SHA256：`9078d2d395f2018f233aaa102f02d8d9409fd3e53ccc70915ecae98dca47b53f`，IPA：`ae8ced7e7b1ee9f348a94a190f311f4e7c7407445cbfdec0d2c86c1764cc929d`。IPA 包含 `Watch/TrainLogWatch.app` 与 Widget，健康用途、Watch companion ID、后台训练声明及版本一致，无设备 provisioning profile。

已目视复核手动跑步完成页（30 分钟/5 km，配速 6 分/km，缺失心率/能量显示未记录）、日历内跑步记录及原生 Watch 启动页。**Watch 运动选择器被压缩成细条并裁切文字，已安排 0.6.1 改为原生导航列表，不将该截图视为完整的手表视觉验收通过。**

升级测试确认 SwiftData V1→V2、原有收藏/归档/名称保留、运动磁盘读写、手表重复导入及删除后迟到消息防重。首轮 #21 的 51 项核心通过，但 Watch 编译因误用泳池长度属性名失败，改为 SDK 的 `lapLength` 后，#22 与 #23 完整通过。

日志保留现有弃用、Predicate Sendable 和共享文件引用警告；有氧 UI 用例首次聚焦距离输入时出现一条框架尺寸警告，用例通过且完成页/日历截图未见横向裁切，输入期间的真实交互性能仍待设备确认。临时数据库测试清理时出现 SQLite 文件仍在使用的日志，测试数据与真实档案隔离。Xcode 在测试成功后额外等待 600 秒收集模拟器诊断并超时；这不是用例失败，也不能作为 App 卡顿或流畅度的结论。0.6.1 检查当前 Xcode 是否支持跳过额外诊断收集，保留 xcresult 结果与显式截图。

**仍待配对真机：** 健康授权、实际心率/距离/系统能量、血氧/VO₂ max 可读性、熄屏后台、锁定/断线接收、意外退出恢复、健身摘要/圆环、帧率与电池。传感器与 WatchConnectivity 行为不能由模拟器或替代客户端测试证明。主 App、Widget、Watch 必须分别签名，主 App 与 Watch 启用 HealthKit。

## 0.5.1 Apple 健康与原生体验

2026-10-17，[Actions #20](https://github.com/Xiao8-24/TrainLog/actions/runs/39036674709) 验证提交 `796235708bf205213624e1f116b1a369ca218c69`，21:44（上海时间）发布 [v0.5.1](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.5.1)。Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式、iPhone Air / iOS 27.0 (24A434) 上，42 个核心、17 个持久化/服务集成与 8 个原生 UI 测试，共 67 项全部通过。Release 设备归档包含小组件扩展，主 App 与扩展均为 0.5.1 / build 7，最低部署 iOS 27.0、iphoneos27.0 SDK。

健康队列测试使用替代客户端，验证拒绝授权、历史不自动全量上传、失败后原版本重试、提交前落盘失败、系统保存后确认落盘失败、同步中删除、关闭后编辑、替换导入及落盘失败时暂停旧摘要提交。纯业务检查覆盖暂停跨度与有效时长、快速补记不结束于未来、历史日期、无效时长、稳定标识与版本、序列化恢复及迟到确认。UI 隔离模式不访问真实健康数据库；新增健康页检查验证关闭且不可用的开关与明确的权限名称/值。已目视复核健康设置、浅深色休息浮层和最大辅助字号截图。

前两轮 #18 / #19 的业务与集成检查均通过，新增健康页 UI 测试因按独立 StaticText 查找系统已合并的 LabeledContent 值失败，发布被阻止。最终为该行显式设置辅助功能名称、值与标识，通过稳定元素读取状态，没有删除状态断言。失败时 Xcode 额外等待约 600 秒收集模拟器诊断；不能将这段诊断等待视为 App 动画卡顿。

已下载五个发布文件，与 GitHub Release 的大小和 SHA256 逐一一致，并校验发布校验单。源码 ZIP 的 94 个文件与上述测试提交逐字节匹配。源码 ZIP SHA256：`01ace8139b61567aff03dc59290f5fceb58ec47a6e8b14e0c9a6f143a4979680`；IPA：`d03ef3f580134bc08587838058839b7f677e87db3614b4ee90479eae86d52547`。IPA 中主 App 包含健康用途说明、Live Activities 声明，小组件版本一致，两者均无设备 provisioning profile。

归档保留 Text 拼接、HKWorkout 显式 duration 初始化的弃用警告，以及 SwiftData Predicate Sendable 与共享文件双组引用警告，未阻止当前 SDK 的测试和构建。显式 duration 构造保留暂停累计时长，未伪造未知的暂停事件或能量样本；后续迁移 WorkoutBuilder 需要相应的计时事件模型。当前不是零警告或 Swift 6 语言模式迁移验收。

**仍待签名 iPhone 验收：** 首次健康授权、拒绝后恢复、健康/健身真实显示、系统锁定与后台恢复、跨设备健康同步、真实系统小组件/灵动岛，以及 Instruments 帧率、功耗和完整辅助功能走查。主 App 签名需启用 HealthKit；健康连接通过系统管理，无额外 Apple 登录，不采集/估算心率或活动热量。详见 [Apple 健康接入说明](APPLE_HEALTH.md)。

## 0.4.0 小组件与训练实时活动

2026-10-17，[Actions #17](https://github.com/Xiao8-24/TrainLog/actions/runs/39024492159) 验证提交 `33cf48403fff442742546db5e0d09ac54d384527`，18:36（上海时间）发布 [v0.4.0](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.4.0)。Xcode 27.0 (27A266a)、Swift 6.4 编译器、iPhone Air / iOS 27.0 (24A434) 上，34 个核心、9 个集成及 7 个 App UI 测试，共 50 项全部通过，Release 设备归档成功。新增链接流程通过设置进入日历、在日历弹窗中进入训练，并在 App 重启后继续原草稿；已复核其真实截图及最大辅助字号休息控件截图。

核心测试覆盖小组件跨午夜、周边界、夏令时、删除和有效正式组摘要，以及实时活动暂停、休息过期和结束状态。SwiftData 显式禁用自动 App Group 数据库位置，原沙盒位置的回归检查通过。扩展不直接读取完整数据库。UI 测试通过 `XCUIDevice.shared.system.open` 发送链接；直接从测试运行器使用 `UIApplication.open` 曾被系统以 “Request is not trusted” 拒绝，此前失败不能当作已送达 App 的链接处理结果。

已下载并校验交付和诊断附件，五个发布资产的大小与 SHA256 均与 GitHub Release 一致；源码包 82 个文件与测试提交逐字节相同。IPA 含 `PlugIns/TrainLogWidgets.appex`，两者均为 0.4.0 / build 5，使用 iphoneos27.0 SDK；主 App 包含 Live Activities 声明及 `trainlog` URL scheme。源码 ZIP SHA256：`f9f141a1442f02c2b23b17c7c38bd29749711e02cddca333a297ffb3d9a7d2f7`；IPA：`79a40ff7bb80b3fee42b7abce135b9c1af0266d28207443dad883eec0dd8eabf`。两者未签名，未包含设备 provisioning profile。

测试模式禁用真实小组件摘要写入和 ActivityKit 请求，因此编译、模型和 App UI 测试不替代主屏幕、锁屏、灵动岛及后台倒计时的设备验收。仍需签名 iPhone 验证扩展 App Group 共享、实际系统布局、权限、手动移除、首次解锁与系统直接冷启动链接。可选统一日志导出在本轮因目标模拟器未启动而未取得内容，判断依据为测试结果与截图。

按用户 2026-10-17 的要求，后续只维护 iOS 27 验证，已移除 iOS 18 CI 任务与发布依赖；以下历史记录保留当时实际结果。已发布二进制的最低部署元数据仍为 iOS 18，不代表后续继续承诺旧系统兼容验收。

## 0.3.1 通知服务响应修复

2026-10-15，[Actions #11](https://github.com/Xiao8-24/TrainLog/actions/runs/38727215902) 的提交 `01fb9f0225955d45eb0ff5c11a7477da121277c9` 在 iOS 27 与 iOS 18 各通过 42 项测试（28 核心 + 8 集成 + 6 UI），Release 设备归档成功，19:36（上海时间）发布 [v0.3.1](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.3.1)。慢服务测试分别用时 1.388 / 0.056 秒，开始与取消的一秒返回断言均通过。iOS 27 浅/深色休息交互测试通过，最终日志无此前的等待采样标记，导出附件中无 Spindump。已目视复核浅色、深色、大辅助字号及已完成训练日历截图；这不替代真机性能或通知后台交付验收。

下载并校验构建产物，与 GitHub Release 五个文件的 SHA256 全部一致；源码包 71 个文件与测试提交逐字节匹配。IPA 元数据为 0.3.1 / build 4、最低 iOS 18、iphoneos27.0 SDK、Xcode 27A266a，未包含签名描述文件。源码包 SHA256：`07fba036c90ed1516dc6c8446c696de72ac94d92463c21aa0cbf4675660f8227`；IPA：`8ef9005b63661bbfa98238fc10da051c275c9b5433228a4f0c91157d8b177fba`。通知调度的 Sendable 转换警告已消除；已有的 SwiftData Predicate 宏迁移警告仍在，工程保持 Swift 5 语言模式。

2026-10-15 复核 0.3.0 最终诊断发现，`Spindump` 的主线程在 `RestTimer.start → cancel → UNUserNotificationCenter.removePendingNotificationRequests` 等待同步 XPC 回复，采样时已等待约 60 秒。因此此前辅助功能容器是排查假设，不是已证实的根因。0.3.1 把通知操作迁移到串行后台队列，保留操作顺序，过期截止时间不重新安排通知，旧错误不会覆盖新计时状态。新增慢服务回归测试与 UI 开始休息耗时断言，双系统复测结果以对应 Actions 为准。

Apple 允许通知中心从任意应用线程使用：[UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)。

[Actions #10](https://github.com/Xiao8-24/TrainLog/actions/runs/38680641216) 中，iOS 18 的 42 项测试通过，iOS 27 的 28 项核心与 6 项 UI 测试通过，包括开始休息交互耗时检查；新增集成用例的两次 2 秒异步等待超时，发布被阻止。测试现改为持有服务完成回调来模拟延迟，避免信号量占用工作线程；队列启动等待允许 30 秒，主线程开始/取消仍必须在 1 秒内返回，并检查取消不能先于旧通知完成。尚未把等待超时归因于确定的系统缺陷，最终结果以修订后的双系统复测为准。

## 0.3.0 Liquid Glass

[Actions #9](https://github.com/Xiao8-24/TrainLog/actions/runs/38566600538) 的提交 `770088ccc5e0acfb3da8a9d9a47138587edffcb3` 在 iOS 27 与 iOS 18 各通过 41 项测试，设备归档及 v0.3.0 预发布成功。2026-10-15 下载并核对全部发布文件 SHA256，70 个源码文件与测试提交逐字节一致。复核最终浅色/深色浮层、概览、训练日历与最大辅助字号截图，横向裁切已修复。不过浅色休息交互仍触发一次系统等待采样，诊断结论及后续修复见 0.3.1。

[Actions #8](https://github.com/Xiao8-24/TrainLog/actions/runs/38563233268) 中，提交 `cf72f8b` 的 iOS 18 兼容任务通过全部 41 项测试，大字号截图无横向越界。iOS 27 休息浮层测试出现辅助功能快照查询超时，未满足发布门槛。后续修复移除每秒更新的玻璃浮层上新增的辅助功能容器，改为逐个检查标题、剩余时间和结束按钮的屏幕边界；测试使用 180 秒菜单选项，为云端交互留出时间。该修复须重新通过双系统验证。

2026-10-14，[Actions #7](https://github.com/Xiao8-24/TrainLog/actions/runs/38527606572) 验证提交 `5eaf2e87de612d4bae1b43918b9030bc5b6a63cc`：Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式、iPhone Air / iOS 27.0 (24A434)，28 核心 + 7 集成 + 6 UI = 41 项全部通过，设备归档成功。独立 Xcode 16.4 / iOS 18.5 任务同样通过 41 项测试。旧系统任务验证回退代码路径，不等于已在 iOS 18 真机测试 Xcode 27 发布二进制。

已下载并按 SHA256 校验原始诊断包，检查浅色/深色概览、玻璃休息浮层和最大辅助字号截图。视觉复核发现大字号日期控件撑宽编辑页，已限制滚动内容宽度，辅助字号使用系统滚轮日期控件和纵向计时布局，并新增浮层/结束按钮不越过屏幕横向边界的 UI 断言。此修复的最终测试与归档见 0.3.0 发布工作流。真机辅助功能组合和性能仍待验收。

## 0.2.0 原生日历更新

2026-10-12，[Actions #5](https://github.com/Xiao8-24/TrainLog/actions/runs/38211655655) 已通过：28 个核心测试、7 个集成测试、4 个 UI 测试，共 39 项，均为 0 失败；iOS 模拟器测试和 Release 设备归档成功。验证提交 `f7f22dff864cc27c8b8162bd81ffe72552ead3b4`。40 个 Swift 文件、107 个工程对象通过静态检查。

2026-10-13，已下载校验并检查 iPhone SE（第 3 代）模拟器的原生日历截图，确认日期圆点和已完成训练列表显示。补充“今天”按钮强制返回当前月并滚回顶部，最终复测见 0.2.0 发布工作流。新功能和仍待真机验收的范围见 [NATIVE_EXPERIENCE.md](NATIVE_EXPERIENCE.md)。以下保留 0.1.0 的历史验证记录。

日期：2026-10-10（Asia/Shanghai）。执行环境：Windows 静态检查 + GitHub macOS 云端 Xcode。

云端验证提交：`9adbd773fa5dab6f47a46ae2c7383c47411016af`。

[GitHub Actions #2：全部成功](https://github.com/Xiao8-24/TrainLog/actions/runs/38047555570)。环境：macOS 15 arm64、Xcode 16.4、Swift 6.1.2 编译器、Swift 5 语言模式、iOS 18.5 SDK/模拟器。22 个核心测试、6 个持久化/肌群集成测试、3 个 UI 测试均为 0 失败；日志包含 `TEST SUCCEEDED` 与 `ARCHIVE SUCCEEDED`。

第一次运行暴露了 App 与 Swift 包 Debug 架构不一致的问题；已在工程生成器和生成工程中统一 ONLY_ACTIVE_ARCH，并限制默认模拟器不高于当前 SDK。第二次运行验证修复有效。Bash 脚本语法、工作流 YAML 解析及模拟器选择也通过本地检查。

## 已执行

| 检查 | 方法 | 结果 |
|---|---|---|
| Swift 语法 | tree-sitter 0.26.0 + tree-sitter-swift 0.7.4 | 35 文件，0 个 ERROR/missing 节点 |
| 工程完整性 | Tools/check_source.py | 101 个对象，ID 无重复、无未定义内部引用 |
| 源文件 target 引用 | 比对仓库 Swift 清单与 project.pbxproj | 所有 app/test 源文件均已引用 |
| plist / 隐私清单 | Python plistlib | 解析通过 |
| Scheme / workspace | XML 解析 | 通过 |
| Asset catalog | JSON 解析 | 通过 |
| 人体矢量 | 源点位复刻渲染并目视检查 | 前后 40 区域，胸部选择测试状态与灰色状态可区分 |
| 应用图标 | Pillow 生成 | RGB、1024×1024、无透明通道 |

语法解析不能验证类型推导、泛型约束、SDK 方法可用性、SwiftData 宏、链接、签名或 UI 运行。

机器可读的静态检查结果保存在 `static-check-results.json`。其中 NOT RUN 只表示静态检查脚本不执行 Apple 构建；云端结果见本页链接。可运行 `python3 Tools/check_source.py --write-report` 重新生成；语法解析依赖只用于开发检查，不是 iPhone 应用依赖。

## 已运行，全部通过

| 测试集 | 数量 | 覆盖 |
|---|---:|---|
| TrainLogCoreTests | 22 | 主次肌群权重、快速记录去重、60×8=76、组类型、失败 0 次、编辑/删除回退、组顺序、哑铃与自重、时间与时区、单位与无效数值、空数据、历史快照、体重时间、周期样本门槛、模板未完成、计时、备份与 CSV |
| TrainLogTests | 6 | 落盘重开、草稿与设置、关系级联、历史修改、校验失败保留原值、动作快照、合并/替换与恢复副本、矢量命中 |
| TrainLogUITests | 3 | 快速胸部记录保存/查阅/删除、草稿关闭重开、四 Tab 空状态 |

## 未执行

- iPhone 真机、通知授权和后台提醒。
- 真机 VoiceOver、Reduce Motion、最大辅助字号、横屏。
- Instruments 内存、帧率与大档案性能评估。
- 多版本 SwiftData 数据库迁移与 App Store 校验。

本地 Windows 没有 Apple SDK，编译和测试在 GitHub 的 macOS runner 完成。已生成未签名设备 IPA，不能直接安装；没有签名证书和 provisioning profile。Xcode 16.4 的 Predicate 宏产生 Sendable 迁移警告，目前使用 Swift 5 语言模式，尚未验证切换至 Swift 6 严格语言模式。

## 在 Mac 上继续验收

2026-10-11 发布复测：核心 22 项和集成 6 项通过；快速记录 UI 用例的滚动前置断言出现间歇失败。日志显示该断言失败后，XCTest 自动滚动并成功完成选择、保存、查阅和删除。测试已改为等待页面及懒加载按钮出现，由 XCTest 定位点击，并增加选择状态断言和截图附件；修改后的完整验证结果见最新发布工作流。

执行 `bash Tools/test-ios.sh`，记录实际 Xcode/SDK/模拟器版本及完整结果。若构建报错，修复源文件后重新运行对应测试，再按照 `ACCEPTANCE.md` 检查 UI。只有收到真实运行结果，才能将上述“未执行”更新为“通过”或“失败”。

