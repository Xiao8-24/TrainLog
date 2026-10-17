# Apple 健康与原生体验 · 0.5.0 历史实现

**0.6.0 已扩展为有氧与原生 Apple Watch 训练。当前权限、传感器数据、备份与签名规则以 [有氧与手表说明](CARDIO_AND_WATCH.md) 为准；下文保留 0.5.x 的手机导出实现背景。**

本版以 iOS 27 / Xcode 27 为部署与验证目标，最低部署版本升为 iOS 27。HealthKit 是系统健康数据库的授权接口，不是「通过 Apple 登录」，也不需要 TrainLog 账号。授权后保存的 HKWorkout 可由系统健康与健身 App 展示；这不是 Fitness+ 内容接入或 Apple Watch App。

## 使用方式

1. 使用启用 HealthKit 能力的 Apple 团队为主 App 签名；同时保留两个 target 的 App Group 配置。小组件扩展不申请健康权限。重新生成主 App 描述文件，不能沿用不含 HealthKit 的旧描述文件。
2. 在 TrainLog「设置 → Apple 健康」打开同步，允许写入「体能训练」。拒绝授权或关闭连接不影响本机记录。
3. 新完成的训练保存到本机后，异步写入传统力量训练类型、时间与有效记录时长。不读取健康数据库中的其他来源；不采集、估算或写入心率、活动热量、体重或圆环数值。
4. 在完成页与历史详情查看每条记录的写入状态。历史不会首次连接时全量上传，可逐条核对时间与时长后写入。零时长、未完成和无效日期不能导出。
5. 在 Apple 健康的「体能训练」数据中查看来源为 TrainLog 的记录，并在 Apple 健身的训练摘要中检查展示。系统决定展示、活动圆环、刷新和设备间同步；未使用设备实测的数据不会被补造。若 Apple Watch 已记录同一训练，请避免同时写入另一份。

## 时间、更新与重试

自动计时保留训练开始与结束之间的墙钟跨度；HKWorkout.duration 只使用计时累计值，排除暂停。手动/快速记录采用明确填写的时长。历史选择的日期作为开始时间；刚补录的一次训练若由此会结束于未来，则以记录保存时的完成时间结束并向前保留填写的时长。详情卡片会先展示实际导出的起止时间。重试不随当前时间推移改变摘要。

每次训练使用 `com.trainlog.workout.<Session UUID>` 作为 HealthKit 同步标识，以递增版本更新同一记录。队列先写入受文件保护的本机 Application Support 文件，再调用 HealthKit，成功后记录确认；重开 App 或保存成功后的确认失败会复用原版本。编辑或删除发生在写入过程中时，旧回调不能覆盖新意图。连接开启且授权有效时，删除和替换导入会移除已受管理的 TrainLog 健康副本，不会操作其他来源。修改后时长无效时移除旧摘要，待补全后重试。

关闭连接时不再开始新的健康操作；已提交给系统的操作仍可能完成。已写入副本不会因关闭连接被清除。离线编辑/删除已管理记录会在重新连接后协调；未授权、设备锁定等失败会保留待处理任务，供下次前台或主动重试。用户在健康 App 中主动删除副本后，TrainLog 不轮询重建；本地「已写入」代表最近一次系统保存成功，不能证明健康副本此刻仍在。

健康授权、同步队列与写入确认不随 JSON 备份导入/导出，不要求 SwiftData Schema 迁移，数据库保持原位置。本机导入不是 HealthKit 的双向同步；导入后不会自动上传陌生的历史 ID。

## 字体、动画与刷新

- 使用系统默认字体设计、语义字号和 Dynamic Type，统一主要标题为 semibold；小组件数字移除 rounded 字体设计并使用等宽数字。
- 保留系统 TabView、NavigationStack、sheet、确认面板、按钮和 Liquid Glass API；去除旧系统玻璃分支，减少透明度时使用不透明系统材质背景。
- 离散选择/组增删使用系统 snappy 动画；统计数字使用 numericText，跟随「减少动态效果」关闭插值。
- 训练运行计时改为系统托管的 timer Text；组间计时仅更新独立数字子视图，玻璃浮层不再每秒重建。
- 训练长列表按需创建视图；上次动作配置直接使用已有顺序，避免输入时反复排序全部历史。完成页不再添加人为等待。

这些是源码中的刷新与交互改进，不等于已测得 120 fps。真实掉帧、发热、VoiceOver、大字体、减少动态效果与健康/健身跨 App 展示仍需签名 iPhone 和 Instruments 验收。

## 官方依据

- [HealthKit 设置与能力](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)
- [授权与写入状态](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [HKWorkout、时长与圆环规则](https://developer.apple.com/documentation/healthkit/hkworkout)
- [HealthKit 同步标识](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier)
- [删除仅限本 App 写入的对象](https://developer.apple.com/documentation/healthkit/hkhealthstore/deleteobjects(of:predicate:withcompletion:))
- [Liquid Glass 原生组件与辅助功能](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [减少不必要的视图刷新](https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency)

自动化检查包括纯业务的日期/时长、队列持久化与迟到回调规则，以及使用替代 Health 客户端的拒绝授权、失败重试、写入前后落盘失败、同步中删除、断开后编辑和替换导入测试。UI 测试使用隔离环境，不弹出真实健康权限，也不向真实健康数据库写数据；不能据此声称真机健康接入已经验收。
