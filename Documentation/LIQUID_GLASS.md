# 三端液态玻璃视觉

iOS、Android、Windows 共用蓝色强调、浅蓝／薄荷／淡紫背景色、26 点内容圆角和 20 点间距。浅色与深色自动切换，保留系统字体与平台操作习惯。

- iOS：系统 TabView、工具栏、主操作按钮和浮动控制使用原生 Liquid Glass。内容卡片采用清晰的珠光底色、细高光和轻阴影。背景不持续运动。
- Android / Windows：导航栏、桌面侧栏和继续训练浮层使用裁剪范围内的背景模糊、半透明填色与边缘高光。使用 Flutter 近似视觉，不能等同于 Apple 私有的折射渲染。内容卡片不做逐卡背景模糊，以控制滚动开销。
- 导航悬浮在内容上方，滚动区域预留底部空间；继续训练控件避开底部导航与系统安全区域。
- iOS 跟随减少透明度与增强对比度；Flutter 在系统报告高对比度或辅助导航时使用实色。Flutter 尚未覆盖所有系统的减少透明度设置。
- 页面切换采用 260 毫秒缓出／缓入过渡，按钮采用短状态反馈；系统要求减少动态效果时关闭这些自定义过渡。iOS 的系统控件动效由系统控制。

本轮只改变呈现与布局，不改变记录、计时、备份或账户同步协议。

依据：[Apple Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)、[Flutter BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)。模糊限制在少量固定表面，重叠表面不共用 backdrop key。
