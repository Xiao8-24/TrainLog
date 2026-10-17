import SwiftUI
import TrainLogCore

struct AppleHealthView: View {
    @Environment(AppStore.self) private var store
    private var health: HealthSyncCoordinator { store.health }
    var body: some View {
        Form {
            Section {
                Label("把训练留在 Apple 健康", systemImage: "heart.fill")
                    .font(.headline).foregroundStyle(.pink)
                Text("授权后，新完成的力量训练会自动写入 Apple 健康，供 Apple「健身」显示训练摘要。无需额外登录账号。")
                    .foregroundStyle(.secondary)
                Toggle("同步已完成训练", isOn: Binding(get: { health.enabled }, set: { enabled in
                    if enabled { Task { await health.enable(sessions: store.sessions) } } else { health.disable() }
                })).disabled(health.isAuthorizing || health.authorization == .unavailable)
                    .accessibilityIdentifier("health.enabled")
                if health.isAuthorizing { ProgressView("正在请求健康授权…") }
                LabeledContent("写入权限", value: authorizationLabel)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("健康写入权限")
                    .accessibilityValue(authorizationLabel)
                    .accessibilityIdentifier("health.authorization")
                if health.authorization == .denied {
                    Text("请打开「健康」App，点按个人头像 → App → TrainLog，允许写入「体能训练」。返回此页后会重新检查权限。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if health.authorization == .unavailable {
                    Text("当前设备或测试环境不支持健康连接。本机记录功能仍可正常使用。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("同步状态") {
                LabeledContent("已写入", value: "\(health.exportedCount) 次")
                LabeledContent("等待处理", value: "\(health.pendingCount) 项")
                if health.isWorking { ProgressView("正在同步…") }
                if let issue = health.issue { Text(issue).font(.footnote).foregroundStyle(.secondary) }
                Button("重试待处理记录", systemImage: "arrow.clockwise") { health.retry(sessions: store.sessions) }
                    .disabled(!health.enabled || health.isWorking || health.authorization != .authorized)
                Text("已有历史不会批量上传。打开单次训练详情，确认日期与时长后，可单独写入。关闭连接会停止后续提交，已写入的健康记录会保留。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Apple 健身中会显示什么") {
                Text("写入力量训练类型、开始与结束时间、实际记录的训练时长。动作、重量、次数、备注和肌群图仍保存在 TrainLog。")
                Text("本版本不采集或估算心率与活动热量，也不伪造圆环进度。Apple 健身的展示、圆环计算和设备间健康同步由系统决定。若 Apple Watch 已记录同一场训练，请只保留一个写入来源，避免重复。")
                Text("编辑已连接记录后会更新对应的健康摘要。删除或替换本机已连接记录后，会排队删除 TrainLog 写入的对应副本；需要保持连接和写入授权。其他 App 或 Apple Watch 的记录不会被删除。")
            }.font(.footnote).foregroundStyle(.secondary)
            Section("隐私") {
                Text("只申请写入「体能训练」的权限，不读取其他 App 的训练、心率、体重或账户信息。健康数据不发送到 TrainLog 服务器。健康授权与同步队列仅属于此设备，不随 TrainLog JSON 备份导出或导入。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Apple 健康").navigationBarTitleDisplayMode(.inline)
    }
    private var authorizationLabel: String {
        switch health.authorization {
        case .authorized: return "已允许"
        case .denied: return "未允许"
        case .notDetermined: return "尚未请求"
        case .unavailable: return "当前不可用"
        }
    }
}

struct WorkoutHealthCard: View {
    @Environment(AppStore.self) private var store
    var session: Session
    private var health: HealthSyncCoordinator { store.health }
    private var export: HealthWorkoutExport? { try? HealthWorkoutExport(session: session) }
    var body: some View {
        AppCard {
            Label("Apple 健康", systemImage: "heart.fill").font(.headline).foregroundStyle(.pink)
            Text(health.status(for: session.id)).font(.subheadline)
                .accessibilityIdentifier("health.workoutStatus")
            if let export {
                Text("传统力量训练 · \(Int(export.duration / 60)) 分钟")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(export.start.formatted(date: .abbreviated, time: .shortened)) — \(export.end.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                if !health.isExported(session.id) {
                    Button(health.enabled ? "写入／重试这次训练" : "连接并写入这次训练", systemImage: "heart.text.clipboard") {
                        Task {
                            if !health.enabled { await health.enable(sessions: store.sessions) }
                            health.export(session)
                        }
                    }.disabled(health.isAuthorizing || health.isWorking || health.authorization == .unavailable)
                        .accessibilityIdentifier("health.exportWorkout")
                }
            } else {
                Text("填写有效时长后，可把训练摘要写入 Apple 健康。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let issue = health.issue { Text(issue).font(.footnote).foregroundStyle(.secondary) }
            NavigationLink("管理健康连接") { AppleHealthView() }.font(.subheadline)
            Text("只写入训练类型与时间，不推算心率、热量。若 Apple Watch 已记录本次训练，请勿重复写入。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
