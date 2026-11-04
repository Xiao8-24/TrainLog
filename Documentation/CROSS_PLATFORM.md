# TrainLog Android 与 Windows 客户端

0.10.0 为新增平台的预览版本。iOS / watchOS 继续使用现有原生工程，平台客户端位于 `CrossPlatform/`，采用 Flutter 3.47.8。

## 能力与操作

- 128 个力量动作与 38 类运动，肌群搜索与稳定动作 ID 和 iOS 一致。
- 正反面人体肌群分布，复用 iOS 的 40 块矢量区域。统一概览按周一开始的本周统计主次肌群训练天数，同一天去重，包含快速记录及已完成正式／递减组；固定颜色阈值，不将颜色解释为恢复状态。
- 边练边记：编辑每组重量、次数或持续时间，可填写 RPE / RIR；开始、暂停、继续和完成每组，整体训练同步计时。
- 整体与组计时使用已保存的时间戳，不依赖每秒回调累计。返回页面或进入后台继续计时，暂停时间不计入训练时长。
- 日期训练计划，可预设动作、组数、重量、次数、时长和休息。开练时冻结目标，历史复盘保留计划与实际。
- 始终可用的健身日历，可按月翻页或跳转日期，查看历史与提前安排训练。
- 后台 SQLite 事务保存，采用 WAL 与 FULL 同步；提交成功才更新界面，保存错误保留原记录。损坏的数据库不会被主动清空；另一个进程持有记录文件时不打开第二个写入窗口。
- Android 使用底部导航，Windows 宽窗口使用侧栏与系统窗口边框，计时数字独立刷新，页面过渡遵从系统减少动态效果。
- 设置中手动导出 / 导入 iOS 格式 JSON 1–5；导入是替换操作，先校验再确认，建议先导出本机资料。旧 Windows 浏览器预览的 JSON 不兼容。

本版重量以 kg 编辑；导入的 lb 偏好、模板、体重、Apple 来源与关联资料继续随备份保留。模板和体重尚无独立编辑页面。iOS 已有的下次目标建议、Watch、HealthKit、小组件与快捷指令仍使用 iOS 原生版本；Android / Windows 未接入这些系统能力，不生成假心率、血氧、VO₂ max 或热量。手动有氧记录时长和适用运动的距离；导入的 Watch 原始测量值可以查看及再导出。

没有自动跨设备同步。修改一台设备的记录不会自动更新另一台，导入前请确认哪份资料需要保留。

## 安装包

构建和测试全部通过后，GitHub 预览发布提供：

| 文件 | 用法 |
| --- | --- |
| `TrainLog-v0.10.0-Windows-x64.zip` | Windows 10 / 11 x64；完整解压后运行 `TrainLog/trainlog.exe`，保留 DLL 与 `data/`。包内包含 VC++ 运行库。 |
| `TrainLog-v0.10.0-Android-arm64-v8a-preview.apk` | Android 7.0 / API 24 以上的主流 64 位手机。 |
| `TrainLog-v0.10.0-Android-armeabi-v7a-preview.apk` | 支持的 32 位 ARM 设备。 |
| `TrainLog-v0.10.0-Android-x86_64-preview.apk` | 64 位 x86 Android 设备或模拟器。 |
| `TrainLog-v0.10.0-source.zip` / `SHA256SUMS.txt` | 测试提交的源码与发布文件校验值。 |

Windows 程序未作商业代码签名。Android 是 release 模式编译、开发证书签名的测试 APK，不是应用商店生产签名；不同 CI 构建的开发签名可能不同，升级时可能需要先导出备份、卸载旧版、安装新版并导入。不要把 CI 生成的开发密钥作为生产身份使用。后续正式商店发布需要配置长期签名密钥。

资料位于系统分配的应用支持目录，与解压文件夹分开。删除 Windows 程序文件不会迁移或清除记录。Android 不申请广泛存储、健康或传感器权限，JSON 导出使用系统文档选择器；默认关闭系统云端自动备份，卸载前请主动导出。

## 开发与验证

固定 Flutter 3.47.8，Android 构建使用 JDK 17 与 Android SDK，Windows 构建使用 Visual Studio C++ 桌面工具链。

```text
python Tools/generate_cross_catalog.py
cd CrossPlatform
flutter create --platforms=android,windows --project-name trainlog --org app.trainlog --no-pub .
cd ..
python Tools/bootstrap_cross_platform.py
cd CrossPlatform
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build apk --release --split-per-abi
flutter build windows --release
```

原生 runner 由固定 SDK 的标准模板生成，项目脚本应用 API 下限、文档导出、禁用云备份和窗口名称配置；定制源码在 `platform/`，不要直接修改忽略的生成文件。数据库和构建产物均不入库。

`.github/workflows/cross-platform.yml` 分别在 Linux 和 Windows 上执行分析、数据/恢复/交互测试及 release 构建，检查 APK 签名，Windows 打包完整运行目录。普通提交只构建；以 `Release cross v0.10.0` 开头的主分支提交，或手动选择 publish，才会在两端通过后发布预览版。

发布门槛包括 Linux 和 Windows 构建、自动记录测试、Windows 原生窗口的逐组记录与数据库重启测试、Android 模拟器交互和 release APK 启动、以及 Swift 与 Dart 的双向备份解码。发布资产附带 Windows 真实测试窗口截图，文件名包含 `test-data`。真实手机和电脑的安装、系统文档选择器及主观流畅度仍需设备体验验证。
