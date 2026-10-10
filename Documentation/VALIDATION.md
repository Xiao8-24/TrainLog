# 验证记录

日期：2026-10-09（Asia/Shanghai）。执行环境：Windows / PowerShell。

2026-10-10 更新：创建 Xiao8-24/TrainLog 仓库，补充 macOS Actions 测试、日志与 xcresult 附件、未签名设备归档、源码/IPA 校验及测试通过后的预览版 Release 流程。本地重新通过 35 文件语法/工程检查、Bash 脚本语法检查和工作流 YAML 解析。初次上传时云端任务尚未实际执行，不计入下方“已执行”测试；真实结果以对应提交的 Actions 记录为准。

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

机器可读的本次结果保存在 `static-check-results.json`。可运行 `python3 Tools/check_source.py --write-report` 重新生成；Swift 语法解析需要安装 `tree-sitter` 与 `tree-sitter-swift`，这些只用于开发检查，不是 iPhone 应用依赖。

## 已编写但没有运行

| 测试集 | 数量 | 覆盖 |
|---|---:|---|
| TrainLogCoreTests | 22 | 主次肌群权重、快速记录去重、60×8=76、组类型、失败 0 次、编辑/删除回退、组顺序、哑铃与自重、时间与时区、单位与无效数值、空数据、历史快照、体重时间、周期样本门槛、模板未完成、计时、备份与 CSV |
| TrainLogTests | 6 | 落盘重开、草稿与设置、关系级联、历史修改、校验失败保留原值、动作快照、合并/替换与恢复副本、矢量命中 |
| TrainLogUITests | 3 | 快速胸部记录保存/查阅/删除、草稿关闭重开、四 Tab 空状态 |

## 未执行

- Swift 编译器类型检查、`swift test`。
- `xcodebuild build/test/archive`。
- iOS 模拟器、真机、通知授权和后台提醒。
- 真机 VoiceOver、Reduce Motion、最大辅助字号、横屏。
- Instruments 内存、帧率与大档案性能评估。
- 多版本 SwiftData 数据库迁移与 App Store 校验。

当前环境没有 Swift、Xcode 或 Apple SDK，WSL 也没有可用 Linux 发行版。没有以另一语言复刻算法并把其结果宣称为 Swift 测试结果。项目没有生成可安装 IPA。

## 在 Mac 上继续验收

执行 `bash Tools/test-ios.sh`，记录实际 Xcode/SDK/模拟器版本及完整结果。若构建报错，修复源文件后重新运行对应测试，再按照 `ACCEPTANCE.md` 检查 UI。只有收到真实运行结果，才能将上述“未执行”更新为“通过”或“失败”。

