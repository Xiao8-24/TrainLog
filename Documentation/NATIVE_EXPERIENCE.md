# 原生日历与交互改进 · 0.2.0

## 日历

- 四个主页面右上角固定提供“健身日历”，无需已有训练或先滚动到趋势底部。
- 月历使用 Apple `UICalendarView`：系统月份/年份切换、日期选择、字体及辅助功能行为。SwiftUI `DatePicker` 提供直接跳转日期。
- 查看日期没有“最近 30 天”或 2000–2030 年过滤；未来日期正常展示空状态。记录训练仍不允许未来日期。
- 圆点和当天列表均从全部已完成记录按设备当前日历及时区建立索引；草稿不计入。编辑、删除和导入会刷新结果。
- 选中日期通过 SceneStorage 保留，重新打开继续查看；“今天”随时返回当天。前后一天使用 Calendar 运算，避免夏令时固定 24 小时偏差。
- 前台每 30 秒，以及返回前台、系统显著时间变化、时区和区域设置改变时刷新日期依赖。切换时区后日期归属按新时区重算。

## 原生交互

- 使用系统 NavigationStack、TabView、sheet、确认对话框及原生日历转场。
- 组展开/增删、完成状态、肌群选择使用 SwiftUI smooth 动画；开启“减少动态效果”时关闭自定义动画。
- 组完成和肌群选择使用系统 sensoryFeedback，取消组完成不触发成功反馈。
- 编辑页支持交互式收起键盘；历史修改取消前确认，禁止滑动关闭造成未保存内容丢失。
- List 中使用系统导航箭头，避免双箭头；破坏性滑动操作不允许整行滑动直接触发。

## 验证

新增日期索引回归测试覆盖远期历史、未来空状态、草稿排除、午夜、时区变化、春秋夏令时、闰日、跨年和编辑/删除刷新；增加日期时钟集成测试、四页面日历入口与选中日期恢复 UI 测试。原快速记录保存测试同时检查日历中的记录。

运行 `bash Tools/test-ios.sh` 获取真实结果。UI 测试附件中的截图为模拟器测试数据。真机触感、VoiceOver、最大辅助字号、横屏和不同 iOS 版本的视觉验收仍须按 ACCEPTANCE.md 执行，测试代码本身不代表已验收。

系统样式随 iOS 版本而变化。没有仿制私有动画或强制覆盖系统导航转场；当前最低版本仍为 iOS 18。

参考：[Apple UICalendarView](https://developer.apple.com/documentation/uikit/uicalendarview)、[SwiftUI SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback)、[Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)。
