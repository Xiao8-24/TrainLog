# TrainLog

记录每一次训练，看见每一点进步。

面向个人力量训练的离线 iPhone 应用。使用 **SwiftUI、SwiftData、Swift Charts、SF Symbols**；最低部署版本 **iOS 18.0**。无服务器、无账号、无第三方运行时依赖。

> **交付状态：原生项目与功能源码已实现，尚未完成 Apple 平台构建验收。**
> 本次开发环境为 Windows，没有 Swift 编译器、Xcode、Apple SDK 或 iOS 模拟器。已执行源文件语法解析、工程引用与资源格式检查；这些检查不能证明 Swift 类型检查、SwiftData 宏展开、链接或运行成功。不要将此交付视为已经通过真机验证的发行版。

## 没有 Mac：使用 GitHub 云端构建

已配置 macOS GitHub Actions：运行业务、持久化和 UI 测试，通过后生成源码 ZIP、未签名 iPhone IPA、校验值，并保留测试日志。手动选择 `publish` 可在全部检查成功后创建 GitHub 预览版 Release。

详见 [云端构建与发布步骤](Documentation/GITHUB_RELEASE.md)。仓库：[Xiao8-24/TrainLog](https://github.com/Xiao8-24/TrainLog)。最新构建状态请查看 [Actions](https://github.com/Xiao8-24/TrainLog/actions)，可下载版本请查看 [Releases](https://github.com/Xiao8-24/TrainLog/releases)。未签名 IPA 需要另外完成有效 Apple 签名才能安装；本项目尚未发布到 TestFlight 或 App Store。

## 在 Mac 上打开、编译与安装

1. 将整个仓库或 `Delivery/TrainLog-iOS-source.zip` 解压到 Mac，保留 `Packages/TrainLogCore` 与 `TrainLog.xcodeproj` 的相对位置。
2. 使用支持 iOS 18 或更新正式 SDK 的 Xcode 打开 **`TrainLog.xcodeproj`**。工程不需要 CocoaPods、网络 Swift Package 或额外工程生成器。
3. 选择共享 Scheme **TrainLog** 和已安装的 iPhone 模拟器。按 **⌘B** 构建、**⌘R** 运行。
4. 真机安装：在 TrainLog target → Signing & Capabilities 中选择自己的开发团队，修改 Bundle Identifier 为自己的唯一标识。连接并信任 iPhone，按系统提示启用开发者模式，选择该设备并运行。
5. 使用个人开发团队安装时，签名能力与有效期以 Xcode 当前提示为准。本仓库不包含签名证书、Team ID 或预签名 IPA。

**首次在 Mac 上请先构建和运行测试，再导入重要训练档案。** 不建议通过删除已有数据库来解决构建或迁移问题。

### 测试命令

```bash
# 仅纯 Swift 业务模块，可在有 Swift 的 Mac 上运行
swift test --package-path Packages/TrainLogCore

# 业务模块、SwiftData 集成、原生 UI 测试
bash Tools/test-ios.sh

# 或指定自己的模拟器
TRAINLOG_SIMULATOR_ID="你的模拟器 UUID" bash Tools/test-ios.sh
```

也可以在 Xcode 中按 **⌘U** 运行 `TrainLogTests` 与 `TrainLogUITests`。纯业务包测试由上面的 `swift test` 单独执行。可用 `xcrun simctl list devices available` 查看模拟器标识。

`.github/workflows/ios.yml` 定义完整测试、归档和可选预览版发布流程。当前真实执行状态见上方交付说明及 `Documentation/VALIDATION.md`。

## 已实现的功能源码

| 模块 | 内容 |
|---|---|
| 原生基础 | 四个 Tab、NavigationStack、系统动态字体、深浅主题、首次引导、统一卡片组件 |
| 概览 | 今天状态、本周目标、时长与组数、本月次数、近 30 天训练天数、最近 7 天、近期 PR |
| 人体图 | 18 个肌群、40 个独立前后/左右矢量区域、保持比例缩放、逐区点击、文字替代操作、VoiceOver、Reduce Motion |
| 快速记录 | 肌群图与标签双向选择、日期、时长、轻/中/高、会话 RPE、备注 |
| 详细记录 | 重量/次数/时长、RPE/RIR、正式/热身/递减/失败组、完成标记、复制组、加减重量/次数、组备注 |
| 草稿 | 本地恢复、500 ms 防抖保存、退到后台和关闭前保存、继续/放弃、保存错误提示 |
| 计时 | 训练计时与暂停、手动时长、组间倒计时、恢复截止时间、可选系统通知 |
| 动作库 | 37 个内置动作、主次肌群映射、搜索/肌群筛选、收藏、自定义动作与编辑、历史定义快照 |
| 模板 | Push/Pull/Legs、自定义、动作排序、组数、默认重量次数、复用上次配置、删除确认 |
| 历史 | 日期/肌群/动作筛选、详情、补记日期、编辑、删除确认、关联原始 PR 组 |
| 趋势 | 今日/7/30/90/365 天/全部、肌群四种指标、月历、可切年份活动图、次数/组数/容量/RPE 图表 |
| 力量 | Epley e1RM、实际重量/估算/同重量次数/会话容量 PR、每日曲线、两个 28 天周期、相对力量、六种动作模式代表动作 |
| 洞察 | 真实记录产生的肌群频率比较、近期缺失记录、数据充分程度；无随机评分 |
| 数据 | 版本化 JSON、校验与预览、合并/确认替换、导入前恢复副本、CSV、系统文件导出与分享 |
| 设置 | kg/lb、每周目标、训练目标、主题、体重历史、统计说明、隐私说明 |

以上表示**代码路径已经实现**，并不表示相应功能已在 iOS 上运行验收。

### 未实现及需后续验证的部分

- 可选增强：HealthKit、WidgetKit、长期报告导出、更多解剖细分。
- 没有手写 Liquid Glass API；使用系统导航、TabView 和原生材质，由系统 SDK/运行系统决定原生外观，因此不存在强制调用新系统玻璃 API 的兼容性问题。
- 当前支持中文界面及 iPhone，未单独设计 iPad 多栏布局和其他语言本地化。
- 未做 iOS 真机性能测试、VoiceOver 实机走查、超大字号/横屏截图验收、通知后台交付验收。
- 当前数据库只有 V1；已声明版本化 Schema 和 MigrationPlan，但尚无跨版本升级数据可验证迁移。
- 未运行 App Store 验证与签名归档。

## 人体图实现

`MuscleVectorData.swift` 存储归一化点位及左右镜像规则。`MuscleRegionShape` 使用圆角路径绘制，`BodyMuscleMapView` 保持 200:440 比例。点击优先匹配可见路径，再为小区域提供有限的边缘容差；同一位置不会同时触发多个肌群。

正面包含胸、前/侧肩、二头、前臂、腹直肌、腹外斜肌、股四头及小腿前侧；背面包含斜方肌、中上背、背阔肌、后/侧肩、三头、前臂、下背、臀、腘绳肌和小腿后侧。

下面是**从源代码点位渲染的几何审查图，不是 iOS 截图**。左侧明确是“选择胸部”的测试状态，右侧为无记录状态；不会向应用数据库注入示例训练。

![人体矢量几何检查](Documentation/muscle-vector-review.png)

## 统计口径

| 指标 | 规则 |
|---|---|
| 训练次数 | 完成的会话数量；草稿排除 |
| 训练天数 | 设备当前时区的自然日去重；同日快速与详细记录只计一次肌群训练日 |
| 覆盖 | 快速肌群记录，或有效已完成正式/递减组的明确主次肌群；热身/失败组排除 |
| 正式组数 | 仅已完成且数值有效的 `working` 组 |
| 相关组数 | 某肌群作为主要或次要肌群的正式组数，未加权 |
| 加权组数 | 每个正式组向主要肌群贡献 1.0，向次要肌群贡献 0.5；主次不重复 |
| 容量 | 适用正式组的外部负重 kg × 次数；双手同时的每只哑铃口径额外 × 2 |
| 主观强度 | 只使用明确填写的轻/中/高序数 1/2/3，先按日平均再按天平均 |
| RPE | 单独显示会话 RPE 的日平均；不把轻/中/高强行转换成 RPE |

加权组是分类近似值，**不是肌肉激活量或精准增肌刺激量**。不同器械或动作的容量不代表等效生理刺激。自重、辅助、计时动作不虚构容量；失败组可以记录 0 次，但不会产生工作组、覆盖、容量或 PR。

快速记录不创建组数、容量或 e1RM。无记录/缺失值使用中性色或“—”，不使用红色诊断训练不足。

热力分段为固定阈值，不按最大值归一化：

- 天数：0、1、2–3、4–6、≥7。
- 加权正式组：0、>0 且 <4、4–<8、8–<12、≥12。
- 覆盖：无/有。
- 主观强度：未填写、1、>1 且 <2、2–<3、3。

本周从周一开始，滚动范围包含今天。切换设备时区会改变自然日分组，但不更改原始时间戳。肌群图、列表、图表和训练总结调用相同的业务服务。

### 力量估算

使用 `e1RM = weight × (1 + reps / 30)`，例如 60 kg × 8 → **估算 76 kg**。1 次重复保留实际重量，不额外放大。仅采用：

- 已完成、有效、正式、外部负重组。
- 动作定义明确允许估算，重复次数为 1–10，重量 >0。
- 至少记录 RPE 或 RIR，RPE ≥8 或 RIR ≤2；两项都填时必须同时满足。

没有努力程度记录时不估算。自重、辅助、计时动作不估算。不同动作 ID、器械、记录模式或负重口径不合并比较。

周期比较使用最近 28 天和此前 28 天的“每日最佳 e1RM 平均值”，每个周期至少 2 个有效训练日。相对力量使用该训练日或之前 30 天内最近一次体重；无匹配体重则不显示。

PR 全部从现存原始记录派生，关联会话、训练组和日期；编辑/删除后自动重算，不维护会脱节的 PR 缓存。

## 存储、隐私与恢复

- SwiftData 本地持久化，禁用 CloudKit。默认数据库位于应用沙盒 Application Support 中。
- `WorkoutSession → SessionExercise → WorkoutSet` 与 `WorkoutSession → QuickMuscleEntry` 使用级联删除、可选反向关系。
- 动作库、模板、体重、设置是独立实体。训练动作保存定义快照及原定义 ID，避免编辑动作库改变历史结果。
- 原始重量始终用 kg；lb 系数为 `2.2046226218487757`。
- 主线程隔离的 `AppStore` 管理 ModelContext，显式保存，失败回滚。训练编辑使用值类型，历史只有点击保存后才写回。
- 草稿不参与统计。正常数字修改在 500 ms 防抖后落盘；无效输入保留在页面并明确提示尚未保存，不用上一数值冒充成功。系统在防抖窗口内强杀时，最近未落盘的编辑可能丢失。
- 启动数据库失败显示错误与重试，**不会静默删除数据库，也不会切换到临时内存库冒充保存成功**。
- 只在用户启用休息提醒时申请通知权限。无 HealthKit、相机、位置、网络或账号要求。
- 系统设备备份是否包含沙盒由 iOS 和用户设置决定；本应用没有自己的云同步服务。

JSON schemaVersion 为 1，日期使用 ISO 8601（秒精度）。完整备份含草稿、训练组、历史动作快照、动作库、模板、体重和设置。导入限制 32 MB，校验字段、数值、全局重复 ID、关联与版本。

合并保留本机设置，相同 ID 保留本机数据；重复导入不会增加副本。不同草稿冲突会要求先处理其中一份。替换操作必须确认，并在任何数据库修改前把当前档案写入 **Documents/Recovery**；可在“文件”App 的 TrainLog 文件夹中找到并再次导入恢复。

CSV 是分析明细，不用于完整恢复。重量列始终为 kg，包含完成状态及组类型；缺失容量留空，UTF-8 BOM、逗号/引号/换行正确转义，并防止文本被表格软件当公式执行。

## 工程结构

```text
TrainLog.xcodeproj/              原生 app、集成测试、UI 测试、共享 Scheme
TrainLog/
  App/                          启动、四 Tab、路由
  Core/Persistence/             SwiftData 实体、V1 schema、存储服务
  Core/DesignSystem/            卡片、数值、输入、空状态
  Core/Services/                休息计时与可选通知
  Features/                     概览、训练、动作库、历史、趋势、能力、肌群、设置
  Resources/                    图标、Info.plist、隐私清单
Packages/TrainLogCore/
  Sources/TrainLogCore/          值类型模型、校验、映射、统计、力量、PR、备份
  Tests/TrainLogCoreTests/       业务测试
TrainLogTests/                  持久化、恢复、级联删除、快照、导入、命中测试
TrainLogUITests/                快速记录闭环、草稿恢复、空状态导航
Tools/                          工程生成、静态检查、矢量审查、Mac 测试脚本
Documentation/                 验证状态、手工验收、矢量几何审查图
```

新增/移动 Swift 源文件后运行 `python3 Tools/generate_project.py` 更新工程引用。此脚本只使用 Python 标准库；日常 Xcode 构建不需要运行它。图标已经提交，`generate_assets.py` 仅供重新生成，使用 Pillow。

## 本次实际检查结果

检查日期：**2026-10-09（Asia/Shanghai）**。

- **35 个 Swift 文件：Tree-sitter Swift 语法解析通过，0 个解析错误。** 不是 Swift 编译器类型检查。
- **101 个 Xcode 工程对象：ID 唯一、内部引用完整，所有 app/test 源文件已加入 target。** 尚未由 Xcode 加载确认。
- Info.plist、PrivacyInfo.xcprivacy、共享 Scheme、workspace XML、资产 Contents.json 格式检查通过。
- 从真实矢量点位生成并目视检查前后视图、胸部选择测试状态及中性状态。该结果只覆盖路径几何，不覆盖 SwiftUI 真机渲染。
- **31 个 XCTest 测试方法已编写：22 个业务测试、6 个持久化/肌群集成测试、3 个 UI 测试。均未运行。**
- Xcode 构建、模拟器、真机、通知后台交付、VoiceOver、动态字号、性能、签名安装：**未验证**。

详见 [`Documentation/VALIDATION.md`](Documentation/VALIDATION.md) 与 [`Documentation/ACCEPTANCE.md`](Documentation/ACCEPTANCE.md)。

工程实现参考 Apple 官方的 [SwiftData 持久化说明](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)、[ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration) 和 [文件导入 API](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:))。

