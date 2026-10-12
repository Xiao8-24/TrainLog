import SwiftUI
import TrainLogCore

struct OverviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @Environment(AppRouter.self) private var router
    var showSettings: () -> Void
    @State private var selectedMuscle: MuscleGroup?
    private var week: DateInterval { TrainingCalendar.week(containing: clock.now, calendar: clock.calendar) }
    private var weekTotals: WorkoutTotals { WorkoutStatisticsService.totals(store.sessions, interval: week) }
    private var today: [Session] { store.completed.filter { clock.calendar.isDate($0.date, inSameDayAs: clock.now) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(clock.now.formatted(.dateTime.month().day().weekday(.wide))).font(.subheadline).foregroundStyle(.secondary)
                    Text(today.isEmpty ? "今天准备练什么？" : "每一次记录，都在积累。")
                        .font(.title2.weight(.bold))
                    Text(today.isEmpty ? "专注当下，让进步慢慢清晰。" : "今天已完成 \(today.count) 次训练。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 4)
                PrimaryActionButton(title: store.draft == nil ? (today.isEmpty ? "开始训练" : "继续记录") : "继续未完成的训练", symbol: "play.fill") { router.start(.detailed, store: store) }.accessibilityIdentifier("startWorkout")
                AppCard {
                    HStack {
                        SectionHeader(title: "本周训练", subtitle: "周一开始 · 次数与训练天数分别统计")
                        Spacer()
                        Text("\(weekTotals.sessions)").font(.title.weight(.semibold)).foregroundStyle(.blue).monospacedDigit()
                        Text("/ \(store.settings.weeklyGoal)").font(.headline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(Double(weekTotals.sessions), Double(store.settings.weeklyGoal)), total: Double(store.settings.weeklyGoal)).tint(.blue)
                    HStack {
                        miniMetric("训练天数", value: "\(weekTotals.trainingDays)", unit: "天")
                        Spacer()
                        miniMetric("总时长", value: "\(Int(weekTotals.durationSeconds / 60))", unit: "分钟")
                        Spacer()
                        miniMetric("正式组数", value: "\(weekTotals.workingSets)", unit: "组")
                    }
                    let month = clock.calendar.dateInterval(of: .month, for: clock.now) ?? TimeRange.month.interval(now: clock.now, calendar: clock.calendar)
                    let monthly = WorkoutStatisticsService.totals(store.sessions, interval: month)
                    let recent = WorkoutStatisticsService.totals(store.sessions, interval: TimeRange.month.interval(now: clock.now, calendar: clock.calendar))
                    Text("本月 \(monthly.sessions) 次训练 · 近 30 天训练 \(recent.trainingDays) 天").font(.caption).foregroundStyle(.secondary)
                }
                MuscleMapCard(title: "本周肌群分布", model: MuscleHeatmapViewModel(sessions: store.sessions, interval: week, metric: .days)) { selectedMuscle = $0 }
                VStack(alignment: .leading, spacing: 8) {
                    let stats = MuscleHeatmapService.statistics(store.sessions, interval: week)
                    let most = stats.filter { $0.trainingDays > 0 }.sorted { $0.trainingDays > $1.trainingDays }.prefix(2)
                    Text(most.isEmpty ? "记录训练后，这里会显示本周训练分布。" : "训练天数最多：\(most.map(\.muscle.name).joined(separator: "、"))")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { router.tab = .trends } label: { Label("查看完整肌群分析", systemImage: "arrow.up.right") }.font(.subheadline)
                }.padding(.horizontal, 4)
                AppCard {
                    SectionHeader(title: "最近七天", subtitle: "点击日期查看记录")
                    SevenDayStrip(sessions: store.completed)
                }
                recentProgress
                if !store.completed.isEmpty {
                    AppCard {
                        SectionHeader(title: "最近训练")
                        ForEach(store.completed.prefix(3)) { session in
                            NavigationLink { SessionDetailView(sessionID: session.id) } label: { SessionRow(session: session, showsChevron: true) }.buttonStyle(.plain)
                        }
                    }
                }
                Text("记录每一次训练，看见每一点进步。").font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(20)
        }.background(AppTheme.background).navigationTitle("概览")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: showSettings) { Image(systemName: "gearshape") }.accessibilityLabel("设置") } }
            .sheet(item: $selectedMuscle) { muscle in NavigationStack { MuscleDetailSheet(muscle: muscle, interval: week) } }
    }
    private func miniMetric(_ title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); StatValue(value: value, unit: unit) }
    }
    private var recentProgress: some View {
        AppCard {
            SectionHeader(title: "最近力量进步", subtitle: "来自实际完成的训练")
            if let latest = store.completed.first {
                let records = PersonalRecordService.newRecords(for: latest, all: store.completed).filter { $0.type == .weight || $0.type == .estimated }
                if let record = records.first {
                    NavigationLink { SessionDetailView(sessionID: record.sessionID) } label: {
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(.orange).font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.exerciseName + " · " + record.type.rawValue).font(.subheadline.weight(.medium))
                                Text("\(store.settings.unit.display(record.value).formattedValue) \(store.settings.unit.rawValue)").font(.headline).foregroundStyle(.green)
                                Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.buttonStyle(.plain)
                } else { Text("最近一次训练没有产生新的重量或估算力量纪录。每一次稳定记录同样有价值。").font(.subheadline).foregroundStyle(.secondary) }
            } else { EmptyStateView(title: "你的进步，从这里开始", message: "完成负重动作后查看实际重量纪录；填写接近力竭的 RPE 或 RIR，可用于适用动作的力量估算。", symbol: "chart.line.uptrend.xyaxis") }
        }
    }
}
struct SevenDayStrip: View {
    @Environment(AppClock.self) private var clock
    var sessions: [Session]
    private var days: [Date] { (0..<7).compactMap { clock.calendar.date(byAdding: .day, value: $0 - 6, to: clock.calendar.startOfDay(for: clock.now)) } }
    var body: some View {
        HStack(spacing: 2) {
            ForEach(days, id: \.self) { date in
                let count = sessions.filter { clock.calendar.isDate($0.date, inSameDayAs: date) }.count
                NavigationLink { DayHistoryView(date: date) } label: {
                    VStack(spacing: 10) {
                        Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption).foregroundStyle(.secondary)
                        Text(date.formatted(.dateTime.day())).font(.subheadline.weight(.medium))
                            .frame(minWidth: 32, minHeight: 32).background(clock.calendar.isDate(date, inSameDayAs: clock.now) ? Color.blue.opacity(0.12) : .clear, in: Circle())
                        Circle().fill(count > 0 ? Color.blue : Color(uiColor: .systemGray5)).frame(width: 5, height: 5)
                    }.frame(maxWidth: .infinity, minHeight: 70)
                }.buttonStyle(.plain).accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(count) 次训练")
            }
        }
    }
}

