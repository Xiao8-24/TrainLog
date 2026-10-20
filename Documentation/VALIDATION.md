# 验证记录

## 0.9.1 原生动效、计划复盘与下次目标交付

2026-10-19 23:43（上海时间），[Actions #41](https://github.com/Xiao8-24/TrainLog/actions/runs/39276536287)对提交`37bbfb0e7f65a38ccd9f3d253a5fbedc49cbcd0e`完成验证并发布[v0.9.1](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.9.1)。**83项核心、40项数据库/服务、18项原生手机UI，共141项通过，0失败**；含Widget、Watch的Release设备归档成功。Xcode27.0（27A266a）、Swift6.4编译器 / Swift5语言模式，iPhone Air / iOS27.0（24A434）。主App、小组件和Watch均为0.9.1 / build14，最低系统27.0，分别使用iPhoneOS27.0与WatchOS27.0 SDK。发布源码与归档冻结于该提交；后续仅补充交付文档。

用户明确批准E/G后实现目标快照与实际逐组对照、预览复制实际配置，以及本地可解释目标参考、取消/逐项采用和全局关闭。F、计划提醒、iCloud同步均未开发。JSON备份版本5读取1–5，CSV仍为46列，V4数据库实体不变。12项新增核心回归覆盖快照、旧记录、JSON、增删组、计时、不同配置复制与建议规则；4项新增UI回归覆盖普通/最大辅助字号组操作、复盘复制及建议确认/关闭。既有数据库回归增加目标与实际分离、偏好设置保留等断言。

关键原生流程实际通过：立即回桌面并终止后备注恢复44.780秒；最大辅助字号和应用减少动态效果策略下完整组控制104.212秒；E复盘与编辑实际复制36.982秒；G取消、不采用时仍为8次、采用并保存9次、关闭开关值为0且入口消失47.760秒。没有延长立即退出前的保存等待；UIKit即将失活同步提交与原场景/离页提交并存。此回归不承诺任意强制终止时尚未提交的输入都能恢复。

**最终截图复核范围：** 已目视核对普通字号暂停时重量60/次数8、整体与本组均暂停及底部结束按钮；最大辅助字号暂停与休息浮层的主要控件可见；冷启动后的完整备注`latest note 062`；复盘计划2组/完成2组、计时1组/未计时1组及20秒合计；复制预览保留60kg×9次和60kg×8次两个不同项目；目标参考的可编辑9次与理由；设置开关关闭后仍保留已采用9次，配置页无建议入口。目标参考页截图仅完整展示第一条历史来源，第二条需继续滚动，不能据此声称全部来源同时可见。所有手机截图均为隔离测试数据，不是真实运动或传感器读数。

本轮Watch可选截图步骤实际生成并复核开始页与运动类型列表（户外跑步、室内跑步、户外步行），同时完成2秒进程采样；不同于前轮截图超时，本次内部命令均成功。该证据仅覆盖模拟器入口与列表显示，不代表配对传感器采集、HealthKit/系统健身展示、跨设备断连或同步已真机验收。完整VoiceOver、所有辅助功能组合、Siri/系统小组件交互、真机帧率与功耗仍待设备检查。

最终诊断附件SHA256：`32eceef4528fe9da4604597b3380d0f1095598767099e1ceab13bbbaf5539671`；设备交付附件SHA256：`e5017f16e513dfd179396b8f29a327bbfecb5ff8603e96bb3fe202cecc5ff3a4`。均已下载核对哈希、ZIP完整性和解压路径。五个发布文件的大小、GitHub资产SHA256与发布校验单一致；源码包**140个文件**与测试提交逐字节相同；IPA三个产品版本、最低系统及SDK已核对，无代码签名和设备provisioning profile。本地Delivery已更新五个原生文件，保留既有Windows预览；IPA需有效Apple签名后安装，未发布到TestFlight或App Store。

| 发布文件 | 字节 | SHA256 |
|---|---:|---|
| BUILD-ENVIRONMENT.txt | 487 | `ff886171cf90cdd494909598502aa7eaf4190afae7714ee709c98a4fe0bf88a3` |
| INSTALLATION.txt | 1614 | `9330cba64ab990e8cb73ebc6371d236cf001fc53a1b4d94260949e4a5406be1e` |
| SHA256SUMS.txt | 349 | `0da32bcd992f143e5ecf26ae183ec4fa6c241905b757a7d66524352ad056a298` |
| TrainLog-iOS-source.zip | 402005 | `a62a29c3d03d172290c64ae676da1939fc82e418bdb7b0268fca791424110da5` |
| TrainLog-unsigned.ipa | 2344225 | `f15d47c289727874eb73bdd6386be217c229d46bbebeb995699f0db6a5a07b7b` |

## 0.9.1 前序失败与修复证据

以下#36–40记录保留各候选当时的结果和待修复状态，最终通过与发布仅以上述#41为准；0.8.1与0.9.0未单独发布。

基于实际#38失败录像，原生UI回归会先验证暂停控件位于导航栏下方的完整可见边界，再点按并等待真实暂停状态，保留所有输入与状态断言。复盘补充组类型/休息配置变化、实际动作负重口径及明确的辅助功能计数；目标建议也显示负重口径。版本0.9.1/build14，86个Swift文件、205个工程对象及141个测试方法通过本地语法/引用检查，尚待完整原生验证和发布文件核对。

[Actions #40](https://github.com/Xiao8-24/TrainLog/actions/runs/39270316110)验证提交`c1a12d7c0818986c92c60bfd6228aee7a5f50d78`：83项核心、40项数据库/服务通过，UI17/18通过，发布跳过。立即回桌面并终止后的备注恢复通过（60.031秒），最大辅助字号与减少动态效果的完整组操作通过（115.304秒），E复盘/实际复制通过（50.854秒）。G取消及采用后的9次保留断言通过，关闭入口检查失败。

诊断附件SHA256 `b4199cf689535e4436340e38a0caa2a75f12348eee6696957499e30d4a650a0a`已下载核对。原始录屏显示设置开关始终开启；原始触摸事件为420点屏宽中的x=210、y=416.33，点在包含标签与开关的辅助功能整行中间空白处，未命中右侧开关。后续回归改为点按原生开关右侧实际触摸区域，并在离开设置前等待值为0、保留采用值为9和入口数量为0断言，不更改生产开关逻辑。本轮Watch截图和设备归档因测试失败跳过，等待修复测试后的完整运行。

## 0.9.0 已批准E、G首轮验证（未发布）

用户明确批准E、G后，实现开练时不可由界面编辑的目标快照、逐组实际复盘及新计划预览复制，以及本地可解释目标参考、逐项确认和关闭入口。F未开发。JSON导出版本5读取1–4，CSV46列及V4数据库实体不变。83项核心、40项数据库/服务、18项UI共141项为源码方法数，尚不能视为原生通过。最终日志、真实截图和五个发布文件须另行核对；0.8.1仍是单独运行的动效候选，不据其结果替代本轮功能测试。

[Actions #39](https://github.com/Xiao8-24/TrainLog/actions/runs/39265206967)验证提交`817dbfbce17eedb2cbd102ba1e7f9489442d8548`：83项核心、40项数据库/服务通过，UI15/18通过，发布跳过。计划逐组复盘与实际复制流程通过（41.890秒），普通字号组操作通过（77.458秒）。三处失败是：最大辅助字号的暂停中心点按仍落在导航栏遮挡区域；建议页“取消”查询匹配了多层导航同名按钮；立即回桌面再终止后，草稿备注未恢复。

诊断附件SHA256 `baad2f56e6a3e29db4a7eab8774c34d628d4df9fd13251908da306cf6e11cdc5`已下载核对。原始备注录像显示退后台时已完整呈现“latest note 062”，重启后却为空，故未以延长输入后的等待来规避；增加UIKit即将失活时同步提交待保存快照，同时保留已有场景/离页提交和立即终止回归。具体生命周期边界以修复后的完整验证为准，不承诺任意时刻强制终止前的未提交输入均可恢复。建议页增加独立取消标识；暂停回归检查完整控件边界。另修正复制组/复用配置带入旧RPE/RIR的问题，旧历史字段的填写来源无法倒推，建议采用前需核对。未取得本轮Watch截图或设备归档，因为测试失败后这些步骤跳过。

## 0.8.1 原生动效候选验证（改进并入0.9.1）

首轮提交 `e9b96c30453caf520fccf80dbbf0332c06eacd98` 已在[Actions #36](https://github.com/Xiao8-24/TrainLog/actions/runs/39259575357)使用Xcode27执行原生验证，71项核心通过，但App编译因辅助功能环境属性只读而失败，未运行手机数据库/UI测试，发布跳过。已改用仅DEBUG的自有动效测试键，正式版本仍遵循系统属性，等待修复版完整重测。81个Swift文件、203个工程对象通过本地语法/引用检查；127个测试方法为源码统计，不能当作云端通过数量。版本0.8.1/build12，最低iOS27/watchOS27。

本轮限制动画范围、共用底部系统玻璃表面，添加系统符号替换、局部完成背景、输入/计时动画隔离和暂停文案修复。新增两条输入保留及浮层切换的原生UI回归，其中一条使用本App减少动态效果策略的隔离DEBUG覆盖与最大辅助字号，未更改用户系统设置。创新E/F/G仅列入待审批方案，没有实现。最终日志、截图和五个发布文件须在运行结束后核对；不据此承诺真机帧率或传感器行为。

修复版[Actions #37](https://github.com/Xiao8-24/TrainLog/actions/runs/39260162182)，提交`47978f07e58c18695368f061598992f9dfbbbb83`，71项核心、40项数据库/服务通过，16项UI中15项通过、1项失败，发布跳过。减少动态效果策略+最大辅助字号的完整新增流程通过（79.480秒）；普通字号新用例在输入次数时焦点失败。下载诊断附件并核对SHA256 `c5d8936f50fec3b8d01a18519cc481e8604bb10a877b5e2416bbe3cd1bb0d323`，原始录像显示浮动键盘“收起键盘”按钮覆盖了次数输入点击区域。已给训练滚动区加入键盘工具栏安全区，保留原输入断言，等待下一轮完整验证。E、G已由用户在本轮明确批准，产品实现另行开发；F仍未批准。

[Actions #38](https://github.com/Xiao8-24/TrainLog/actions/runs/39263263793)，提交`cbe4a03e29259c25cb7a7014779ff9b867a74c03`，核心71、数据库/服务40通过，UI15/16通过。普通字号完整新流程通过（97.834秒），键盘遮挡修复有效；最大辅助字号的一处暂停状态断言失败，发布跳过。已核对诊断SHA256 `1ea4dc9224d7c3b59892b0830f802ced295c460700ae6e44b7d65bb3f9023aef`，原始录像显示自动测试在暂停控件仍被玻璃导航栏遮挡时根据isHittable提前停止滚动，中心点按未命中。后续改为检查控件完整画面边界并等待实际暂停状态，保留输入和暂停断言。此失败不能算应用暂停逻辑已通过，也不作为真机帧率结论。

## 0.8.0 实时训练与日期计划交付

2026-10-19 17:34（上海时间），[Actions #35](https://github.com/Xiao8-24/TrainLog/actions/runs/39228055603) 对提交 `6bd53df65416494e8b05f28c631f8f4bd9824a1b` 完成验证并发布 [v0.8.0](https://github.com/Xiao8-24/TrainLog/releases/tag/v0.8.0)。**71 项核心、40 项数据库/服务、14 项原生手机 UI，共125项通过，0失败**；含 Widget 与 Watch 的设备归档成功。Xcode 27.0 (27A266a)、Swift 6.4 编译器 / Swift 5 语言模式，iPhone Air / iOS27.0 (24A434)。三个产品均为0.8.0 / build11，最低iOS/watchOS27.0，使用各自27.0 SDK。

用户本轮明确要求边练边记、提前计划和每组/整体计时，因此实现日期计划；未开启提醒或iCloud。新增7项核心、5项数据库/服务、2项UI回归，保留原111项。覆盖逐组开始/完成、缺失输入不停止时钟、休息与整体暂停、后台序列化、旧备份、新计划不计统计、重复开练保护、V3→V4迁移、暂停冷启动读取及备份替换。V4新增独立计时和计划表，旧实体定义未改。JSON导出版本4并读取1–3，CSV保留原40列并追加6列。

两项新增UI流程分别执行“创建计划→开始→记录60kg×8次并结束本组→休息→完成整场”（55.904秒）以及“开始本组→退后台→暂停→关闭并重启→仍保留暂停的组与整体用时”（53.244秒）。不是只检查按钮存在。组开始/结束和整体暂停/继续立即提交，普通字段沿用合并保存；后台未主动暂停则按日期继续计时。手机计时不操控Watch采集。

**截图复核范围：** 最终诊断附件包含19张手机PNG。已目视核对计划详情的日期、动作/预设组及开始入口，正在训练的重量/次数、本组计时与底部结束入口，以及重启后整体和本组均为暂停。正在训练截图因滚动位置未显示顶部整体计时，不能据此声称两处计时始终同时可见。界面数据来自隔离UI测试，非真实运动或传感器读数。完整VoiceOver、全部辅助字号和真机帧率仍待走查。

本轮Watch可选截图只生成启动图，活动列表截图在等待屏幕表面时发生NSPOSIX代码60超时，未完成列表截图和后续采样；该步骤允许失败，不能用外层任务成功代替Watch交互验收。Watch App入口及WorkoutManager相对0.7.0未变，设备编译/归档通过；上轮截图不作为本轮列表验收结果。最终诊断附件SHA256：`f990ee594274d437d6ec52d528a7d3a980c87840749831116790346f5871d94c`，已下载校验。

首轮[Actions #34](https://github.com/Xiao8-24/TrainLog/actions/runs/39225056897)验证提交`447c73b2214263b05beab8ad706dc06790bda457`，71项核心、40项数据库/服务及12项既有UI通过，新增两项UI在入口点击处失败，共3处失败断言，发布被阻止。已核对诊断附件SHA256：`1d7f5e44f29939b275e50ab4f52d806b86c75ef538e6abd3876d5d2def7b4a02`。原始录像显示模板行与计划菜单中心空白处点按未打开入口；随后修复整行点击形状、稳定辅助功能标识及打开后等待，保留端到端断言。测试脚本在失败时也导出附件，并返回原失败退出码。最终发布仅指向#35通过的提交。

五个发布文件的大小、GitHub资产SHA256及发布校验单全部一致，ZIP完整性检查通过；源码包**133个文件**与测试提交逐字节一致。本地Delivery已更新五个原生交付文件，保留原Windows预览范围。IPA三个产品的版本、最低系统、SDK已核对，无代码签名与设备provisioning profile。

| 发布文件 | 字节 | SHA256 |
|---|---:|---|
| BUILD-ENVIRONMENT.txt | 487 | `7894371b0aa59a73001e1c3f1d9bbe61c78fca29ea74d2f08af59420dd4f7cce` |
| INSTALLATION.txt | 1614 | `9330cba64ab990e8cb73ebc6371d236cf001fc53a1b4d94260949e4a5406be1e` |
| SHA256SUMS.txt | 349 | `8a8d1a3c0eb94f940bc0367bd1f3129674580524cc703e3afdcb7ad9c004f356` |
| TrainLog-iOS-source.zip | 375230 | `2c3329d0f5f2012b6f56f4bb9cc17b1693cd9d0e40960cee180a20e8b1334c18` |
| TrainLog-unsigned.ipa | 2193313 | `801df6a06d41fb83b8bb9a0a61fb5f480bc5386cd5a457aeaa46ef0430224431` |

保留既有Text拼接、HKWorkout初始化弃用、SwiftData Predicate Sendable和无AppIntents依赖目标跳过元数据提取等警告。三个UI输入用例出现框架尺寸警告并通过；不将测试通过等同于零警告或已完成Swift6语言模式迁移。

**仍待签名配对真机：** 健康授权与Apple健身展示、真实传感器、跨设备与锁屏后台传输、Siri/快捷指令、系统小组件/灵动岛、实际帧率/功耗和完整辅助功能走查。IPA不能直接安装，主App、Widget、Watch需分别签名并配置既有健康/App Group能力。使用方法及计时含义见[实时训练与计划](LIVE_TRAINING_AND_PLANS.md)。

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

