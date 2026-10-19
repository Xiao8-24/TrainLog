# 0.8.1 原生动效优化

## 交互与视觉

训练编辑页不再因休息显示状态变化而向整页传递动画；动作插入/删除仅在动作区域中处理。底部正在训练与组间休息共用一个稳定的系统玻璃表面，切换时保留容器，以短系统动画调整内容和高度；出现/消失用透明度过渡，没有自定义缩放或弹跳。系统导航、弹窗、键盘和按钮按压仍交给SwiftUI。

完成勾选、暂停/继续和展开箭头使用系统SF Symbols替换转场，完成行的浅绿色背景只在背景修饰范围内平滑变化，不给整行输入附加完成动画。预设组数进度使用系统数字转场。逐组控制区、更多选项和动作列表的动画只观察对应离散状态；不观察整个训练快照。

每秒计时仍由独立系统文本或局部TimelineView负责，计时标签和数字输入屏蔽继承的动画，避免每次变化驱动父级玻璃布局；没有新增每秒更新整页的定时器。展开、收起本组更多选项后，重量、次数和备注保留。暂停时底部准确显示“本组已暂停”，不再保持“进行中”文案。

## 辅助功能与验证

系统“减少动态效果”下，以上应用自定义动画与符号替换关闭；大辅助字号继续使用纵向控制布局，主要操作至少44pt高。“更多选项”明确提供展开/折叠值。系统“减少透明度”保留原有实色玻璃回退。

新增两条原生UI回归：展开/收起后输入保留、运行组暂停/继续、完成后同一浮层切换休息和结束休息；第二条同时使用最大辅助字号和减少动态效果的DEBUG环境覆盖。覆盖只在隔离UI测试参数下生效，不改系统设置，也不代表已验证所有设备辅助功能组合。最终结果、截图范围与发布文件校验以[验证记录](VALIDATION.md)为准。

本轮不改变数据库、备份版本、健康写入或Watch采集控制。不以模拟器用例或截图承诺120Hz、真机无掉帧或功耗，仍需配对设备和Instruments检查。

## 官方依据

- [局部动画 animation(_:body:)](https://developer.apple.com/documentation/swiftui/view/animation(_:body:))：将背景动画限制在修饰范围，避免输入一同参与。
- [系统符号替换](https://developer.apple.com/documentation/symbols/replacesymboleffect)：沿用系统符号过渡，不增加循环装饰动画。
- [Liquid Glass 自定义控件](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)：使用系统材质和控件，玻璃用于操作层。
- [SwiftUI 性能](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)：缩小观察和更新范围，计时保持局部更新。
