import SwiftUI
import Charts
import TrainLogCore

struct MuscleDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var muscle: MuscleGroup
    var interval: DateInterval
    var sessionScope: Set<UUID>? = nil
    private var source: [Session] { store.completed.filter { sessionScope?.contains($0.id) ?? true } }
    private var stat: MuscleStatistics? { MuscleHeatmapService.statistics(source, interval: interval).first { $0.muscle == muscle } }
    private var records: [Session] { source.filter { interval.includes($0.date) && MuscleMappingService.coverage(of: $0).contains(muscle) } }
    var body: some View {
        List {
            if let stat {
                Section("当前时间范围") {
                    LabeledContent("最近训练", value: stat.lastTrained?.formatted(date: .abbreviated, time: .omitted) ?? "暂无记录")
                    LabeledContent("训练天数", value: "\(stat.trainingDays) 天")
                    LabeledContent("主要肌群正式组", value: "\(stat.primarySets) 组")
                    LabeledContent("相关动作正式组（未加权）", value: "\(stat.relatedSets) 组")
                    LabeledContent("加权正式组数", value: "\(stat.weightedSets.formattedValue) 组")
                    Text(HeatMetric.weightedSets.explanation).font(.caption).foregroundStyle(.secondary)
                }
                if !stat.exerciseNames.isEmpty { Section("常见相关动作") { ForEach(stat.exerciseNames, id: \.self) { Text($0) } } }
                if records.count > 1 {
                    Section("逐日加权组数") {
                        let groups = Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.date) }
                        Chart(groups.keys.sorted(), id: \.self) { date in
                            let amount = MuscleHeatmapService.statistics(groups[date, default: []], interval: interval).first { $0.muscle == muscle }?.weightedSets ?? 0
                            BarMark(x: .value("日期", date, unit: .day), y: .value("加权组", amount)).foregroundStyle(.blue)
                        }.frame(height: 160)
                    }
                }
            }
            Section("相关训练 · \(records.count) 次") {
                ForEach(records) { session in NavigationLink { SessionDetailView(sessionID: session.id) } label: { SessionRow(session: session) } }
                if records.isEmpty { Text("这个时间范围内没有对应肌群记录，不代表你的身体状态异常。").foregroundStyle(.secondary) }
            }
        }.navigationTitle(muscle.name + "训练").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}

