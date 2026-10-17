import SwiftUI
import Charts
import TrainLogCore

struct TrendsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @State private var range = TimeRange.month
    @State private var metric = HeatMetric.weightedSets
    @State private var bodyView = BodyView.front
    @State private var selectedMuscle: MuscleGroup?
    private var interval: DateInterval { range.interval(now: clock.now, calendar: clock.calendar) }
    private var model: MuscleHeatmapViewModel { MuscleHeatmapViewModel(sessions: store.sessions, interval: interval, metric: metric) }
    private var daily: [DailyStatistic] { TrendAnalysisService.daily(store.sessions, interval: interval) }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("每个阶段，都有迹可循。").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("时间范围", selection: $range) { ForEach(TimeRange.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                }
                AppCard {
                    SectionHeader(title: "人体肌群分析", subtitle: "\(range.name) · 点击部位查看训练档案")
                    Picker("统计指标", selection: $metric) { ForEach(HeatMetric.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                    Picker("人体视角", selection: $bodyView) { ForEach(BodyView.allCases) { Text($0.name).tag($0) } }.pickerStyle(.segmented)
                    BodyMuscleMapView(view: bodyView, levels: model.levels) { selectedMuscle = $0 }.frame(height: 375).frame(maxWidth: .infinity)
                    HeatLegend(metric: metric)
                    Text(metric.explanation).font(.caption).foregroundStyle(.secondary)
                    if metric == .intensity && model.statistics.allSatisfy({ $0.meanIntensity == nil }) { Text("数据不足：当前范围没有明确的轻／中／高记录。").font(.subheadline).foregroundStyle(.secondary) }
                    DisclosureGroup("肌群数值与文字操作") {
                        ForEach(model.statistics) { stat in
                            Button { selectedMuscle = stat.muscle } label: {
                                HStack { Text(stat.muscle.name); Spacer(); Text(statValue(stat)).monospacedDigit().foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.caption) }.font(.subheadline).frame(minHeight: 44)
                            }.buttonStyle(.plain)
                        }
                    }.font(.subheadline)
                }
                summaryCards
                CardioTrendsCard(sessions: store.sessions, interval: interval)
                if daily.isEmpty {
                    AppCard { EmptyStateView(title: "这段时间还没有训练记录", message: "记录后即可查看频率、正式组数、适用容量和主观感受的变化。") }
                } else {
                    ForEach(TrendMetric.allCases) { type in
                        TrainingTrendChart(type: type, daily: daily, unit: store.settings.unit)
                    }
                    muscleDistribution
                }
                AppCard {
                    SectionHeader(title: "训练日历", subtitle: "点击日期查看当天训练")
                    WorkoutMonthCalendar(sessions: store.completed)
                }
                AppCard { AnnualHeatmap(sessions: store.completed) }
                NavigationLink { HistoryView() } label: { Label("筛选与管理全部记录", systemImage: "clock.arrow.circlepath").font(.headline).frame(maxWidth: .infinity, minHeight: 50) }.buttonStyle(.bordered)
            }.padding(20)
        }.background(AppTheme.background).navigationTitle("趋势")
            .sheet(item: $selectedMuscle) { muscle in NavigationStack { MuscleDetailSheet(muscle: muscle, interval: interval) } }
    }
    private func statValue(_ stat: MuscleStatistics) -> String {
        switch metric {
        case .coverage: return stat.trainingDays > 0 ? "有记录" : "无记录"
        case .days: return "\(stat.trainingDays) 天"
        case .weightedSets: return "\(stat.weightedSets.formattedValue) 组"
        case .intensity: return stat.meanIntensity.map { "\($0.formattedValue) / 3" } ?? "未记录"
        }
    }
    private var summaryCards: some View {
        let totals = WorkoutStatisticsService.totals(store.sessions, interval: interval)
        let effectiveStart = range == .all ? (store.completed.map(\.date).min() ?? clock.now) : interval.start
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: effectiveStart), to: interval.end).day ?? 1)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 12) {
            MetricCard(title: "训练次数", value: "\(totals.sessions)", unit: "次", symbol: "dumbbell")
            MetricCard(title: "训练天数", value: "\(totals.trainingDays)", unit: "天", symbol: "calendar")
            MetricCard(title: "正式组数", value: "\(totals.workingSets)", unit: "组", symbol: "checkmark.circle")
            MetricCard(title: "每周平均", value: (Double(totals.sessions) / Double(dayCount) * 7).formattedValue, unit: "次", symbol: "chart.bar")
        }
    }
    private var muscleDistribution: some View {
        let values = model.statistics.filter { $0.weightedSets > 0 }.sorted { $0.weightedSets > $1.weightedSets }
        return ChartContainer(title: "肌群组数分布", subtitle: "加权正式组数 · 主要 × 1，次要 × 0.5") {
            if values.isEmpty { Text("快速记录与非正式组不产生组数分布。").font(.subheadline).foregroundStyle(.secondary) }
            else {
                Chart(values) { item in BarMark(x: .value("加权组数", item.weightedSets), y: .value("肌群", item.muscle.name)).foregroundStyle(.blue).cornerRadius(3) }
                    .frame(height: max(150, CGFloat(values.count) * 29))
            }
        }
    }
}
enum TrendMetric: String, CaseIterable, Identifiable {
    case sessions, sets, volume, rpe
    var id: String { rawValue }
    var title: String { switch self { case .sessions: return "训练频率"; case .sets: return "正式组数"; case .volume: return "适用训练容量"; case .rpe: return "主观训练感受" } }
    func value(_ day: DailyStatistic, unit: WeightUnit) -> Double? {
        switch self { case .sessions: return Double(day.totals.sessions); case .sets: return Double(day.totals.workingSets); case .volume: return day.totals.volumeKg.map(unit.display); case .rpe: return day.meanRPE }
    }
    func subtitle(unit: WeightUnit) -> String {
        switch self { case .sessions: return "次 / 天 · 同一天可有多次训练"; case .sets: return "组 / 天 · 仅已完成正式组"; case .volume: return "\(unit.rawValue) / 天 · 仅外部负重；不同器械不等效"; case .rpe: return "每日会话 RPE 平均值 · 缺失值不填零" }
    }
}
struct TrainingTrendChart: View {
    var type: TrendMetric
    var daily: [DailyStatistic]
    var unit: WeightUnit
    var body: some View {
        ChartContainer(title: type.title, subtitle: type.subtitle(unit: unit)) {
            if daily.contains(where: { type.value($0, unit: unit) != nil }) {
                Chart(daily) { day in
                    if let value = type.value(day, unit: unit) {
                        if type == .rpe {
                            PointMark(x: .value("日期", day.date), y: .value("RPE", value)).foregroundStyle(.orange).symbolSize(35)
                        } else {
                            BarMark(x: .value("日期", day.date, unit: .day), y: .value(type.title, value)).foregroundStyle(.blue.gradient).cornerRadius(3)
                        }
                    }
                }.chartYScale(domain: type == .rpe ? 0...10 : 0...max(1, daily.compactMap { type.value($0, unit: unit) }.max() ?? 1))
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month().day()) } }
                    .frame(height: 180)
            } else { Text(type == .rpe ? "填写整次训练 RPE 后显示，不将轻／中／高换算成 RPE。" : "没有适用的外部负重正式组，暂不提供容量。").font(.subheadline).foregroundStyle(.secondary).padding(.vertical) }
        }
    }
}

