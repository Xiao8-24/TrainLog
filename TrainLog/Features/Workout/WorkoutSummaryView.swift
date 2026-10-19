import SwiftUI
import TrainLogCore

struct WorkoutSummaryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var sessionID: UUID
    @State private var reveal = false
    @State private var muscle: MuscleGroup?
    var body: some View {
        if let session = store.completed.first(where: { $0.id == sessionID }) {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 48, weight: .light)).foregroundStyle(.green).accessibilityHidden(true)
                        Text("又一次，认真完成。").font(.title2.weight(.semibold))
                        Text("训练已安全保存在本机").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                    if session.mode != .cardio { MuscleMapCard(title: "看见今天的努力", model: MuscleHeatmapViewModel(sessions: reveal ? [session] : [], interval: .init(start: .distantPast, end: .distantFuture), metric: .coverage)) { muscle = $0 } }
                    AppCard { SessionMetrics(session: session) }
                    LiveTrainingSummaryCard(session: session)
                    CardioAnalysisCard(session: session)
                    LinkedWatchSummaryCard(session: session)
                    WorkoutHealthCard(session: session)
                    let records = PersonalRecordService.newRecords(for: session, all: store.completed)
                    if !records.isEmpty {
                        AppCard {
                            Label("新的个人纪录", systemImage: "trophy.fill").font(.headline).foregroundStyle(.orange)
                            ForEach(records) { record in RecordRow(record: record, unit: store.settings.unit) }
                            Text("首次有效表现也会建立你的初始纪录。").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    PrimaryActionButton(title: "完成", symbol: "checkmark") { dismiss() }.accessibilityIdentifier("closeSummary")
                }.padding(20)
            }.background(AppTheme.background).navigationTitle("训练完成").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("关闭") { dismiss() } }
                .task {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { reveal = true }
                }
                .sheet(item: $muscle) { value in NavigationStack { MuscleDetailSheet(muscle: value, interval: TimeRange.today.interval(now: session.date), sessionScope: [sessionID]) } }
        } else { ContentUnavailableView("训练不存在", systemImage: "tray").toolbar { Button("关闭") { dismiss() } } }
    }
}
struct LiveTrainingSummaryCard: View {
    var session: Session
    var body: some View {
        if session.mode == .detailed && (session.plan != nil || session.exercises.flatMap(\.sets).contains(where: { $0.timing != nil })) {
            AppCard {
                SectionHeader(title: "逐组训练记录", subtitle: "整场用时包含组间休息，暂停时间不计入；本组用时只记录实际开启的计时。")
                if let plan = session.plan { Label(plan.name, systemImage: "calendar"); Text("原计划：" + plan.scheduledAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                ForEach(session.exercises) { entry in
                    Text(entry.exercise.name).font(.headline)
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        LabeledContent("第 \(index + 1) 组 · \(set.isCompleted ? "已完成" : "未完成")", value: set.timing.map { Duration.seconds($0.elapsed()).formatted(.time(pattern: .hourMinuteSecond)) } ?? "未计时")
                    }
                }
            }
        }
    }
}
struct RecordRow: View {
    var record: PersonalRecord
    var unit: WeightUnit
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.type.rawValue).font(.subheadline)
                Spacer()
                Text(record.type == .repetitions ? "\(Int(record.value)) 次" : "\(unit.display(record.value).formattedValue) \(unit.rawValue)").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            Text(record.exerciseName + (record.weightKg.map { " · \(unit.display($0).formattedValue) \(unit.rawValue)" } ?? "") + " · " + record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}

