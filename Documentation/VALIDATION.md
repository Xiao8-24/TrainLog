# 验证记录

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

