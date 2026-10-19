import SwiftUI
import TrainLogCore

extension WatchTrainingLink {
    var displayState: String {
        switch state {
        case .requested: return "等待手表确认连接"
        case .prepared: return "已连接，请在手表点按开始"
        case .recording: return "手表采集中／等待保存结果"
        case .finished: return "手表结果已附加到这次训练"
        case .cancelled: return "连接已取消，可使用手机健康记录"
        }
    }
}
struct LinkedWatchDraftCard: View {
    @Environment(AppStore.self) private var store
    @Binding var session: Session
    var beforeConnect: () throws -> Void
    @State private var busy = false
    @State private var issue: String?
    var body: some View {
        if session.watchLink == nil && !store.watch.installed {
            AppCard {
                NavigationLink { WatchConnectionView() } label: { Label("连接 Apple Watch", systemImage: "applewatch") }
            }
        } else { expandedCard }
    }
    private var expandedCard: some View {
        AppCard {
            Label("这次训练的 Apple Watch", systemImage: "applewatch").font(.headline)
            if let link = session.watchLink {
                Text(link.displayState).font(.subheadline).accessibilityIdentifier("watch.linkState")
                if link.state == .requested || link.state == .prepared {
                    Button("重新确认连接") { connect() }.disabled(busy)
                    Button("取消连接（需手表确认）", role: .destructive) { cancel(link) }.disabled(busy)
                } else if link.state == .cancelled {
                    Button("重新连接这次训练") { connect() }.disabled(busy || !store.watch.installed)
                }
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    if let live = store.watch.live, live.phoneLink == link.reference {
                        if live.isFresh(at: context.date) {
                            LabeledContent("手表心率", value: live.heartRate.map { "\($0.formattedValue) 次/分" } ?? "等待测量")
                            LabeledContent("手表活动能量", value: live.activeEnergyKcal.map { "\($0.formattedValue) 千卡" } ?? "等待测量")
                        } else { Text("手表数据暂未更新，训练仍在手表记录。").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if let summary = link.summary { Text("手表已保存 \(Int(summary.duration / 60)) 分钟采集结果，完成手机训练后查看心率曲线。").font(.caption).foregroundStyle(.secondary) }
            } else {
                Text("在手机逐组记录，同时附加手表的心率与系统能量。").font(.subheadline).foregroundStyle(.secondary)
                Button("连接这次力量训练", systemImage: "applewatch") { connect() }
                    .disabled(busy || !store.watch.installed).accessibilityIdentifier("watch.connectCurrentWorkout")
            }
            if busy { ProgressView("正在确认连接…") }
            if let issue { Text(issue).font(.caption).foregroundStyle(.orange) }
            Text(store.watch.installed ? "先在手表打开 TrainLog，再连接；开始、暂停与结束由手表控制。" : "先通过 Watch App 在已配对手表安装并打开 TrainLog。")
                .font(.caption).foregroundStyle(.secondary)
            Text("连接后健康记录由手表负责。手机与手表分别保留实际计时区间，不重复写入健康。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func connect() {
        guard !busy else { return }
        do { try beforeConnect() } catch { issue = error.localizedDescription; return }
        let id = session.id
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await store.connectWatch(sessionID: id); issue = nil }
            catch { issue = error.localizedDescription }
        }
    }
    private func cancel(_ link: WatchTrainingLink) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                let update = try await store.watch.send(WatchLinkCommand(kind: .cancel, request: link.request))
                try store.applyWatchLinkUpdate(update)
                issue = update.state == .cancelled ? nil : "手表已经开始，请在手表结束并保存；不能改回手机健康记录。"
            } catch { issue = "尚未取消：\(error.localizedDescription)。也可在手表取消未开始的连接。" }
        }
    }
}
struct LinkedWatchSummaryCard: View {
    var session: Session
    var body: some View {
        if let link = session.watchLink, link.ownsHealthRecord {
            AppCard {
                Label("关联手表记录", systemImage: "applewatch").font(.headline)
                Text(link.displayState).font(.subheadline)
                if let summary = link.summary {
                    LabeledContent("手表采集时长", value: "\(Int(summary.duration / 60)) 分钟")
                    Text("\(summary.startedAt.formatted(date: .abbreviated, time: .shortened)) — \(summary.endedAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    Text("下方身体数据来自这个手表采集时段；手机训练时长、组数与备注保持原记录。").font(.caption).foregroundStyle(.secondary)
                } else { Text("请在手表开始或结束并保存。手机记录已保留，结果收到后自动附加；不要另建同一场训练。").font(.caption).foregroundStyle(.secondary) }
            }
            if let summary = link.summary { CardioAnalysisCard(session: summary.session) }
        }
    }
}
