# 验证记录

## 0.3.0 Liquid Glass

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

