import Foundation

public struct Performance: Identifiable, Sendable {
    public var id: UUID { setID }
    public var sessionID: UUID
    public var setID: UUID
    public var date: Date
    public var weightKg: Double
    public var reps: Int
    public var estimated1RM: Double?
}
public struct StrengthComparison: Sendable {
    public var current: Double
    public var previous: Double
    public var percent: Double { (current / previous - 1) * 100 }
}
public enum StrengthAnalysisService {
    public static func estimate(_ set: TrainingSet, exercise: Exercise) -> Double? {
        guard exercise.allowsEstimate, exercise.tracking == .weightReps, set.kind == .working,
              RecordValidator.isValidCompleted(set, exercise: exercise), let weight = set.weightKg, weight > 0,
              let reps = set.reps, (1...10).contains(reps), set.rpe != nil || set.rir != nil,
              set.rpe.map({ $0 >= 8 }) ?? true, set.rir.map({ $0 <= 2 }) ?? true else { return nil }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }
    public static func performances(_ sessions: [Session], exercise: Exercise) -> [Performance] {
        sessions.filter { $0.status == .completed }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }.flatMap { session in
            session.exercises.filter { $0.exercise.comparisonKey == exercise.comparisonKey }.flatMap { entry in
                WorkoutStatisticsService.workingSets(entry).compactMap { set -> Performance? in
                    guard entry.exercise.tracking == .weightReps, let weight = set.weightKg, let reps = set.reps else { return nil }
                    return Performance(sessionID: session.id, setID: set.id, date: session.date, weightKg: weight, reps: reps, estimated1RM: estimate(set, exercise: entry.exercise))
                }
            }
        }
    }
    public static func dailyBest(_ values: [Performance], calendar: Calendar = .current) -> [Performance] {
        Dictionary(grouping: values.filter { $0.estimated1RM != nil }) { calendar.startOfDay(for: $0.date) }
            .values.compactMap { $0.max { ($0.estimated1RM ?? 0) < ($1.estimated1RM ?? 0) } }.sorted { $0.date < $1.date }
    }
    public static func compare(_ values: [Performance], now: Date = Date(), calendar: Calendar = .current) -> StrengthComparison? {
        let end = TimeRange.today.interval(now: now, calendar: calendar).end
        guard let split = calendar.date(byAdding: .day, value: -28, to: end), let start = calendar.date(byAdding: .day, value: -56, to: end) else { return nil }
        let daily = dailyBest(values, calendar: calendar)
        let current = daily.filter { $0.date >= split && $0.date < end }.compactMap(\.estimated1RM)
        let previous = daily.filter { $0.date >= start && $0.date < split }.compactMap(\.estimated1RM)
        guard current.count >= 2, previous.count >= 2 else { return nil }
        let a = current.reduce(0, +) / Double(current.count), b = previous.reduce(0, +) / Double(previous.count)
        guard b > 0 else { return nil }
        return StrengthComparison(current: a, previous: b)
    }
    public static func relativeStrength(_ value: Performance, weights: [BodyWeight], calendar: Calendar = .current) -> Double? {
        guard let estimate = value.estimated1RM,
              let weight = weights.filter({ calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: value.date) }).max(by: { $0.date < $1.date }),
              let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: weight.date), to: calendar.startOfDay(for: value.date)).day,
              (0...30).contains(age), weight.weightKg > 0 else { return nil }
        return estimate / weight.weightKg
    }
}
public enum RecordType: String, Sendable { case weight = "最大实际重量", estimated = "最佳估算 1RM", repetitions = "同重量最多次数", volume = "单次最高容量" }
public struct PersonalRecord: Identifiable, Sendable {
    public var id: String { "\(exerciseID)|\(type.rawValue)|\(sessionID)|\(setID?.uuidString ?? "session")" }
    public var type: RecordType
    public var exerciseID: UUID
    public var exerciseName: String
    public var sessionID: UUID
    public var setID: UUID?
    public var date: Date
    public var value: Double
    public var weightKg: Double?
}
public enum PersonalRecordService {
    public static func records(_ sessions: [Session], exercise: Exercise) -> [PersonalRecord] {
        let values = StrengthAnalysisService.performances(sessions, exercise: exercise)
        guard !values.isEmpty else { return [] }
        var result: [PersonalRecord] = []
        func add(_ type: RecordType, _ p: Performance, _ value: Double, weight: Double? = nil) {
            result.append(PersonalRecord(type: type, exerciseID: exercise.id, exerciseName: exercise.name, sessionID: p.sessionID, setID: p.setID, date: p.date, value: value, weightKg: weight))
        }
        if let best = values.max(by: { $0.weightKg < $1.weightKg }) { add(.weight, best, best.weightKg) }
        if let best = values.filter({ $0.estimated1RM != nil }).max(by: { ($0.estimated1RM ?? 0) < ($1.estimated1RM ?? 0) }), let estimate = best.estimated1RM { add(.estimated, best, estimate) }
        // Tolerance is applied only to the grouping key, preserving original weight in the record.
        for group in Dictionary(grouping: values, by: { Int(($0.weightKg * 1000).rounded()) }).values {
            if let best = group.max(by: { $0.reps < $1.reps }) { add(.repetitions, best, Double(best.reps), weight: best.weightKg) }
        }
        let volumes: [(Session, Double)] = sessions.filter { $0.status == .completed }.compactMap { session in
            let amounts = session.exercises.filter { $0.exercise.comparisonKey == exercise.comparisonKey }.flatMap { entry in entry.sets.compactMap { WorkoutStatisticsService.volume($0, exercise: entry.exercise) } }
            return amounts.isEmpty ? nil : (session, amounts.reduce(0, +))
        }
        if let (session, volume) = volumes.max(by: { $0.1 < $1.1 }) {
            result.append(PersonalRecord(type: .volume, exerciseID: exercise.id, exerciseName: exercise.name, sessionID: session.id, setID: nil, date: session.date, value: volume, weightKg: nil))
        }
        return result.sorted { $0.date > $1.date }
    }
    public static func newRecords(for session: Session, all: [Session]) -> [PersonalRecord] {
        let previous = all.filter { $0.id != session.id && $0.date <= session.date }
        let unique = Dictionary(grouping: session.exercises, by: { $0.exercise.comparisonKey }).values.compactMap(\.first)
        return unique.flatMap { entry in
            let before = records(previous, exercise: entry.exercise)
            return records(previous + [session], exercise: entry.exercise).filter { record in
                guard record.sessionID == session.id else { return false }
                let prior = before.filter { $0.type == record.type && ($0.type != .repetitions || abs(($0.weightKg ?? 0) - (record.weightKg ?? 0)) < 0.001) }
                return prior.allSatisfy { record.value > $0.value + 0.00001 }
            }
        }
    }
}
public enum TrainingInsightService {
    public static func insights(_ sessions: [Session], now: Date = Date(), calendar: Calendar = .current) -> [String] {
        let completed = sessions.filter { $0.status == .completed }
        guard let first = completed.map(\.date).min() else { return ["记录第一次训练后，这里会显示来自真实记录的变化。"] }
        let stats = MuscleHeatmapService.statistics(completed, interval: TimeRange.month.interval(now: now, calendar: calendar), calendar: calendar)
        var result: [String] = []
        if let chest = stats.first(where: { $0.muscle == .chest }), let back = stats.first(where: { $0.muscle == .lats }), chest.trainingDays != back.trainingDays {
            result.append("近 30 天：胸部记录 \(chest.trainingDays) 天，背阔肌记录 \(back.trainingDays) 天。这反映记录分布，不代表训练是否充分。")
        }
        if let start = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)), first < start {
            let trainedBefore = completed.filter { $0.date < start }.reduce(into: Set<MuscleGroup>()) { $0.formUnion(MuscleMappingService.coverage(of: $1)) }
            let trainedNow = completed.filter { $0.date >= start }.reduce(into: Set<MuscleGroup>()) { $0.formUnion(MuscleMappingService.coverage(of: $1)) }
            let missing = trainedBefore.subtracting(trainedNow).sorted { $0.rawValue < $1.rawValue }.prefix(3)
            if !missing.isEmpty { result.append("最近 14 天没有\(missing.map(\.name).joined(separator: "、"))的训练记录。可检查是否漏记。") }
        }
        if WorkoutStatisticsService.totals(completed, calendar: calendar).trainingDays < 4 { result.append("数据有限：目前训练日较少，暂不判断长期进步趋势。") }
        return result.isEmpty ? ["训练记录正在积累。力量周期比较需要前后各 28 天内至少 2 个有效训练日。"] : result
    }
}

