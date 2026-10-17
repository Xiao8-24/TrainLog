# TrainLog Windows 交互预览

在源码中，双击 **打开 TrainLog.cmd**，或直接用 Edge / Chrome / Firefox 打开 **index.html**。不需要安装依赖、开发环境或连接网络。源码版需要保留同目录的 CSS 和 JavaScript 文件。

打包交付版位于 `Delivery/TrainLog-Windows-Preview.zip`，解压后双击 **打开 TrainLog.cmd** 即可；也可以直接打开独立的 **TrainLog-Windows-Preview.html**。打包后的 HTML 已包含全部资源，可以单独移动。运行 `python Tools/package_windows_preview.py` 可重新生成交付文件与校验值。

可以体验四个标签页、原项目的 37 个动作和 40 个人体矢量区域、详细／快速记录、完成组、训练暂停、组间休息、草稿重开、任意日期日历和小组件／灵动岛状态变化。右上角可切换浅／深色，设置内可调整单位和每周目标。

首次打开包含明确标注的演示记录。设置内可以清空，或重新载入演示。预览数据只写入浏览器的本地存储，关闭后可继续；浏览器拒绝本地存储或使用隐私模式时，可能无法保留。移动文件夹或更换浏览器可能使用新的存储位置。

这是 **Windows 浏览器中的交互预览**，并非 SwiftUI 的 Windows 移植。系统玻璃和动画使用 CSS 近似呈现；右侧组件与手机上方灵动岛用于展示布局及状态逻辑，不会注册成 Windows 或 iOS 的系统组件。没有接入系统通知、HealthKit 或 iPhone 数据库。

导出的 JSON 仅用于保留此预览的数据，**不是原生 iOS 版的备份格式**。数据不会自动同步到 iPhone。

开发检查：`node --test Tools/check_windows_preview.cjs`。动作与矢量数据通过 `python Tools/generate_windows_preview_data.py` 从原生源码生成。iOS 应用仍以 Swift 源码和原生设备验证为准。

DOM 交互检查：安装开发依赖 `npm install --no-save --prefix .tools/windows-preview-test jsdom`，启动 `python Tools/serve_windows_preview.py`，另开终端运行 `node Tools/check_windows_preview_ui.cjs`。依赖仅用于开发检查，不进入交付包。已验证动作搜索、完成组、实时活动状态、休息与暂停、关闭重开草稿、保存、日历跳转至 2040 年、快速记录、主题与单位、清空确认和模板。另以 Chromium 检查了离线 HTML 的浅色概览及深色训练界面；这不替代 iOS 原生验收。
