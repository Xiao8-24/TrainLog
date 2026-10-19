import SwiftUI
import TrainLogCore

enum TrainingSetAction { case start, complete }

struct ExerciseEditorCard: View {
    @Binding var entry: ExerciseEntry
    var previous: ExerciseEntry?
    var unit: WeightUnit
    var live = true
    var activeSetID: UUID?
    var onAction: (UUID, TrainingSetAction) -> Void
    var onDelete: () -> Void
    @State private var confirmDelete = false
    @State private var confirmReuse = false
    var body: some View {
        AppCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.exercise.name).font(.headline)
                    Text(entry.exercise.loading.name).font(.caption).foregroundStyle(.blue)
                    Text("主要：" + entry.exercise.primary.map(\.name).joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("复用上次配置", systemImage: "arrow.clockwise") { confirmReuse = true }.disabled(previous == nil)
                    Button("删除动作", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("\(entry.exercise.name)操作")
            }
            if let previous {
                let completed = previous.sets.filter(\.isCompleted)
                if let last = completed.last {
                    Text("上次：" + setDescription(last, exercise: entry.exercise, unit: unit) + " · \(completed.count) 组已完成").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach($entry.sets) { $set in
                WorkoutSetRow(set: $set, index: (entry.sets.firstIndex { $0.id == set.id } ?? 0) + 1, exercise: entry.exercise, unit: unit, live: live, otherSetActive: activeSetID != nil && activeSetID != set.id, onAction: { action in onAction(set.id, action) }) { let id = set.id; entry.sets.removeAll { $0.id == id } }
                if set.id != entry.sets.last?.id { Divider() }
            }
            HStack {
                Button { var value = TrainingSet(); value.restSeconds = entry.sets.last?.restSeconds ?? 90; entry.sets.append(value) } label: { Label("新增一组", systemImage: "plus") }
                Spacer()
                Button { if let last = entry.sets.last { entry.sets.append(last.copied()) } } label: { Label("复制上一组", systemImage: "doc.on.doc") }.disabled(entry.sets.isEmpty)
            }.font(.subheadline).frame(minHeight: 44)
            TextField("动作备注（可选）", text: $entry.notes).font(.subheadline)
        }
        .confirmationDialog("删除动作及其所有组？", isPresented: $confirmDelete, titleVisibility: .visible) { Button("删除动作", role: .destructive, action: onDelete) }
        .nativeMotion(value: entry.sets.map(\.id))
        .confirmationDialog("用上次配置替换当前所有组？完成状态会清除。", isPresented: $confirmReuse, titleVisibility: .visible) {
            Button("替换配置") { if let previous { entry.sets = previous.sets.map { $0.copied() } } }
        }
    }
}
struct WorkoutSetRow: View {
    @Binding var set: TrainingSet
    var index: Int
    var exercise: Exercise
    var unit: WeightUnit
    var live: Bool
    var otherSetActive: Bool
    var onAction: (TrainingSetAction) -> Void
    var onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var deleteConfirmation = false
    @State private var errorMessage: String?
    private var weight: Binding<Double?> { Binding(get: { set.weightKg.map(unit.display) }, set: { set.weightKg = $0.map(unit.kilograms) }) }
    private func integer(_ path: WritableKeyPath<TrainingSet, Int?>) -> Binding<Double?> {
        Binding(get: { set[keyPath: path].map(Double.init) }, set: { number in
            set[keyPath: path] = number.map { $0.isFinite && abs($0) < 1_000_000 && $0.rounded() == $0 ? Int($0) : -1 }
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(index)").font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 24)
                Picker("第 \(index) 组类型", selection: $set.kind) { ForEach(SetKind.allCases) { Text($0.name).tag($0) } }.labelsHidden().font(.caption)
                Spacer(minLength: 0)
                Button {
                    if set.isCompleted { set.isCompleted = false }
                    else { onAction(.complete) }
                } label: { Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle").nativeSymbolTransition().nativeMotion(value: set.isCompleted).font(.title2).foregroundStyle(set.isCompleted ? .green : .secondary).frame(width: 44, height: 44) }
                    .accessibilityLabel("第 \(index) 组\(set.isCompleted ? "已完成，点击撤销" : "标记完成")").accessibilityIdentifier("completeSet.\(index)")
            }
            if exercise.tracking == .duration {
                HStack { Text("持续秒数").font(.caption).foregroundStyle(.secondary); OptionalNumberField(title: "秒", value: integer(\.durationSeconds), integer: true) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { numericFields }
                    VStack(spacing: 12) { numericFields }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if let timing = set.timing {
                    HStack {
                        Label(timing.endedAt == nil ? (timing.timerStartedAt == nil ? "本组已暂停" : "本组进行中") : "本组用时", systemImage: "stopwatch")
                        Spacer()
                        SetElapsedLabel(timing: timing).accessibilityIdentifier("setTimer.\(index)")
                    }.font(.subheadline).foregroundStyle(timing.endedAt == nil ? .blue : .secondary)
                }
                if live && !set.isCompleted {
                    if set.timing != nil && set.timing?.endedAt == nil {
                        Button("结束本组", systemImage: "checkmark.circle.fill") { onAction(.complete) }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("set.finish.\(index)")
                    } else {
                        Button("开始本组", systemImage: "play.fill") { onAction(.start) }
                            .buttonStyle(.bordered).disabled(otherSetActive).accessibilityIdentifier("set.start.\(index)")
                    }
                }
            }.nativeMotion(value: set.timing != nil).nativeMotion(value: set.isCompleted)
            HStack(spacing: 8) {
                Text("RPE").font(.caption).foregroundStyle(.secondary)
                OptionalNumberField(title: "可选 1–10", value: $set.rpe).frame(minWidth: 65)
                Spacer(minLength: 8)
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.up" : "chevron.down").nativeSymbolTransition().frame(width: 44, height: 44) }.accessibilityLabel("第 \(index) 组更多选项").accessibilityValue(expanded ? "已展开" : "已折叠").accessibilityIdentifier("set.options.\(index)")
            }
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("RIR").font(.caption); OptionalNumberField(title: "可选 0–10", value: $set.rir) }
                    Stepper("组间休息 \(set.restSeconds) 秒", value: $set.restSeconds, in: 0...3600, step: 15).font(.caption)
                    TextField("本组备注", text: $set.notes).font(.caption).accessibilityIdentifier("set.notes.\(index)")
                    if exercise.tracking == .weightReps || exercise.tracking == .assistedReps {
                        HStack {
                            Button("− 2.5 \(unit.rawValue)") { weight.wrappedValue = max(0, (weight.wrappedValue ?? 0) - 2.5) }
                            Spacer()
                            Button("+ 2.5 \(unit.rawValue)") { weight.wrappedValue = (weight.wrappedValue ?? 0) + 2.5 }
                        }.font(.caption).frame(minHeight: 44)
                    }
                    if exercise.tracking != .duration { Stepper("次数 \(set.reps ?? 0)", value: Binding(get: { set.reps ?? 1 }, set: { set.reps = $0 }), in: 1...1000) }
                    Button("删除本组", role: .destructive) { deleteConfirmation = true }.font(.caption).frame(minHeight: 44)
                }.transition(.opacity)
            }
        }
        .padding(10)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22)) { content in
            content.background(set.isCompleted ? Color.green.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .nativeMotion(value: expanded)
        .transition(.opacity)
        .sensoryFeedback(.success, trigger: set.isCompleted) { _, completed in completed }
        .confirmationDialog("删除第 \(index) 组？", isPresented: $deleteConfirmation, titleVisibility: .visible) { Button("删除本组", role: .destructive, action: onDelete) }
        .errorAlert($errorMessage)
    }
    @ViewBuilder private var numericFields: some View {
        if exercise.tracking == .weightReps || exercise.tracking == .assistedReps {
            HStack(spacing: 5) {
                Text(exercise.tracking == .assistedReps ? "辅助 \(unit.rawValue)" : unit.rawValue).font(.caption).foregroundStyle(.secondary)
                OptionalNumberField(title: "重量", value: weight).accessibilityIdentifier("setWeight.\(index)")
            }.padding(10).background(AppTheme.background, in: RoundedRectangle(cornerRadius: 10))
        }
        HStack(spacing: 5) {
            Text("次数").font(.caption).foregroundStyle(.secondary)
            OptionalNumberField(title: "次数", value: integer(\.reps), integer: true).accessibilityIdentifier("setReps.\(index)")
        }.padding(10).background(AppTheme.background, in: RoundedRectangle(cornerRadius: 10))
    }
}
struct SetElapsedLabel: View {
    var timing: SetTiming
    var body: some View {
        Group {
            if let running = timing.timerStartedAt {
                let origin = running.addingTimeInterval(-timing.accumulatedSeconds)
                Text(timerInterval: origin...max(origin, .distantFuture), countsDown: false, showsHours: true)
            } else { Text(Duration.seconds(timing.elapsed()).formatted(.time(pattern: .hourMinuteSecond))) }
        }.monospacedDigit().transaction { $0.animation = nil }
    }
}
func setDescription(_ set: TrainingSet, exercise: Exercise, unit: WeightUnit) -> String {
    if exercise.tracking == .duration { return "\(set.durationSeconds ?? 0) 秒" }
    if exercise.tracking == .bodyweightReps { return "自重 × \(set.reps ?? 0) 次" }
    return "\(set.weightKg.map { unit.display($0).formattedValue } ?? "—") \(unit.rawValue) × \(set.reps ?? 0) 次"
}

