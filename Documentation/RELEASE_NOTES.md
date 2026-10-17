TrainLog 0.5.1 · Apple 健康与原生体验预览版

最低 iOS 27，使用 Xcode 27 / iOS 27 SDK。

新增可选 Apple HealthKit 连接：授权后，新完成的力量训练异步写入训练类型、起止时间与记录时长，供 Apple 健康和健身 App 展示。默认关闭，不需要注册或 Apple 登录。历史记录可逐条确认后写入；提供同步状态、待处理重试、编辑更新和已管理 TrainLog 副本删除。稳定同步标识与持久化版本避免重试时重复新增；编辑或删除意图暂时无法落盘时，暂停旧版本提交，恢复后再写入最新摘要；不读取其他来源，不采集或估算心率、热量或圆环进度。具体展示与设备间同步由 Apple 系统决定；请避免与 Apple Watch 的同一场训练重复写入。

统一系统字体设计、语义字号与标题字重；使用系统计时文本，休息浮层只刷新数字，训练长列表按需创建，避免输入时重复排序历史。系统数字转场、选择动画及减少动态效果保持一致。保留原生 Liquid Glass 导航、按钮、浮层及减少透明度适配，不再维护旧系统玻璃回退分支。

训练数据保留原 SwiftData 位置，无需迁移已有 Schema。HealthKit 权限与同步队列不进入 TrainLog JSON 备份；不批量上传初次连接或导入的历史。详见 Documentation/APPLE_HEALTH.md。

自动发布要求纯 Swift 业务测试、持久化与健康队列测试、原生 UI 测试、Release 设备归档全部通过。健康队列测试使用替代客户端，UI 测试隔离真实健康数据库，不代表健康与健身的真机跨 App 验收。系统动画掉帧和发热仍待签名 iPhone / Instruments 验证，不声称已达到特定帧率。

文件：TrainLog-iOS-source.zip 为完整源码；TrainLog-unsigned.ipa 为未签名设备构建，不能直接安装。签名时，主 App 启用 HealthKit，主 App 与 Widget 扩展均配置相同 App Group 并分别签名。Apple 健康写入仍需设备内主动授权。本版本不是 App Store 或 TestFlight 发布。