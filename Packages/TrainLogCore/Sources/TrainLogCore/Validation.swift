import Foundation

public struct ValidationError: LocalizedError, Equatable, Sendable {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum RecordValidator {
    public static func exercise(_ item: Exercise) throws {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, item.name.count <= 100 else { throw ValidationError("动作名称应为 1–100 个字符。") }
        guard !item.primary.isEmpty, Set(item.primary).count == item.primary.count,
              Set(item.secondary).count == item.secondary.count,
              Set(item.primary).isDisjoint(with: item.secondary) else { throw ValidationError("请选择主要肌群；主、次肌群不能重复。") }
        let compatible: Bool
        switch item.tracking {
        case .weightReps: compatible = item.loading == .total || item.loading == .perHand
        case .bodyweightReps: compatible = item.loading == .bodyweight
        case .assistedReps: compatible = item.loading == .assistance
        case .duration: compatible = item.loading == .timeOnly
        }
        guard compatible else { throw ValidationError("记录模式与负重口径不一致。") }
        guard !item.allowsEstimate || item.tracking == .weightReps else { throw ValidationError("此记录模式不能估算 1RM。") }
    }
    public static func trainingSet(_ set: TrainingSet, exercise: Exercise, requireComplete: Bool = false) throws {
        if let timing = set.timing {
            try timing.validate()
            if set.isCompleted && timing.endedAt == nil { throw ValidationError("已完成组不能仍在计时。") }
        }
        if let w = set.weightKg, !w.isFinite || !(0...1500).contains(w) { throw ValidationError("重量应在 0–1500 kg 之间。") }
        if let r = set.reps, !((set.kind == .failed ? 0 : 1)...1000).contains(r) { throw ValidationError("次数应在 1–1000 之间；失败组允许 0 次。") }
        if let d = set.durationSeconds, !(1...86400).contains(d) { throw ValidationError("持续时间应在 1–86400 秒之间。") }
        if let r = set.rpe, !r.isFinite || !(1...10).contains(r) { throw ValidationError("RPE 应在 1–10 之间。") }
        if let r = set.rir, !r.isFinite || !(0...10).contains(r) { throw ValidationError("RIR 应在 0–10 之间。") }
        guard (0...3600).contains(set.restSeconds) else { throw ValidationError("休息时间应在 0–3600 秒之间。") }
        if requireComplete || set.isCompleted {
            switch exercise.tracking {
            case .weightReps, .assistedReps:
                guard set.weightKg != nil, set.reps != nil else { throw ValidationError("完成该组前，请填写重量和次数。") }
            case .bodyweightReps:
                guard set.reps != nil else { throw ValidationError("完成该组前，请填写次数。") }
            case .duration:
                guard set.durationSeconds != nil else { throw ValidationError("完成该组前，请填写持续时间。") }
            }
        }
    }
    public static func isValidCompleted(_ set: TrainingSet, exercise: Exercise) -> Bool {
        set.isCompleted && (try? trainingSet(set, exercise: exercise, requireComplete: true)) != nil
    }
    public static func session(_ session: Session) throws {
        if let plan = session.plan {
            guard session.mode == .detailed, plan.id != session.id, !plan.name.isEmpty, plan.name.count <= 100,
                  plan.scheduledAt.timeIntervalSince1970.isFinite else { throw ValidationError("训练计划来源无效。") }
        }
        let timed = session.exercises.flatMap(\.sets).compactMap(\.timing)
        guard timed.filter({ $0.endedAt == nil }).count <= 1 else { throw ValidationError("同一时间只能计时一组。") }
        for timing in timed {
            guard timing.startedAt >= session.startTime.addingTimeInterval(-1),
                  session.endTime.map({ end in timing.endedAt.map { $0 <= end.addingTimeInterval(1) } ?? true }) ?? true else { throw ValidationError("本组时间超出整场训练范围。") }
            if session.timerStartedAt == nil && timing.timerStartedAt != nil { throw ValidationError("整体暂停时本组也必须暂停。") }
            if session.status == .completed && timing.endedAt == nil { throw ValidationError("结束训练前请先结束本组计时。") }
        }
        if let link = session.watchLink {
            guard session.mode == .detailed, session.phoneLink == nil else { throw ValidationError("只有手机逐组力量训练可以关联手表。") }
            try link.validate(phoneSessionID: session.id)
        }
        if let reference = session.phoneLink {
            guard session.mode == .cardio, session.activity?.kind == .traditionalStrength,
                  session.activity?.hasWatchMeasurements == true, reference.phoneSessionID != session.id else { throw ValidationError("关联手机训练的手表资料无效。") }
        }
        for date in [session.date, session.startTime, session.createdAt, session.updatedAt] + [session.endTime, session.timerStartedAt].compactMap({ $0 }) {
            guard date.timeIntervalSince1970.isFinite else { throw ValidationError("训练日期无效。") }
        }
        guard session.date <= Date().addingTimeInterval(60) else { throw ValidationError("训练日期不能在未来。") }
        guard session.accumulatedSeconds.isFinite, (0...315_576_000).contains(session.accumulatedSeconds) else { throw ValidationError("训练计时数据超出有效范围。") }
        if let d = session.manualDurationSeconds, !(0...604800).contains(d) { throw ValidationError("训练时长应在 0–7 天之间。") }
        guard session.elapsed().isFinite, (0...315_576_000).contains(session.elapsed()) else { throw ValidationError("计时数据无效。") }
        if session.status == .completed && session.elapsed() > 604800 { throw ValidationError("计时超过 7 天，请手动修正训练时长。") }
        if let timer = session.timerStartedAt, timer > Date().addingTimeInterval(60) { throw ValidationError("计时开始时间不能在未来。") }
        if let rpe = session.sessionRPE, !rpe.isFinite || !(1...10).contains(rpe) { throw ValidationError("整次训练 RPE 应在 1–10 之间。") }
        guard Set(session.quickEntries.map(\.muscle)).count == session.quickEntries.count else { throw ValidationError("快速记录包含重复肌群。") }
        if session.mode == .cardio {
            guard session.quickEntries.isEmpty, session.exercises.isEmpty, let activity = session.activity else { throw ValidationError("运动记录不能混入力量组或快速肌群。") }
            try activityRecord(activity)
            if session.status == .completed && activity.hasWatchMeasurements && activity.watchWorkoutID == nil { throw ValidationError("手表训练缺少已保存的健康记录标识。") }
            let end = session.endTime ?? Date()
            guard activity.heartRate.allSatisfy({ $0.date >= session.startTime && $0.date <= end.addingTimeInterval(5) }) else { throw ValidationError("心率采样超出本次训练的时间范围。") }
            if session.status == .completed && session.elapsed() <= 0 { throw ValidationError("请记录大于零的运动时长。") }
        } else if session.mode == .quick {
            guard session.exercises.isEmpty else { throw ValidationError("快速记录不能包含详细动作。") }
            if session.status == .completed && session.quickEntries.isEmpty { throw ValidationError("请至少选择一个肌群。") }
        } else {
            guard session.quickEntries.isEmpty else { throw ValidationError("详细记录不能包含快速肌群条目。") }
            for entry in session.exercises {
                try exercise(entry.exercise)
                for set in entry.sets { try trainingSet(set, exercise: entry.exercise) }
            }
            if session.status == .completed && !session.exercises.contains(where: { e in e.sets.contains { isValidCompleted($0, exercise: e.exercise) } }) {
                throw ValidationError("请至少完成一个有效训练组，再结束训练。")
            }
        }
        if session.mode != .cardio && session.activity != nil { throw ValidationError("身体数据应保存在独立运动记录中。") }
        if session.status == .completed {
            guard let end = session.endTime, end >= session.startTime, end <= Date().addingTimeInterval(60), session.timerStartedAt == nil else { throw ValidationError("已完成训练的起止时间或计时状态无效。") }
        }
    }
    public static func activityRecord(_ value: ActivityRecord) throws {
        if let distance = value.distanceMeters {
            guard value.kind.supportsDistance, distance.isFinite, (0...2_000_000).contains(distance) else { throw ValidationError("此运动的距离无效，应在 0–2000 km 之间。") }
        }
        if let energy = value.activeEnergyKcal, !energy.isFinite || !(0...100_000).contains(energy) { throw ValidationError("活动能量数据无效。") }
        for heart in [value.averageHeartRate, value.maximumHeartRate].compactMap({ $0 }) {
            guard heart.isFinite, (20...300).contains(heart) else { throw ValidationError("心率数据无效。") }
        }
        if let mean = value.averageHeartRate, let maximum = value.maximumHeartRate, mean > maximum { throw ValidationError("平均心率不能大于最高心率。") }
        guard value.heartRate.count <= 10_000, value.heartRate.allSatisfy({ $0.date.timeIntervalSince1970.isFinite && $0.bpm.isFinite && (20...300).contains($0.bpm) }) else { throw ValidationError("心率采样数据无效或过多。") }
        guard ["manual", "appleWatch"].contains(value.source) else { throw ValidationError("运动数据来源无效。") }
        if !value.hasWatchMeasurements && (value.activeEnergyKcal != nil || value.averageHeartRate != nil || value.maximumHeartRate != nil || !value.heartRate.isEmpty || value.watchWorkoutID != nil) { throw ValidationError("传感器数据必须标记其手表来源。") }
    }
    public static func settings(_ value: Settings) throws {
        guard (1...14).contains(value.weeklyGoal), (0...3600).contains(value.restSeconds) else { throw ValidationError("每周目标或休息时间超出范围。") }
        guard value.representatives.keys.allSatisfy({ MovementPattern(rawValue: $0) != nil }) else { throw ValidationError("代表动作模式无效。") }
    }
    public static func bodyWeight(_ value: BodyWeight) throws {
        guard value.weightKg.isFinite, (20...500).contains(value.weightKg) else { throw ValidationError("体重应在 20–500 kg 之间。") }
        guard value.date.timeIntervalSince1970.isFinite, value.date <= Date().addingTimeInterval(60) else { throw ValidationError("体重日期无效或在未来。") }
    }
}

