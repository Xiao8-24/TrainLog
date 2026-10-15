# 桌面小组件与训练实时活动

## 信息设计

「训练日程」小号显示今日完成次数、分钟与有效正式组，并提供开始训练／继续草稿入口；中号增加本周目标进度、七天完成标记及独立日历入口。锁屏矩形展示本周目标和草稿提示。无数据时如实显示零，首次同步或设备尚未解锁时提示打开 App。小组件不显示体重、备注或完整训练明细。

详细训练的 Live Activity 同时支持锁屏、灵动岛紧凑、最小和展开布局。训练中显示累计计时，暂停时冻结计时；休息时优先显示倒计时与有效正式组数；休息到点以系统 stale 状态显示「休息结束／就绪」。点击回到原草稿，完成或放弃后立即移除。快速记录和历史编辑不创建实时活动。长时间没有更新的训练显示更新提示，不把过期数据伪装成实时信息。

## Apple 原生行为

- WidgetKit 管理刷新、系统边距和背景；使用 `containerBackground`、语义颜色及 `widgetAccentable` 适配着色模式和系统玻璃外观，不在小组件内叠加自制玻璃。
- ActivityKit 管理展示和生命周期；倒计时使用系统 `Text(timerInterval:)`，不依赖 App 后台每秒唤醒。`staleDate` 负责休息到点后的状态，通知声音仍由独立的可选休息提醒控制。
- 无服务器和推送 token，不请求频繁更新权限。新活动仅在前台且系统允许时创建；用户移除后不自动反复弹出。设置内关闭会结束当前活动，重新启用允许恢复当前草稿。
- 深链接只识别已定义的训练与日历路径。已删除草稿的旧链接不会创建新记录；编辑过程中不覆盖当前未保存输入。
- 系统控制小组件刷新时机，不能承诺每次保存后立刻刷新。时间线提前生成七个本地午夜条目，跨天可自行切换统计；按当前日历和时区计算。

## 数据与签名

主 App 原子写入 App Group 的版本化 JSON 摘要，扩展只读，不直接打开 SwiftData 数据库。文件使用首次解锁后可读取的保护级别；读取失败时显示可理解的空状态。修改、删除、导入与设置更新后重新生成摘要，并请求刷新。核心数据仍只在主 App 中修改。

签名需要两个 Bundle ID：`com.trainlog.personal` 与 `com.trainlog.personal.TrainLogWidgets`，两者同时启用 `group.com.trainlog.personal` App Group。若团队使用其他标识，需同步修改两个 entitlements 和 `Shared/WidgetSnapshotStorage.swift`。设备归档仍未签名；必须同时签名主 App 与内嵌 `PlugIns/TrainLogWidgets.appex`。模拟器测试使用 ad-hoc 签名，不需要 Apple 开发者证书。

## 验证范围

核心用例覆盖午夜、跨周和夏令时、草稿排除、有效正式组、暂停、休息过期、完成状态、序列化、删除记录和非法深链接。工程检查验证相同 App Group；归档检查验证扩展存在、版本一致和 Live Activities 声明。云端结果见 VALIDATION.md。

仍需已签名 iPhone 验收：在主屏幕添加各种尺寸、浅／深／着色／透明外观、VoiceOver 与辅助字号；锁屏隐私；灵动岛紧凑／展开／多活动最小显示；后台倒计时到点；系统禁止和手动移除实时活动；重启后首次解锁；实际签名团队的 App Group 数据共享。模拟器构建成功不能替代这些验证。

## 官方依据

- [Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [ActivityKit 生命周期与 staleDate](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [WidgetKit 时间线与刷新预算](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [小组件背景与系统渲染](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
