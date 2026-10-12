import SwiftUI
import Charts
import TrainLogCore

struct StrengthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @State private var selectedKey = ""
    @State private var range = TimeRange.quarter
    @State private var choosingPattern: MovementPattern?
    @State private var selectedMuscle: MuscleGroup?
    private var options: [Exercise] {
        var seen = Set<String>()
        return (store.exercises + store.completed.flatMap(\.exercises).map(\.exercise)).filter { $0.tracking == .weightReps && seen.insert($0.comparisonKey).inserted }.sorted { $0.name < $1.name }
    }
    private var exercise: Exercise? { options.first { $0.comparisonKey == selectedKey } ?? options.first { $0.id == ExerciseCatalog.id(1) } ?? options.first }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("让真正的进步，清晰可见。").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                if let exercise {
                    let performances = StrengthAnalysisService.performances(store.completed, exercise: exercise)
                    let comparison = StrengthAnalysisService.compare(performances)
                    AppCard {
                        Picker("分析动作", selection: Binding(get: { exercise.comparisonKey }, set: { selectedKey = $0 })) {
                            ForEach(options, id: \.comparisonKey) { option in
                                Text(option.name + (store.exercises.first(where: { $0.id == option.id })?.comparisonKey == option.comparisonKey ? "" : " · 历史口径")).tag(option.comparisonKey)
                            }
                        }.pickerStyle(.menu)
                        Text(exercise.loading.name).font(.caption).foregroundStyle(.secondary)
                        if let latest = performances.last {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("最近一次表现").font(.caption).foregroundStyle(.secondary)
                                StatValue(value: store.settings.unit.display(latest.weightKg).formattedValue, unit: "\(store.settings.unit.rawValue) × \(latest.reps)")
                            }
                            if let best = performances.compactMap(\.estimated1RM).max() { LabeledContent("历史最佳 e1RM（估算）", value: "\(store.settings.unit.display(best).formattedValue) \(store.settings.unit.rawValue)") }
                            if let relative = StrengthAnalysisService.relativeStrength(latest, weights: store.bodyWeights) {
                                LabeledContent("最近表现的相对力量", value: "\(relative.formattedValue) 倍体重")
                                Text("使用该训练日或之前 30 天内最近一次体重。").font(.caption).foregroundStyle(.secondary)
                            } else { Text("有适用 e1RM 和训练当日或之前 30 天内的体重时，才计算相对力量。").font(.caption).foregroundStyle(.secondary) }
                            Text(performances.filter { $0.estimated1RM != nil }.isEmpty ? "暂无估算数据" : comparison == nil ? "数据有限 · 尚不足以比较两个周期" : "数据充足 · 可比较前后两个周期").font(.caption).foregroundStyle(.secondary)
                        } else { EmptyStateView(title: "还没有这个动作的有效表现", message: "记录已完成正式组。适用动作填写 1–10 次、RPE ≥8 或 RIR ≤2 后，可提供 e1RM 估算。", symbol: "dumbbell") }
                    }
                    strengthChart(exercise, performances: performances)
                    AppCard {
                        SectionHeader(title: "前后周期比较", subtitle: "最近 28 天 vs 之前 28 天 · 每日最佳 e1RM 的平均值")
                        if let comparison {
                            LabeledContent("当前周期", value: "\(store.settings.unit.display(comparison.current).formattedValue) \(store.settings.unit.rawValue)")
                            LabeledContent("上一周期", value: "\(store.settings.unit.display(comparison.previous).formattedValue) \(store.settings.unit.rawValue)")
                            Text("变化 \(comparison.percent >= 0 ? "+" : "")\(comparison.percent.formattedValue)%").font(.title3.weight(.semibold)).foregroundStyle(comparison.percent >= 0 ? .green : .orange)
                            Text("比较同一动作、器械与负重口径；每个周期至少包含 2 个有效训练日。估算变化不等于实际最大重量变化。").font(.caption).foregroundStyle(.secondary)
                        } else { Text("每个周期至少需要 2 个具有有效 e1RM 的训练日。目前不生成增长或下降结论。").font(.subheadline).foregroundStyle(.secondary) }
                    }
                    let records = PersonalRecordService.records(store.completed, exercise: exercise)
                    if !records.isEmpty {
                        AppCard {
                            SectionHeader(title: "个人纪录", subtitle: "点击追溯原始训练组")
                            ForEach(records.filter { $0.type != .repetitions }) { record in
                                NavigationLink { SessionDetailView(sessionID: record.sessionID, highlightedSetID: record.setID) } label: { RecordRow(record: record, unit: store.settings.unit) }.buttonStyle(.plain)
                            }
                            DisclosureGroup("同重量最多次数") {
                                ForEach(records.filter { $0.type == .repetitions }.sorted { ($0.weightKg ?? 0) > ($1.weightKg ?? 0) }) { record in
                                    NavigationLink { SessionDetailView(sessionID: record.sessionID, highlightedSetID: record.setID) } label: { RecordRow(record: record, unit: store.settings.unit).padding(.vertical, 6) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else { AppCard { EmptyStateView(title: "还没有负重动作", message: "在动作库创建动作后，可开始积累力量记录。") } }
                representatives
                MuscleMapCard(title: "长期训练结构", model: MuscleHeatmapViewModel(sessions: store.completed, interval: TimeRange.quarter.interval(now: clock.now, calendar: clock.calendar), metric: .weightedSets)) { selectedMuscle = $0 }
                AppCard {
                    SectionHeader(title: "训练洞察", subtitle: "本地规则分析 · 只描述已有记录")
                    ForEach(TrainingInsightService.insights(store.sessions), id: \.self) { insight in Label { Text(insight).font(.subheadline) } icon: { Image(systemName: "sparkle").foregroundStyle(.blue) } }
                }
                NavigationLink { DataRulesView() } label: { Label("了解力量与统计的计算方式", systemImage: "info.circle").font(.subheadline).frame(minHeight: 44) }
            }.padding(20)
        }.background(AppTheme.background).navigationTitle("我的力量")
            .sheet(item: $choosingPattern) { pattern in NavigationStack { RepresentativePicker(pattern: pattern) } }
            .sheet(item: $selectedMuscle) { muscle in NavigationStack { MuscleDetailSheet(muscle: muscle, interval: TimeRange.quarter.interval(now: clock.now, calendar: clock.calendar)) } }
    }
    private func strengthChart(_ exercise: Exercise, performances: [Performance]) -> some View {
        let values = StrengthAnalysisService.dailyBest(performances).filter { range.interval(now: clock.now, calendar: clock.calendar).includes($0.date) }
        return ChartContainer(title: "力量发展趋势", subtitle: "每日最佳估算 1RM · \(store.settings.unit.rawValue)") {
            Picker("力量趋势时间", selection: $range) { ForEach(TimeRange.allCases.filter { $0 != .today }) { Text($0.name).tag($0) } }.pickerStyle(.menu)
            if values.isEmpty { EmptyStateView(title: "暂无适用估算", message: exercise.allowsEstimate ? "只采用有效正式组：1–10 次，RPE ≥8 或 RIR ≤2。缺失努力程度时不估算。" : "此动作未启用 e1RM。你仍可以记录训练并查看实际重量与次数纪录。", symbol: "chart.xyaxis.line") }
            else {
                Chart(values) { p in
                    if let estimate = p.estimated1RM {
                        LineMark(x: .value("日期", p.date), y: .value("估算 1RM", store.settings.unit.display(estimate))).foregroundStyle(.blue)
                        PointMark(x: .value("日期", p.date), y: .value("估算 1RM", store.settings.unit.display(estimate))).foregroundStyle(.blue).symbolSize(30)
                    }
                }.chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month().day()) } }.frame(height: 210)
                Text("Epley：重量 × (1 + 次数 / 30)。单次重复保留实际重量；该曲线始终是估算，不代表完成过相应负重。").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("逐日数据") {
                    ForEach(values.reversed()) { value in
                        NavigationLink { SessionDetailView(sessionID: value.sessionID, highlightedSetID: value.setID) } label: {
                            LabeledContent(value.date.formatted(date: .abbreviated, time: .omitted), value: "\(store.settings.unit.display(value.estimated1RM ?? 0).formattedValue) \(store.settings.unit.rawValue)")
                        }.font(.subheadline).frame(minHeight: 44)
                    }
                }
            }
        }
    }
    private var representatives: some View {
        AppCard {
            SectionHeader(title: "六大动作模式", subtitle: "为每种模式选择自己的代表动作")
            ForEach(MovementPattern.allCases) { pattern in
                let selected = store.exercises.first { $0.id == store.settings.representatives[pattern.rawValue] }
                VStack(alignment: .leading, spacing: 5) {
                    HStack { Text(pattern.name).font(.subheadline.weight(.medium)); Spacer(); Button(selected?.name ?? "选择动作") { choosingPattern = pattern }.font(.subheadline) }
                    if let selected {
                        let values = StrengthAnalysisService.performances(store.completed, exercise: selected)
                        if let latest = values.last {
                            Button { selectedKey = selected.comparisonKey } label: { Text("最近 \(store.settings.unit.display(latest.weightKg).formattedValue) \(store.settings.unit.rawValue) × \(latest.reps) · 点击分析此动作").font(.caption) }
                        } else { Text("暂缺适用负重数据；自重与辅助动作可在历史页查看次数表现。").font(.caption).foregroundStyle(.secondary) }
                    }
                }.padding(.vertical, 6)
            }
        }
    }
}
struct RepresentativePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @Environment(\.dismiss) private var dismiss
    var pattern: MovementPattern
    var body: some View {
        List {
            ForEach(store.exercises.filter { $0.pattern == pattern && !$0.isArchived }) { exercise in
                Button { var settings = store.settings; settings.representatives[pattern.rawValue] = exercise.id; do { try store.updateSettings(settings); dismiss() } catch { store.errorMessage = error.localizedDescription } } label: { ExerciseRow(exercise: exercise) }.buttonStyle(.plain)
            }
            Button("清除代表动作") { var settings = store.settings; settings.representatives.removeValue(forKey: pattern.rawValue); do { try store.updateSettings(settings); dismiss() } catch { store.errorMessage = error.localizedDescription } }
        }.navigationTitle(pattern.name).toolbar { Button("关闭") { dismiss() } }
    }
}

