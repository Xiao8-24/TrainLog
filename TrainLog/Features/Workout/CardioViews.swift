import SwiftUI
import Charts
import TrainLogCore

struct CardioEditorCard: View {
    @Binding var activity: ActivityRecord
    var body: some View {
        AppCard {
            SectionHeader(title: "运动记录", subtitle: "时长为必填；距离可留空，不自动估算热量")
            Picker("运动类型", selection: $activity.kind) {
                ForEach(CardioActivity.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
            }.accessibilityIdentifier("cardio.kind")
            if activity.kind.supportsDistance {
                HStack {
                    Text("距离（km）")
                    Spacer()
                    OptionalNumberField(title: "距离，可留空", value: Binding(get: { activity.distanceMeters.map { $0 / 1000 } }, set: { activity.distanceMeters = $0.map { $0 * 1000 } })).frame(maxWidth: 150)
                        .accessibilityIdentifier("cardio.distance")
                }
            }
            Text("在下方填写手动时长，或使用训练计时。使用 Apple Watch 训练可采集心率、活动能量和系统支持的距离。").font(.caption).foregroundStyle(.secondary)
        }.onChange(of: activity.kind) { _, _ in activity.distanceMeters = nil }
    }
}

struct CardioAnalysisCard: View {
    @Environment(AppStore.self) private var store
    var session: Session
    @State private var reference = HealthReferenceSnapshot()
    @State private var loading = false
    @State private var issue: String?
    private var activity: ActivityRecord? { session.activity }
    var body: some View {
        if let activity {
            AppCard {
                SectionHeader(title: "运动分析", subtitle: activity.hasWatchMeasurements ? "Apple Watch 记录 · 活动能量为系统估算" : "手动记录 · 未采集传感器数据")
                Label(activity.kind.name, systemImage: activity.kind.symbol).font(.headline)
                if let distance = activity.distanceMeters { LabeledContent("距离", value: "\((distance / 1000).formattedValue) km") }
                if let pace = activity.paceSecondsPerKilometer(duration: session.elapsed()), pace.isFinite, pace <= 86400 {
                    if activity.kind.usesSpeed { LabeledContent("平均速度", value: "\((3600 / pace).formattedValue) km/h") }
                    else { LabeledContent("平均配速", value: "\(Int(pace) / 60)′\(String(format: "%02d", Int(pace) % 60))″ / km") }
                    Text("按记录距离与活动时长计算；不代表每一公里的分段配速。").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("活动能量", value: activity.activeEnergyKcal.map { "\($0.formattedValue) 千卡" } ?? "未记录")
                LabeledContent("平均心率", value: activity.averageHeartRate.map { "\($0.formattedValue) 次/分" } ?? "未记录")
                LabeledContent("最高心率", value: activity.maximumHeartRate.map { "\($0.formattedValue) 次/分" } ?? "未记录")
                if !activity.heartRate.isEmpty {
                    Chart(Array(activity.heartRate.enumerated()), id: \.offset) { _, point in
                        PointMark(x: .value("时间", point.date), y: .value("心率", point.bpm)).foregroundStyle(.pink).symbolSize(12)
                    }.chartYAxisLabel("次/分").frame(height: 180)
                        .accessibilityLabel("本次训练心率采样图；平均 \(activity.averageHeartRate?.formattedValue ?? "未记录")，最高 \(activity.maximumHeartRate?.formattedValue ?? "未记录") 次每分")
                    Text("曲线按最多每 10 秒一条采样显示；暂停与缺失时段不补值。").font(.caption).foregroundStyle(.secondary)
                }
                Text(CardioAnalysis.observation(for: session)).font(.subheadline).foregroundStyle(.secondary)
                if activity.hasWatchMeasurements {
                    Text("系统估算的活动能量不包含静息能量。手表佩戴、权限和运动类型会影响数据完整性。").font(.caption).foregroundStyle(.secondary)
                }
            }
            AppCard {
                SectionHeader(title: "有氧适能与血氧参考", subtitle: "读取 Apple 健康已有测量；不从单次心率推算 VO₂ max")
                if store.healthInsights.enabled {
                    if loading { ProgressView("正在读取健康参考…") }
                    if let fitness = reference.fitness.first {
                        LabeledContent("有氧适能 VO₂ max", value: "\(fitness.value.formattedValue) ml/kg/min")
                        Text("\(fitness.date.formatted(date: .abbreviated, time: .shortened)) · \(fitness.source)").font(.caption).foregroundStyle(.secondary)
                        if reference.fitness.count == 2 {
                            let delta = fitness.value - reference.fitness[1].value
                            LabeledContent("与上次可读记录相比", value: (delta >= 0 ? "+" : "") + delta.formattedValue + " ml/kg/min")
                            Text("上次测量：\(reference.fitness[1].date.formatted(date: .abbreviated, time: .omitted))。不同日期的系统估算变化，不作为本次训练造成的变化。").font(.caption).foregroundStyle(.secondary)
                        }
                    } else { Text("近 180 天没有可读的有氧适能记录。是否产生新估算由 Apple 决定，并非每次训练都有。").font(.subheadline).foregroundStyle(.secondary) }
                    if let oxygen = reference.oxygen {
                        LabeledContent("最近血氧参考", value: "\((oxygen.value * 100).formattedValue)%")
                        Text("\(oxygen.date.formatted(date: .abbreviated, time: .shortened)) · \(oxygen.source) · 历史静止测量参考，不表示本次运动中的血氧。").font(.caption).foregroundStyle(.secondary)
                    } else { Text("近 30 天没有可读血氧记录；可能尚未测量、设备不支持或未允许读取。").font(.subheadline).foregroundStyle(.secondary) }
                    Button("刷新参考值", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(loading)
                } else {
                    Text("可单独允许读取血氧和有氧适能。无数据时保持空白，不推算或补零。").font(.subheadline).foregroundStyle(.secondary)
                    Button("允许读取健康参考", systemImage: "heart.text.clipboard") {
                        Task { await store.healthInsights.enable(); await load() }
                    }.disabled(store.healthInsights.busy)
                }
                if let message = issue ?? store.healthInsights.issue { Text(message).font(.caption).foregroundStyle(.secondary) }
                Text("只显示不晚于本次训练结束的已有参考值。血氧和有氧适能不写入 TrainLog 备份。可在「健康」管理读取权限。").font(.caption).foregroundStyle(.secondary)
            }.task(id: session.updatedAt) { await load() }
        }
    }
    private func load() async {
        guard store.healthInsights.enabled else { return }
        loading = true; defer { loading = false }
        do { reference = try await store.healthInsights.references(at: session.endTime ?? session.date); issue = nil }
        catch { issue = "健康参考暂不可读：\(error.localizedDescription)" }
    }
}

struct WatchConnectionView: View {
    @Environment(AppStore.self) private var store
    @State private var activity: CardioActivity = .outdoorRun
    var body: some View {
        Form {
            Section {
                Label("Apple Watch 训练", systemImage: "applewatch").font(.headline)
                LabeledContent("配对手表", value: store.watch.paired ? "已配对" : "尚未检测到")
                LabeledContent("手表 App", value: store.watch.installed ? "已安装" : "请通过 Watch App 安装")
                LabeledContent("即时连接", value: store.watch.reachable ? "可用" : "后台连接／暂不可达")
                Picker("运动类型", selection: $activity) { ForEach(CardioActivity.allCases) { Text($0.name).tag($0) } }
                Button("在 Apple Watch 上准备训练", systemImage: "applewatch") { Task { await store.watch.start(activity) } }
                    .disabled(store.watch.launching || !store.watch.installed)
                Text("打开手表后点按「开始训练」，首次需在手表上允许健康权限。戴上手表不会擅自开始记录。暂停、继续和结束在手表操作。").font(.footnote).foregroundStyle(.secondary)
                if let issue = store.watch.issue { Text(issue).font(.footnote).foregroundStyle(.secondary) }
            }
            Section("数据与同步") {
                Text("手表原生采集心率、活动能量和系统支持的距离；室内骑行、划船等运动没有距离来源时不会虚构距离。泳池游泳请在手表确认泳池长度。")
                Text("手表完成训练后先写入 Apple 健康，再保留离线文件，直到手机确认保存。手机不再导出第二份训练。手机编辑与删除只影响 TrainLog 的手表副本，健康原始记录请在 Apple 健康中管理。")
                Text("心率与能量随这份训练进入本机 JSON／CSV 备份；导出时请妥善保管。血氧和有氧适能仅在查看时读取，不写入备份。")
            }.font(.footnote).foregroundStyle(.secondary)
            Section("身体数据参考") {
                Button("管理血氧与有氧适能读取") { Task { await store.healthInsights.enable() } }.disabled(store.healthInsights.busy)
                if store.healthInsights.enabled { Button("停止在 App 中读取参考值") { store.healthInsights.disable() } }
                if let issue = store.healthInsights.issue { Text(issue) }
                Text("血氧不连续采集。VO₂ max 使用 Apple 健康已有的系统估算，不根据年龄、心率或配速套用公式生成。")
            }.font(.footnote)
        }.navigationTitle("Apple Watch").navigationBarTitleDisplayMode(.inline)
            .task { store.activateWatch(); store.watch.refresh() }
    }
}

struct WatchLiveCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            if let live = store.watch.live {
                AppCard {
                    Label("Apple Watch · \(live.kind.name)", systemImage: "applewatch").font(.headline)
                    if live.isFresh(at: context.date) {
                        Text(live.paused ? "已暂停" : "正在训练").foregroundStyle(.secondary)
                        LabeledContent("活动时长", value: "\(Int(live.elapsed / 60)) 分钟")
                        LabeledContent("心率", value: live.heartRate.map { "\($0.formattedValue) 次/分" } ?? "等待测量")
                        LabeledContent("活动能量", value: live.activeEnergyKcal.map { "\($0.formattedValue) 千卡" } ?? "等待测量")
                    } else { Text("手表数据暂未更新。训练仍在手表记录，连接恢复后会更新。").font(.subheadline).foregroundStyle(.secondary) }
                    Text("请在手表上暂停或结束；完成后自动导入历史。").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CardioTrendsCard: View {
    var sessions: [Session]
    var interval: DateInterval
    @State private var activity: CardioActivity?
    private var records: [Session] {
        sessions.filter { $0.status == .completed && $0.mode == .cardio && interval.includes($0.date) && (activity == nil || $0.activity?.kind == activity) }.sorted { $0.date < $1.date }
    }
    var body: some View {
        let totals = CardioAnalysis.totals(records)
        AppCard {
            SectionHeader(title: "有氧与其他运动", subtitle: "按运动类型查看时长、距离与已有能量记录")
            Picker("运动筛选", selection: $activity) {
                Text("全部运动").tag(Optional<CardioActivity>.none)
                ForEach(CardioActivity.allCases) { Text($0.name).tag(Optional($0)) }
            }
            LabeledContent("运动次数", value: "\(totals.sessions) 次")
            LabeledContent("活动时长", value: "\(Int(totals.durationSeconds / 60)) 分钟")
            LabeledContent("已记录距离", value: totals.distanceMeters.map { "\(($0 / 1000).formattedValue) km" } ?? "未记录")
            LabeledContent("已记录活动能量", value: totals.activeEnergyKcal.map { "\($0.formattedValue) 千卡" } ?? "未记录")
            if !records.isEmpty {
                Chart(records) { session in
                    BarMark(x: .value("日期", session.date, unit: .day), y: .value("分钟", session.elapsed() / 60)).foregroundStyle(.mint).cornerRadius(3)
                }.frame(height: 150).chartYAxisLabel("分钟")
            } else { Text("完成运动后，这里会显示记录。也可通过日历查看任意日期。").font(.subheadline).foregroundStyle(.secondary) }
            Text("缺失距离与能量不补零。筛选相同运动后再比较；运动次数和时长包含瑜伽等非有氧项目，不换算为力量组数。单次记录中的有氧适能使用 Apple 健康已有值。").font(.caption).foregroundStyle(.secondary)
        }
    }
}
