import Foundation

public struct TrainingPlanReference: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var scheduledAt: Date
}
public struct TrainingPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var scheduledAt: Date
    public var items: [TemplateItem]
    public var notes: String = ""
    public var isSkipped = false
    public init(name: String = "力量训练", scheduledAt: Date = Date(), items: [TemplateItem] = []) {
        self.name = name; self.scheduledAt = scheduledAt; self.items = items
    }
    public func session(catalog: [Exercise], at now: Date = Date(), defaultRest: Int = 90) throws -> Session {
        guard !isSkipped else { throw ValidationError("请先将计划恢复为待训练。") }
        try validate(catalog: catalog)
        var result = Session(mode: .detailed, date: now)
        result.plan = TrainingPlanReference(id: id, name: name, scheduledAt: scheduledAt); result.notes = notes
        result.exercises = try items.map { item in
            guard let exercise = catalog.first(where: { $0.id == item.exerciseID }) else { throw ValidationError("计划中的动作不存在，请先编辑计划。") }
            return ExerciseEntry(exercise: exercise, sets: (0..<item.setCount).map { _ in
                var set = TrainingSet(weightKg: item.weightKg, reps: item.reps, durationSeconds: item.durationSeconds)
                set.restSeconds = item.restSeconds ?? defaultRest; return set
            })
        }
        return result
    }
    public func copied(to date: Date) -> Self {
        var copy = self; copy.id = UUID(); copy.scheduledAt = date; copy.isSkipped = false
        copy.items = items.map { item in var value = item; value.id = UUID(); return value }; return copy
    }
    public func validate(catalog: [Exercise]) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
              scheduledAt.timeIntervalSince1970.isFinite, !items.isEmpty, items.count <= 100,
              Set(items.map(\.id)).count == items.count else { throw ValidationError("请填写计划名称并选择1–100个动作。") }
        for item in items {
            guard let exercise = catalog.first(where: { $0.id == item.exerciseID }), (1...30).contains(item.setCount) else { throw ValidationError("计划动作或预设组数无效。") }
            var set = TrainingSet(weightKg: item.weightKg, reps: item.reps, durationSeconds: item.durationSeconds)
            set.restSeconds = item.restSeconds ?? 90
            try RecordValidator.trainingSet(set, exercise: exercise)
        }
    }
}
