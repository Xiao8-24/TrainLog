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
    private enum Route: Hashable { case activities, poolLength }
    @State private var manager = WatchWorkoutManager.shared
    @State private var confirmingFinish = false
    @State private var confirmingDiscardRecovery = false
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var phase
    init() {
        #if DEBUG
        _path = State(initialValue: ProcessInfo.processInfo.arguments.contains("--snapshot-activities") ? [.activities] : [])
        #endif
    }
    var body: some View {
        @Bindable var manager = manager
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if manager.running {
                        WatchWorkoutMetrics(manager: manager)
                        if manager.finishing {
                            ProgressView("正在保存")
                            if manager.issue != nil { Button("重试保存") { manager.retrySave() } }
                        } else {
                            Button(manager.paused ? "继续" : "暂停", systemImage: manager.paused ? "play.fill" : "pause.fill") { manager.togglePause() }.buttonStyle(.bordered)
                            Button("结束训练", role: .destructive) { confirmingFinish = true }.buttonStyle(.bordered)
                        }
                    } else {
                        Label("开始运动", systemImage: "figure.run").font(.headline)
                        if let request = manager.linkedRequest {
                            Label("已连接手机训练", systemImage: "iphone").font(.caption)
                            Text(request.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text("仅把采集数据附加到这一场手机训练。").font(.caption2).foregroundStyle(.secondary)
                        }
                        NavigationLink(value: Route.activities) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("运动类型").font(.caption2).foregroundStyle(.secondary)
                                Label(manager.selection.name, systemImage: manager.selection.symbol).font(.body).fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }.buttonStyle(.bordered).disabled(manager.linkedRequest != nil).accessibilityIdentifier("watch.chooseActivity")
                        if manager.selection == .swimming {
                            NavigationLink(value: Route.poolLength) {
                                Text("泳池长度 · \(Int(manager.poolLengthMeters)) 米").fixedSize(horizontal: false, vertical: true)
                            }.buttonStyle(.bordered)
                        }
                        Button("开始训练", systemImage: "play.fill") { Task { await manager.start() } }.buttonStyle(.borderedProminent).tint(.green).disabled(manager.busy)
                        if manager.linkedRequest != nil { Button("取消手机连接", role: .destructive) { manager.cancelPreparedLink() }.disabled(manager.busy) }
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
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .activities: WatchActivitySelection(selection: $manager.selection)
                    case .poolLength: WatchPoolLengthSelection(length: $manager.poolLengthMeters)
                    }
                }
                .task { manager.recover() }
                .onChange(of: manager.linkedRequest) { _, value in if value != nil { path.removeAll() } }
                .confirmationDialog("结束并保存训练？", isPresented: $confirmingFinish) { Button("保存训练") { manager.finish() } }
                .confirmationDialog("放弃未完成恢复记录？仅清除本机标记，Apple 健康原始记录保留。", isPresented: $confirmingDiscardRecovery) { Button("放弃恢复标记", role: .destructive) { manager.discardRecovery() } }
                .onChange(of: phase) { _, value in if value == .active { manager.flush() } }
        }
    }
}

/// Sensor ticks update this subtree, rather than rebuilding navigation/controls.
private struct WatchWorkoutMetrics: View {
    var manager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
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
    }
    private func metric(_ title: String, value: Double?, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " " + unit } ?? "—").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(color)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: value)
        }.accessibilityElement(children: .combine)
    }
}

private struct WatchActivitySelection: View {
    @Binding var selection: CardioActivity
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List(CardioActivity.allCases) { activity in
            Button {
                selection = activity; dismiss()
            } label: {
                HStack {
                    Label(activity.name, systemImage: activity.symbol).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if selection == activity { Image(systemName: "checkmark").foregroundStyle(.green) }
                }
            }.accessibilityIdentifier("watch.activity.\(activity.rawValue)")
                .accessibilityAddTraits(selection == activity ? .isSelected : [])
        }.navigationTitle("运动类型")
    }
}

private struct WatchPoolLengthSelection: View {
    @Binding var length: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List([20.0, 25.0, 50.0], id: \.self) { meters in
            Button {
                length = meters; dismiss()
            } label: {
                HStack {
                    Text("\(Int(meters)) 米")
                    Spacer()
                    if length == meters { Image(systemName: "checkmark").foregroundStyle(.green) }
                }
            }.accessibilityAddTraits(length == meters ? .isSelected : [])
        }.navigationTitle("泳池长度")
    }
}
