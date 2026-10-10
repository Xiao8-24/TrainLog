TrainLog 原生 iOS 预览版，最低 iOS 18。

包含快速/详细力量训练记录、前后肌群图、动作库与模板、训练历史、趋势、e1RM/PR、体重记录、JSON 备份和 CSV 导出。数据保存在设备本地。

此自动发布流程要求纯 Swift 业务测试、SwiftData 集成测试、UI 测试及 Release 设备归档全部成功。具体提交与工具链见 BUILD-ENVIRONMENT.txt；测试证据见对应 Actions 的 diagnostics 附件。

- `TrainLog-iOS-source.zip`：完整源码工程。
- `TrainLog-unsigned.ipa`：**未签名**的设备构建，不能直接安装到 iPhone。需要适用的 Apple 证书和描述文件完成签名。
- `SHA256SUMS.txt`：下载文件校验值。

尚未完成真机、辅助功能、通知后台交付和性能验收。这不是 App Store 或 TestFlight 发布。
