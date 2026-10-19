# 有氧与 Apple Watch · 0.7.0

最低 iOS 27 / watchOS 27，使用 Xcode 27。Windows 预览仍为此前的交互演示，不模拟手表传感器或健康授权。

## 运动记录

力量动作由 37 扩为 **128 个**，保留原始稳定 ID 和负重口径；新增胸背肩臂、腿臀、小腿前侧及核心动作，支持器械、肌群、收藏与中英文搜索。升级只补缺失项，保留收藏、归档、自定义名称与历史快照。

「训练 → 有氧与其他运动」提供 **38 种**类型：室内外跑走骑、泳池/开放水域游泳、划船机、椭圆机、爬楼机、跳绳、徒步、间歇、拳击、舞蹈、球类、滑雪、瑜伽和普拉提等。并非全部属于有氧运动，不将瑜伽和力量项目判定为有氧适能。

手动记录支持计时/暂停、补录日期、手动时长、适用距离、RPE 与备注；由有效距离和活动时长计算平均配速/速度，不虚构分段、热量或心率。运动计入日历、历史、整体次数/时长、小组件和运动趋势；不生成肌群覆盖、力量组、容量、力量 PR 或 e1RM。手机计时运动支持锁屏实时活动和灵动岛。

## 原生手表训练

在 iPhone「训练 → Apple Watch 训练」选择项目并准备，或直接打开手表 TrainLog。开始始终需要手表操作和健康授权。泳池游泳需确认泳池长度。使用系统 `HKWorkoutSession`、`HKLiveWorkoutBuilder` 与实时数据源，后台采用 workout-processing 模式。

0.6.1 将运动类型与泳池长度改为原生导航列表，显示当前选中项，避免滚动容器内默认选择器高度压缩。系统绿色开始按钮与原生字体保留，大段说明可滚动查看。

显示活动计时、暂停/继续、心率、系统估算活动能量及可读距离；没有读数保持缺失。数据取决于运动类型、设备与授权；例如没有距离来源的室内单车不会生成距离。App 不额外实现 GPS 路线采集。手机可查看最近手表状态，超过 20 秒标记为未更新，避免旧心率冒充实时心率。训练控制保留在手表。

完成后先保存 HealthKit 原件，再把训练与心率明细写入受保护的离线发件箱，通过 WatchConnectivity 文件传送。手机事务提交后才确认，确认前保留手表副本。收据防止重复消息覆盖历史，并在本机删除后防止迟到消息复活记录。手机草稿不妨碍接收完成的手表记录。

手表直接开始时创建独立运动记录。0.7.0 支持先在手机力量草稿中明确连接手表，再由手表开始采集；结果回传后附加到原逐组训练，避免另建第二条手机记录。不按日期或名称猜测合并。两端保留各自的真实计时，手机完成不会自动结束手表采集。连接、取消、恢复和删除的完整规则见 [已批准功能 A](APPROVED_FEATURES.md)。

系统意外退出可恢复活动训练并重连数据源。健康已保存、发送前退出的摘要可按稳定同步标识找回；恢复前的细分心率可能不在 TrainLog 曲线中，完整明细留在健康。保存失败显示错误并可重试；无法恢复的标记仅在用户明确确认后清除，健康原件保留。

## 分析边界

- 单次分析提供时长、适用距离、平均配速/速度、平均/最高心率、心率采样图及活动能量。曲线约每 10 秒最多一条、上限 10000 条，暂停与缺失不补值；平均/最高值取系统统计。
- 活动能量为 Apple Watch 系统估算，单位千卡，不包含静息能量；没有数据不套用年龄、体重、主观强度或通用 MET 公式。
- 有至少两次可比历史时，比较同类型、配速差不超过 5%、距离差不超过 20%、时长至少 10 分钟的最近最多五次手表记录的平均心率。此筛选用于描述差异，不是医学阈值；不把天气、疲劳、地形等混杂因素导致的变化直接解释为有氧能力变化。
- **有氧适能使用 Apple 健康已有 VO₂ max**，显示日期、来源和前一次可读值的变化，不从单次心率、配速或血氧推导，不生成诊断或随机评分。Apple 不保证每次第三方训练都产生新估算。
- **血氧是已有静止测量参考**，不连续采集，也不提供第三方即时启动测量接口。标注日期、来源与“不是本次运动中的血氧”；设备、地区与年龄等限制由 Apple 决定。
- 参考只查询不晚于训练结束的样本：血氧近 30 天、VO₂ max 近 180 天，排除手动输入标记。HealthKit 不向 App 揭示拒绝读取与无数据的差异，空状态说明多种原因。
- 参考读取须另行主动授权，可停止 App 内读取，在健康中撤销系统权限。血氧/VO₂ max 只用于查看，不存入 TrainLog 数据库或备份。

## 健康副本与隐私

手机手动记录经可选授权，以对应 HealthKit 类型导出时间和时长；手动距离留在本机，不伪造关联距离样本。原同步队列继续支持编辑、重试和删除管理副本。

Watch 负责保存手表训练，手机禁止再次导出。独立手表记录在手机只读；关联力量记录仍可修改组数与备注，传感器附件和健康原件保持不变。手机删除只移除 TrainLog 副本，健康原件由用户在健康中管理。Apple 决定健身摘要、圆环与健康同步，本 App 不写入圆环数值。

心率与能量随手表训练保存在本机并进入 JSON 备份；CSV 增加运动、距离、能量、平均/最高心率、来源和 Watch 健康标识，明细心率仅在 JSON 中。界面提示导出文件含健康信息。数据不发送到 TrainLog 服务器，配对设备通过系统 WatchConnectivity 传送。

## 升级、签名与验收

SwiftData V1 实体保持原样；V2 增加扩展数据与接收收据表，轻量迁移并保留原数据库路径。JSON 新导出版本为 2，继续读取版本 1。旧版 App 不能读取新运动模式，请使用当前版本导入。

分别签名三个产品：`com.trainlog.personal`、`com.trainlog.personal.TrainLogWidgets`、`com.trainlog.personal.TrainLogWatch`。主 App 与 Watch 启用 HealthKit，主 App 与 Widget 使用同一 App Group；Watch 不需要 App Group。更换 Bundle ID 时同步修改 Watch 的 WKCompanionAppBundleIdentifier。共享 TrainLogWatch scheme 可直接构建，IPA 必须包含 `Watch/TrainLogWatch.app`。

自动化覆盖目录、校验、备份、CSV、统计隔离、健康防重、SwiftData V1→V2、目录升级保留选择、手表导入幂等/删除防重、手机有氧记录→完成→日历。归档验证 Watch/Widget 均嵌入且版本一致。

需签名配对真机验收：授权与撤销、真实心率/能量/距离、熄屏后台训练、泳池长度、断线重连/锁定接收、训练恢复、健康/健身摘要与圆环、参考值可用性、电池及帧率。模拟器和替代数据不能证明这些结果。

## Apple 官方依据

- [实时训练构建器](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder)
- [从 iPhone 打开 Watch 训练](https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:))
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity/wcsession)
- [运动类型](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype)
- [血氧测量、静止要求与可用性](https://support.apple.com/en-us/120358)
- [VO₂ max 类型](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/vo2max)
