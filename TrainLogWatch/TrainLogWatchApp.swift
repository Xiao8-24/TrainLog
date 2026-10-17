import SwiftUI
import WatchKit
import HealthKit
import TrainLogCore

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in WatchWorkoutManager.shared.prepare(workoutConfiguration) }
    }
    func handleActiveWorkoutRecovery() { Task { @MainActor in WatchWorkoutManager.shared.recover() } }
}

@main struct TrainLogWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate
    var body: some Scene { WindowGroup { WatchWorkoutView() } }
}

struct WatchWorkoutView: View {
    @State private var manager = WatchWorkoutManager.shared
    @State private var confirmingFinish = false
    @State private var confirmingDiscardRecovery = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        @Bindable var manager = manager
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if manager.running {
                        Label(manager.selection.name, systemImage: manager.selection.symbol).font(.headline)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let duration = manager.elapsed + (manager.running && !manager.paused && !manager.finishing ? max(0, context.date.timeIntervalSince(manager.elapsedUpdatedAt)) : 0)
                            Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond))).font(.title2).monospacedDigit()
                            let fresh = manager.heartRateDate.map { context.date.timeIntervalSince($0) <= 20 } == true
                            metric("心率", value: fresh && !manager.paused ? manager.heartRate : nil, unit: "次/分", color: .pink)
                        }
                        metric("活动能量", value: manager.energy, unit: "千卡", color: .orange)
                        if manager.selection.supportsDistance { metric("距离", value: manager.distance.map { $0 / 1000 }, unit: "km", color: .blue) }
                        Text(manager.paused ? "已暂停" : "Apple Watch 测量 · 能量为系统估算").font(.caption2).foregroundStyle(.secondary)
                        if manager.finishing {
                            ProgressView("正在保存")
                            if manager.issue != nil { Button("重试保存") { manager.retrySave() } }
                        } else {
                            Button(manager.paused ? "继续" : "暂停", systemImage: manager.paused ? "play.fill" : "pause.fill") { manager.togglePause() }.buttonStyle(.bordered)
                            Button("结束训练", role: .destructive) { confirmingFinish = true }.buttonStyle(.bordered)
                        }
                    } else {
                        Label("开始运动", systemImage: "figure.run").font(.headline)
                        Picker("运动类型", selection: $manager.selection) { ForEach(CardioActivity.allCases) { Text($0.name).tag($0) } }
                        if manager.selection == .swimming {
                            Picker("泳池长度（米）", selection: $manager.poolLengthMeters) { ForEach([20.0, 25.0, 50.0], id: \.self) { Text("\(Int($0)) 米").tag($0) } }
                        }
                        Button("开始训练", systemImage: "play.fill") { Task { await manager.start() } }.buttonStyle(.borderedProminent).disabled(manager.busy)
                        Text("允许健康权限后采集心率、活动能量及适用距离。训练可在离线时完成。").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let issue = manager.issue { Text(issue).font(.caption2).foregroundStyle(.orange) }
                    if !manager.running && manager.hasRecovery {
                        Button("恢复上次训练") { manager.recover() }.font(.caption2)
                        Button("放弃恢复标记", role: .destructive) { confirmingDiscardRecovery = true }.font(.caption2)
                    }
                    if manager.pendingCount > 0 {
                        Text("\(manager.pendingCount) 次训练等待手机接收").font(.caption2)
                        Button("重试发送") { manager.flush() }
                    }
                    Text("血氧不在运动中连续采集；可在手机中查看健康已有的血氧与有氧适能。").font(.caption2).foregroundStyle(.secondary)
                }.padding(.horizontal, 4)
            }.navigationTitle("TrainLog")
                .task { manager.recover() }
                .confirmationDialog("结束并保存训练？", isPresented: $confirmingFinish) { Button("保存训练") { manager.finish() } }
                .confirmationDialog("放弃未完成恢复记录？仅清除本机标记，Apple 健康原始记录保留。", isPresented: $confirmingDiscardRecovery) { Button("放弃恢复标记", role: .destructive) { manager.discardRecovery() } }
                .onChange(of: phase) { _, value in if value == .active { manager.flush() } }
        }
    }
    private func metric(_ title: String, value: Double?, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " " + unit } ?? "—").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(color)
        }.accessibilityElement(children: .combine)
    }
}
