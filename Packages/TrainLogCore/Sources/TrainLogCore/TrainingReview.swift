import Foundation

public struct PlanSetReview: Identifiable, Sendable {
    public var id: UUID
    public var number: Int
    public var target: TrainingSet?
    public var actual: TrainingSet?
    public var changed: Bool {
        guard let target, let actual else { return true }
        return target.weightKg != actual.weightKg || target.reps != actual.reps || target.durationSeconds != actual.durationSeconds || target.kind != actual.kind || target.restSeconds != actual.restSeconds
    }
}
public struct PlanExerciseReview: Identifiable, Sendable {
    public var id: UUID
    public var exercise: Exercise
    public var actualExercise: Exercise?
    public var sets: [PlanSetReview]
    public var wasAdded: Bool
    public var wasRemoved: Bool
    public var conventionChanged: Bool { actualExercise.map { $0.comparisonKey != exercise.comparisonKey } ?? false }
}
public struct PlanReview: Sendable {
    public var exercises: [PlanExerciseReview]
    public var plannedSets: Int
    public var completedWorkingSets: Int
    public var changedSets: Int
    public var timedCompletedSets: Int
    public var untimedCompletedSets: Int
    public var recordedSetSeconds: TimeInterval
}
public enum PlanReviewService {
    public static func validateTargets(_ targets: [ExerciseEntry]?) throws {
        guard let targets else { return }
        guard !targets.isEmpty, targets.count <= 100, Set(targets.map(\.id)).count == targets.count else { throw ValidationError("开练时计划快照无效。") }
        var ids = Set<UUID>()
        for entry in targets {
            try RecordValidator.exercise(entry.exercise)
            guard (1...30).contains(entry.sets.count) else { throw ValidationError("计划快照组数无效。") }
            for set in entry.sets {
                guard ids.insert(set.id).inserted, !set.isCompleted, set.timing == nil, set.kind == .working else { throw ValidationError("计划快照不能包含重复、已完成或计时中的组。") }
                try RecordValidator.trainingSet(set, exercise: entry.exercise)
            }
        }
    }
    public static func review(_ session: Session) -> PlanReview? {
        guard let targets = session.plan?.targets else { return nil }
        let actual = Dictionary(session.exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let targetIDs = Set(targets.map(\.id))
        var rows: [PlanExerciseReview] = targets.map { target in
            let entry = actual[target.id]
            let actualSets = Dictionary((entry?.sets ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let plannedIDs = Set(target.sets.map(\.id))
            var sets = target.sets.enumerated().map { index, set in PlanSetReview(id: set.id, number: index + 1, target: set, actual: actualSets[set.id]) }
            sets += (entry?.sets ?? []).enumerated().filter { !plannedIDs.contains($0.element.id) }.map { index, set in PlanSetReview(id: set.id, number: index + 1, target: nil, actual: set) }
            return PlanExerciseReview(id: target.id, exercise: target.exercise, actualExercise: entry?.exercise, sets: sets, wasAdded: false, wasRemoved: entry == nil)
        }
        rows += session.exercises.filter { !targetIDs.contains($0.id) }.map { entry in
            PlanExerciseReview(id: entry.id, exercise: entry.exercise, actualExercise: entry.exercise, sets: entry.sets.enumerated().map { index, set in PlanSetReview(id: set.id, number: index + 1, target: nil, actual: set) }, wasAdded: true, wasRemoved: false)
        }
        let completed = session.exercises.flatMap(\.sets).filter(\.isCompleted)
        let timed = completed.compactMap { $0.timing }.filter { $0.endedAt != nil }
        return PlanReview(exercises: rows, plannedSets: targets.reduce(0) { $0 + $1.sets.count }, completedWorkingSets: session.exercises.reduce(0) { count, entry in count + entry.sets.filter { $0.kind == .working && RecordValidator.isValidCompleted($0, exercise: entry.exercise) }.count }, changedSets: rows.flatMap(\.sets).filter(\.changed).count, timedCompletedSets: timed.count, untimedCompletedSets: completed.count - timed.count, recordedSetSeconds: timed.reduce(0) { $0 + $1.elapsed() })
    }
    /// A fresh editable plan; only actual completed working sets are copied.
    /// Consecutive equal configurations are grouped without erasing varied loads.
    public static func copiedPlan(from session: Session, scheduledAt: Date, catalog: [Exercise]) throws -> TrainingPlan {
        guard session.status == .completed, session.mode == .detailed else { throw ValidationError("请从已完成的力量训练创建计划。") }
        var items: [TemplateItem] = []
        for entry in session.exercises {
            for set in entry.sets where set.kind == .working && RecordValidator.isValidCompleted(set, exercise: entry.exercise) {
                let next = TemplateItem(exerciseID: entry.exercise.id, setCount: 1, weightKg: set.weightKg, reps: set.reps, durationSeconds: set.durationSeconds, restSeconds: set.restSeconds)
                if let last = items.last, last.exerciseID == next.exerciseID, last.setCount < 30, last.weightKg == next.weightKg, last.reps == next.reps, last.durationSeconds == next.durationSeconds, last.restSeconds == next.restSeconds {
                    items[items.count - 1].setCount += 1
                } else { items.append(next) }
            }
        }
        guard items.count <= 100 else { throw ValidationError("实际配置超过100项，请手动精简后建立计划。") }
        var plan = TrainingPlan(name: (session.plan?.name ?? "力量训练") + " · 复用实际", scheduledAt: scheduledAt, items: items)
        plan.name = String(plan.name.prefix(100)); plan.notes = session.notes
        try plan.validate(catalog: catalog)
        return plan
    }
}
