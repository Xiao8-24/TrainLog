import Foundation

public enum TargetSuggestionKind: String, Sendable { case unavailable, maintain, addRepetition, increaseLoad }
public struct TargetEvidence: Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var sets: [TrainingSet]
}
public struct TargetSuggestion: Sendable {
    public var kind: TargetSuggestionKind
    public var original: TemplateItem
    public var proposed: TemplateItem?
    public var reasons: [String]
    public var evidence: [TargetEvidence]
    public var canApply: Bool { kind == .addRepetition || kind == .increaseLoad }
    public var title: String {
        switch kind { case .unavailable: return "暂不生成目标"; case .maintain: return "先维持当前目标"; case .addRepetition: return "可尝试多一次"; case .increaseLoad: return "可考虑小幅加重" }
    }
}
/// Local, inspectable planning heuristics; never updates a workout, diagnoses
/// recovery, or substitutes a session RPE for missing per-set RPE/RIR.
public enum TargetSuggestionService {
    public static func suggest(exercise: Exercise, target: TemplateItem, sessions: [Session], goal: String, at now: Date = Date()) -> TargetSuggestion {
        func result(_ kind: TargetSuggestionKind, _ reason: String, evidence: [TargetEvidence] = [], proposed: TemplateItem? = nil) -> TargetSuggestion {
            TargetSuggestion(kind: kind, original: target, proposed: proposed, reasons: [reason], evidence: evidence)
        }
        guard (try? RecordValidator.exercise(exercise)) != nil, target.exerciseID == exercise.id, (1...30).contains(target.setCount), let reps = target.reps, (5...20).contains(reps), exercise.tracking == .weightReps || exercise.tracking == .bodyweightReps else {
            return result(.unavailable, "本轮只为5–20次的负重或自重次数目标提供参考；辅助重量和持续时间暂不套用同一进阶规则。")
        }
        let sampleSet = TrainingSet(weightKg: target.weightKg, reps: reps)
        guard (try? RecordValidator.trainingSet(sampleSet, exercise: exercise, requireComplete: true)) != nil else { return result(.unavailable, "请先填写有效的当前重量与目标次数。") }
        var seen = Set<UUID>()
        let recent = sessions.filter { seen.insert($0.id).inserted && $0.status == .completed && $0.mode == .detailed && $0.date <= now && $0.endTime.map { $0 <= now } == true && $0.exercises.contains { $0.exercise.comparisonKey == exercise.comparisonKey } }
            .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
        guard recent.count >= 2 else { return result(.unavailable, "至少需要最近两次同动作、同器械与同负重口径的已完成训练；草稿不参与。") }
        let pair = Array(recent.prefix(2))
        guard pair.allSatisfy({ (try? RecordValidator.session($0)) != nil }) else { return result(.unavailable, "参考记录包含无效数据，请先检查原记录。") }
        guard pair.allSatisfy({ now.timeIntervalSince($0.date) <= 60 * 86400 }) else { return result(.unavailable, "最近两次可比训练不都在60天内，请先积累近期记录。") }
        var evidence: [TargetEvidence] = []
        for session in pair {
            let entries = session.exercises.filter { $0.exercise.comparisonKey == exercise.comparisonKey }
            let all = entries.flatMap(\.sets)
            let working = all.filter { $0.kind == .working }
            let completed = working.filter { RecordValidator.isValidCompleted($0, exercise: exercise) }
            evidence.append(TargetEvidence(id: session.id, date: session.date, sets: completed))
            guard completed.count >= max(2, target.setCount), completed.count == working.count else { return result(.maintain, "最近记录中有未完成正式组，或不足当前预设组数；先维持并自行确认下次安排。", evidence: evidence, proposed: target) }
            if all.contains(where: { $0.kind == .failed && $0.isCompleted }) { return result(.maintain, "最近训练记录了失败组，暂不提出增加目标。", evidence: evidence, proposed: target) }
            guard completed.allSatisfy({ set in
                if exercise.tracking == .bodyweightReps { return true }
                guard let weight = set.weightKg, let goalWeight = target.weightKg, weight.isFinite, goalWeight.isFinite else { return false }
                return abs(weight - goalWeight) < 0.0001
            }) else { return result(.unavailable, "最近两次正式组的重量与当前目标不一致，不跨重量或混合配置推算进步。", evidence: evidence) }
            guard completed.allSatisfy({ set in
                guard set.rpe != nil || set.rir != nil else { return false }
                if let rpe = set.rpe, !rpe.isFinite || !(1...10).contains(rpe) { return false }
                if let rir = set.rir, !rir.isFinite || !(0...10).contains(rir) { return false }
                if let rpe = set.rpe, let rir = set.rir, abs((10 - rpe) - rir) > 2 { return false }
                return true
            }) else { return result(.unavailable, "需要每个可比正式组已填写且无明显冲突的RPE或RIR；缺失强度不会补零。", evidence: evidence) }
        }
        guard goal == "提升力量" || goal == "增加肌肉" else { return result(.maintain, "当前训练目标为“\(goal)”；保持规律或记录观察不需要强制增加负荷。", evidence: evidence, proposed: target) }
        let sets = evidence.flatMap(\.sets)
        guard sets.allSatisfy({ ($0.reps ?? 0) >= reps && ($0.rpe.map { $0 <= 8 } ?? true) && ($0.rir.map { $0 >= 2 } ?? true) }) else {
            return result(.maintain, "最近两次尚未全部达到当前次数目标，或已填强度较高；先维持目标。", evidence: evidence, proposed: target)
        }
        var proposed = target
        if exercise.tracking == .weightReps, let weight = target.weightKg, weight >= 5, reps >= 8, sets.allSatisfy({ ($0.reps ?? 0) >= reps + 2 }) {
            let incremented = (weight * 1.02 * 10).rounded() / 10
            if incremented > weight, incremented <= weight * 1.05 {
                proposed.weightKg = incremented
                return result(.increaseLoad, "最近两次同重量的全部正式组均超出目标至少2次，且已填RPE≤8或RIR≥2。给出约2%的重量参考，次数维持；请按器械刻度编辑后再确认。", evidence: evidence, proposed: proposed)
            }
        }
        guard reps < 20 else { return result(.maintain, "当前已到本轮次数参考范围上限；请自行调整训练安排，不自动继续加次数。", evidence: evidence, proposed: target) }
        proposed.reps = reps + 1
        return result(.addRepetition, "最近两次同重量的全部正式组均达到当前目标，且已填RPE≤8或RIR≥2。先给出保持重量、多1次的计划参考。", evidence: evidence, proposed: proposed)
    }
}
