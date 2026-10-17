# Liquid Glass 与 iOS 27 · 0.3.0

## 原生实现

使用 Xcode 27 / iOS 27 SDK 构建，最低部署版本保持 iOS 18。导航栏、类型化 Tab、工具栏、sheet、菜单、选择器及 UICalendarView 由系统绘制；不设置旧设计兼容开关，不覆盖导航栏背景或模拟玻璃动画。

- 开始训练、继续训练等主要操作采用系统 `glassProminent` 和胶囊形状，由系统处理按压与光学效果。
- 休息计时浮层采用 `glassEffect(.regular)`，不叠加第二层玻璃按钮。`safeAreaBar` 为浮层预留空间并提供系统滚动边缘效果。
- 系统“减少透明度”开启时，自定义浮层切换到不透明语义背景；系统玻璃控件自行响应系统辅助功能与玻璃外观偏好。不提供仿制的应用内透明度滑杆。
- 保留既有“减少动态效果”支持。大辅助字号下，休息浮层改为纵向排列，结束按钮至少 44 点。
- 训练卡片、图表、人体图是内容层，保留语义背景与清晰文字，不铺满玻璃。
- iOS 18 使用系统 borderedProminent / regularMaterial / safeAreaInset 回退。编译条件允许旧 SDK 验证兼容路径。

## 构建和验证

主 CI 使用 GitHub 官方 `xcode-27` 镜像，显式选择 Xcode 27.0，要求 iOS SDK 与模拟器运行时至少 27。缺少环境时直接失败，不把 iOS 18 结果当成 iOS 27 验收。该 runner 标签由 GitHub 标记为 preview，实际工具链记录在 BUILD-ENVIRONMENT.txt。

当前只以 Xcode 27 / iOS 27 测试与归档作为发布门槛，已按项目要求移除旧系统持续验证任务。UI 测试保留浅色/深色概览、休息浮层、大辅助字号和日历截图，供视觉复核。测试源码本身不是通过证据，实际结果见 Actions。

真机玻璃折射与帧率、系统玻璃外观滑杆、减少透明度/增加对比度/减少动态效果组合、VoiceOver 和横屏仍需设备验收。应用图标目前保留现有 asset catalog，尚未制作 Icon Composer 分层图标。

## 官方依据（2026-10-14 查阅）

- [Apple：Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Apple HIG：Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple：glassProminent](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent)
- [Apple：Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Apple：Xcode SDK 与系统要求](https://developer.apple.com/xcode/system-requirements)
- [GitHub：Xcode 27 runner](https://github.com/actions/runner-images/issues/14404)
