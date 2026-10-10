import Foundation

public enum MuscleMappingService {
    public static func weights(for exercise: Exercise) -> [MuscleGroup: Double] {
        var weights: [MuscleGroup: Double] = [:]
        for muscle in exercise.secondary { weights[muscle] = 0.5 }
        for muscle in exercise.primary { weights[muscle] = 1 }
        return weights
    }
    public static func coverage(of session: Session) -> Set<MuscleGroup> {
        guard session.status == .completed else { return [] }
        if session.mode == .quick { return Set(session.quickEntries.map(\.muscle)) }
        return session.exercises.reduce(into: Set<MuscleGroup>()) { result, entry in
            if entry.sets.contains(where: { ($0.kind == .working || $0.kind == .drop) && RecordValidator.isValidCompleted($0, exercise: entry.exercise) }) {
                result.formUnion(weights(for: entry.exercise).keys)
            }
        }
    }
}
public struct WorkoutTotals: Equatable, Sendable {
    public var sessions: Int = 0
    public var trainingDays: Int = 0
    public var workingSets: Int = 0
    public var volumeKg: Double? = nil
    public var durationSeconds: Double = 0
}
public enum WorkoutStatisticsService {
    public static func workingSets(_ entry: ExerciseEntry) -> [TrainingSet] {
        entry.sets.filter { $0.kind == .working && RecordValidator.isValidCompleted($0, exercise: entry.exercise) }
    }
    public static func volume(_ set: TrainingSet, exercise: Exercise) -> Double? {
        guard set.kind == .working, RecordValidator.isValidCompleted(set, exercise: exercise),
              exercise.tracking == .weightReps, let weight = set.weightKg, let reps = set.reps else { return nil }
        return weight * Double(reps) * exercise.loading.volumeMultiplier
    }
    public static func totals(_ sessions: [Session], interval: DateInterval? = nil, calendar: Calendar = .current) -> WorkoutTotals {
        let completed = sessions.filter { $0.status == .completed && (interval?.includes($0.date) ?? true) }
        let volumes = completed.flatMap(\.exercises).flatMap { entry in entry.sets.compactMap { volume($0, exercise: entry.exercise) } }
        return WorkoutTotals(sessions: completed.count, trainingDays: Set(completed.map { calendar.startOfDay(for: $0.date) }).count,
                             workingSets: completed.flatMap(\.exercises).reduce(0) { $0 + workingSets($1).count },
                             volumeKg: volumes.isEmpty ? nil : volumes.reduce(0, +),
                             durationSeconds: completed.reduce(0) { $0 + $1.elapsed() })
    }
}
public struct MuscleStatistics: Identifiable, Sendable {
    public var muscle: MuscleGroup
    public var id: MuscleGroup { muscle }
    public var trainingDays: Int = 0
    public var primarySets: Int = 0
    public var relatedSets: Int = 0
    public var weightedSets: Double = 0
    public var meanIntensity: Double?
    public var lastTrained: Date?
    public var exerciseNames: [String] = []
}
public enum HeatMetric: String, CaseIterable, Identifiable, Sendable {
    case coverage, days, weightedSets, intensity
    public var id: String { rawValue }
    public var name: String {
        switch self { case .coverage: return "训练覆盖"; case .days: return "训练天数"; case .weightedSets: return "加权正式组数"; case .intensity: return "主观强度" }
    }
    public var legend: [String] {
        switch self {
        case .coverage: return ["无记录", "有记录"]
        case .days: return ["0", "1", "2–3", "4–6", "≥7 天"]
        case .weightedSets: return ["0", "<4", "4–<8", "8–<12", "≥12 组"]
        case .intensity: return ["无强度", "轻", "轻–中", "中–高", "高"]
        }
    }
    public var explanation: String {
        switch self {
        case .coverage: return "快速记录或有效已完成的正式、递减组产生覆盖；热身与失败组不产生覆盖。无记录不代表未运动。"
        case .days: return "按设备当前时区的自然日去重。同一天的快速与详细记录，每个肌群只计 1 天。"
        case .weightedSets: return "仅有效已完成正式组：主要肌群 × 1，次要肌群 × 0.5。是动作分类近似值，不是实际肌肉激活量或精准增肌刺激。固定阈值，不按最大值拉伸。"
        case .intensity: return "只使用明确填写的轻／中／高，序数为 1／2／3，先按日平均再按天平均。RPE、RIR 单独展示，不换算为组数、容量或力量。灰色表示缺少强度记录。"
        }
    }
}
public enum MuscleHeatmapService {
    public static func statistics(_ sessions: [Session], interval: DateInterval, calendar: Calendar = .current) -> [MuscleStatistics] {
        let completed = sessions.filter { $0.status == .completed && interval.includes($0.date) }
        return MuscleGroup.allCases.map { muscle in
            var stat = MuscleStatistics(muscle: muscle)
            var days = Set<Date>(); var intensities: [Date: [Double]] = [:]; var names: [String: Int] = [:]
            for session in completed where MuscleMappingService.coverage(of: session).contains(muscle) {
                let day = calendar.startOfDay(for: session.date)
                days.insert(day); stat.lastTrained = max(stat.lastTrained ?? session.date, session.date)
                let intensity = session.quickEntries.first(where: { $0.muscle == muscle })?.intensity ?? session.intensity
                if let intensity { intensities[day, default: []].append(intensity.ordinal) }
                for entry in session.exercises {
                    guard let weight = MuscleMappingService.weights(for: entry.exercise)[muscle] else { continue }
                    let count = WorkoutStatisticsService.workingSets(entry).count
                    stat.relatedSets += count
                    stat.primarySets += entry.exercise.primary.contains(muscle) ? count : 0
                    stat.weightedSets += Double(count) * weight
                    if count > 0 { names[entry.exercise.name, default: 0] += count }
                }
            }
            stat.trainingDays = days.count
            let daily = intensities.values.map { $0.reduce(0, +) / Double($0.count) }
            stat.meanIntensity = daily.isEmpty ? nil : daily.reduce(0, +) / Double(daily.count)
            stat.exerciseNames = names.keys.sorted { names[$0, default: 0] == names[$1, default: 0] ? $0 < $1 : names[$0, default: 0] > names[$1, default: 0] }
            return stat
        }
    }
    public static func level(_ stat: MuscleStatistics, metric: HeatMetric) -> Int {
        switch metric {
        case .coverage: return stat.trainingDays > 0 ? 3 : 0
        case .days: switch stat.trainingDays { case 0: return 0; case 1: return 1; case 2...3: return 2; case 4...6: return 3; default: return 4 }
        case .weightedSets:
            let n = stat.weightedSets
            return n == 0 ? 0 : n < 4 ? 1 : n < 8 ? 2 : n < 12 ? 3 : 4
        case .intensity:
            guard let n = stat.meanIntensity else { return 0 }
            return n <= 1 ? 1 : n < 2 ? 2 : n < 3 ? 3 : 4
        }
    }
}
public struct DailyStatistic: Identifiable, Sendable {
    public var date: Date
    public var id: Date { date }
    public var totals: WorkoutTotals
    public var meanRPE: Double?
}
public enum TrendAnalysisService {
    public static func daily(_ sessions: [Session], interval: DateInterval, calendar: Calendar = .current) -> [DailyStatistic] {
        let groups = Dictionary(grouping: sessions.filter { $0.status == .completed && interval.includes($0.date) }) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { date in
            let items = groups[date, default: []]
            let rpes = items.compactMap(\.sessionRPE)
            return DailyStatistic(date: date, totals: WorkoutStatisticsService.totals(items, calendar: calendar), meanRPE: rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count))
        }
    }
}

