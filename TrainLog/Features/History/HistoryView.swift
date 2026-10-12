import SwiftUI
import TrainLogCore

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var muscle: MuscleGroup?
    @State private var exerciseID: UUID?
    @State private var useDates = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var deleting: Session?
    private var results: [Session] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
        return store.completed.filter { session in
            (!useDates || (session.date >= start && session.date < end)) &&
            (muscle.map { MuscleMappingService.coverage(of: session).contains($0) } ?? true) &&
            (exerciseID.map { id in session.exercises.contains { $0.exercise.id == id } } ?? true)
        }
    }
    var body: some View {
        List {
            Section("筛选") {
                Toggle("限定日期", isOn: $useDates)
                if useDates {
                    DatePicker("开始", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("结束", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Picker("肌群", selection: $muscle) { Text("全部").tag(Optional<MuscleGroup>.none); ForEach(MuscleGroup.allCases) { Text($0.name).tag(Optional($0)) } }
                Picker("动作", selection: $exerciseID) { Text("全部").tag(Optional<UUID>.none); ForEach(store.exercises) { Text($0.name).tag(Optional($0.id)) } }
            }
            Section("\(results.count) 次训练") {
                ForEach(results) { session in
                    NavigationLink { SessionDetailView(sessionID: session.id) } label: { SessionRow(session: session) }
                        .swipeActions(allowsFullSwipe: false) { Button("删除", role: .destructive) { deleting = session } }
                }
                if results.isEmpty { EmptyStateView(title: "暂无对应训练", message: "调整筛选条件，或记录一次新的训练。", symbol: "calendar") }
            }
        }.navigationTitle("训练历史")
            .confirmationDialog("删除训练？统计与个人纪录将根据剩余记录重算。", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("删除训练", role: .destructive) { if let session = deleting { store.perform { try store.deleteSession(session.id) } }; deleting = nil }
            }
    }
}
struct DayHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    var date: Date
    private var records: [Session] { WorkoutCalendarIndex(sessions: store.sessions, calendar: clock.calendar).records(on: date) }
    var body: some View {
        List {
            if records.isEmpty { EmptyStateView(title: "这一天没有训练记录", message: "可在训练页新建记录，并将训练日期设为这一天。", symbol: "calendar") }
            ForEach(records) { session in NavigationLink { SessionDetailView(sessionID: session.id) } label: { SessionRow(session: session) } }
        }.navigationTitle(date.formatted(date: .abbreviated, time: .omitted)).navigationBarTitleDisplayMode(.inline)
    }
}
struct SessionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var highlightedSetID: UUID? = nil
    @State private var editing: Session?
    @State private var deleting = false
    @State private var selectedMuscle: MuscleGroup?
    var body: some View {
        Group {
            if let session = store.sessions.first(where: { $0.id == sessionID }) {
                ScrollView {
                    VStack(spacing: 20) {
                        AppCard {
                            Text(session.displayName).font(.title2.bold())
                            Text(session.date.formatted(date: .complete, time: .shortened)).foregroundStyle(.secondary)
                            SessionMetrics(session: session)
                            if let intensity = session.intensity { LabeledContent("主观强度", value: intensity.name) }
                            if let rpe = session.sessionRPE { LabeledContent("整次训练 RPE", value: rpe.formattedValue) }
                            if !session.notes.isEmpty { Text(session.notes).font(.subheadline).textSelection(.enabled) }
                        }
                        MuscleMapCard(title: "本次训练覆盖", model: MuscleHeatmapViewModel(sessions: [session], interval: .init(start: .distantPast, end: .distantFuture), metric: .coverage)) { selectedMuscle = $0 }
                        if session.mode == .quick {
                            AppCard {
                                SectionHeader(title: "快速记录", subtitle: "不产生正式组数、训练容量或 e1RM")
                                ForEach(session.quickEntries) { item in LabeledContent(item.muscle.name, value: (item.intensity ?? session.intensity)?.name ?? "未填写强度") }
                            }
                        }
                        ForEach(session.exercises) { entry in
                            AppCard {
                                SectionHeader(title: entry.exercise.name, subtitle: entry.exercise.loading.name)
                                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("\(index + 1) · \(set.kind.name)").font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                            Text(setDescription(set, exercise: entry.exercise, unit: store.settings.unit)).font(.subheadline).monospacedDigit()
                                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle").foregroundStyle(set.isCompleted ? .green : .secondary)
                                        }
                                        if let rpe = set.rpe { Text("RPE \(rpe.formattedValue)").font(.caption).foregroundStyle(.secondary) }
                                        if let rir = set.rir { Text("RIR \(rir.formattedValue)").font(.caption).foregroundStyle(.secondary) }
                                        if !set.notes.isEmpty { Text(set.notes).font(.caption).foregroundStyle(.secondary) }
                                        if set.id == highlightedSetID { Label("此纪录对应的训练组", systemImage: "arrow.turn.up.left").font(.caption).foregroundStyle(.blue) }
                                    }
                                    if index < entry.sets.count - 1 { Divider() }
                                }
                                if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        Button("删除训练", role: .destructive) { deleting = true }.frame(minHeight: 44)
                    }.padding(20)
                }.background(AppTheme.background)
                    .toolbar { Button("编辑") { editing = session }.accessibilityIdentifier("editWorkout") }
            } else { ContentUnavailableView("训练记录已删除", systemImage: "tray") }
        }.navigationTitle("训练详情").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { session in NavigationStack { WorkoutEditorView(session: session) { _ in editing = nil } }.interactiveDismissDisabled() }
            .sheet(item: $selectedMuscle) { muscle in NavigationStack { MuscleDetailSheet(muscle: muscle, interval: TimeRange.all.interval()) } }
            .confirmationDialog("删除训练？此操作会同步更新所有统计。", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除训练", role: .destructive) { do { try store.deleteSession(sessionID); dismiss() } catch { store.errorMessage = error.localizedDescription } }
            }
    }
}
struct SessionMetrics: View {
    @Environment(AppStore.self) private var store
    var session: Session
    var body: some View {
        let totals = WorkoutStatisticsService.totals([session])
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 16) {
            item("时长", value: "\(Int(totals.durationSeconds / 60))", unit: "分钟")
            if session.mode == .detailed {
                item("动作", value: "\(session.exercises.count)", unit: "个")
                item("正式组", value: "\(totals.workingSets)", unit: "组")
                item("适用容量", value: totals.volumeKg.map { store.settings.unit.display($0).formattedValue } ?? "—", unit: store.settings.unit.rawValue)
            } else { item("覆盖肌群", value: "\(session.quickEntries.count)", unit: "个") }
        }
    }
    private func item(_ title: String, value: String, unit: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); StatValue(value: value, unit: unit) }.accessibilityElement(children: .combine) }
}

