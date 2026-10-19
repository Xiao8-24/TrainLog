import Foundation
import SwiftData
import TrainLogCore

enum ModelCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T { try JSONDecoder().decode(type, from: data) }
}

@Model final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date?
    var statusRaw: String
    var modeRaw: String
    var intensityRaw: String?
    var sessionRPE: Double?
    var notes: String
    var accumulatedSeconds: Double
    var timerStartedAt: Date?
    var manualDurationSeconds: Int?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.workoutSession) var exercises: [SessionExercise] = []
    @Relationship(deleteRule: .cascade, inverse: \QuickMuscleEntry.workoutSession) var quickEntries: [QuickMuscleEntry] = []

    init(_ value: Session) {
        id = value.id; date = value.date; startTime = value.startTime; endTime = value.endTime
        statusRaw = value.status.rawValue; modeRaw = value.mode.rawValue; intensityRaw = value.intensity?.rawValue
        sessionRPE = value.sessionRPE; notes = value.notes; accumulatedSeconds = value.accumulatedSeconds
        timerStartedAt = value.timerStartedAt; manualDurationSeconds = value.manualDurationSeconds
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }
    func apply(_ value: Session, context: ModelContext, previous: Session? = nil) throws {
        date = value.date; startTime = value.startTime; endTime = value.endTime
        statusRaw = value.status.rawValue; modeRaw = value.mode.rawValue; intensityRaw = value.intensity?.rawValue
        sessionRPE = value.sessionRPE; notes = value.notes; accumulatedSeconds = value.accumulatedSeconds
        timerStartedAt = value.timerStartedAt; manualDurationSeconds = value.manualDurationSeconds; createdAt = value.createdAt; updatedAt = value.updatedAt
        let oldEntries = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let previousEntries = Dictionary(uniqueKeysWithValues: (previous?.exercises ?? []).map { ($0.id, $0) })
        let keep = Set(value.exercises.map(\.id))
        for old in exercises where !keep.contains(old.id) { context.delete(old) }
        exercises = try value.exercises.enumerated().map { order, entry in
            let model = try oldEntries[entry.id] ?? SessionExercise(entry, order: order)
            if previousEntries[entry.id] != entry || model.order != order { try model.apply(entry, order: order, context: context) }
            model.workoutSession = self
            return model
        }
        let oldQuick = Dictionary(uniqueKeysWithValues: quickEntries.map { ($0.id, $0) })
        let quickIDs = Set(value.quickEntries.map(\.id))
        for old in quickEntries where !quickIDs.contains(old.id) { context.delete(old) }
        quickEntries = value.quickEntries.map { item in
            let model = oldQuick[item.id] ?? QuickMuscleEntry(item)
            model.muscleRaw = item.muscle.rawValue; model.intensityRaw = item.intensity?.rawValue; model.workoutSession = self
            return model
        }
    }
    func value() throws -> Session {
        guard let mode = WorkoutMode(rawValue: modeRaw), let status = SessionStatus(rawValue: statusRaw) else { throw ValidationError("数据库中的训练模式无效。原始文件已保留。") }
        var s = Session(mode: mode, date: date)
        s.id = id; s.startTime = startTime; s.endTime = endTime; s.status = status
        s.intensity = intensityRaw.flatMap(Intensity.init(rawValue:)); s.sessionRPE = sessionRPE; s.notes = notes
        s.accumulatedSeconds = accumulatedSeconds; s.timerStartedAt = timerStartedAt; s.manualDurationSeconds = manualDurationSeconds
        s.createdAt = createdAt; s.updatedAt = updatedAt
        s.exercises = try exercises.sorted { $0.order < $1.order }.map { try $0.value() }
        s.quickEntries = try quickEntries.map { try $0.value() }.sorted { $0.muscle.rawValue < $1.muscle.rawValue }
        return s
    }
}
@Model final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var exerciseDefinitionID: UUID
    var exerciseNameSnapshot: String
    var exerciseSnapshot: Data
    var order: Int
    var notes: String
    var workoutSession: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.sessionExercise) var sets: [WorkoutSet] = []
    init(_ value: ExerciseEntry, order: Int) throws {
        id = value.id; exerciseDefinitionID = value.exercise.id; exerciseNameSnapshot = value.exercise.name
        exerciseSnapshot = try ModelCodec.encode(value.exercise); self.order = order; notes = value.notes
    }
    func apply(_ value: ExerciseEntry, order: Int, context: ModelContext) throws {
        exerciseSnapshot = try ModelCodec.encode(value.exercise); exerciseNameSnapshot = value.exercise.name
        exerciseDefinitionID = value.exercise.id; self.order = order; notes = value.notes
        let old = Dictionary(uniqueKeysWithValues: sets.map { ($0.id, $0) }), keep = Set(value.sets.map(\.id))
        for item in sets where !keep.contains(item.id) { context.delete(item) }
        sets = value.sets.enumerated().map { order, value in
            let item = old[value.id] ?? WorkoutSet(value, order: order)
            item.apply(value, order: order); item.sessionExercise = self; return item
        }
    }
    func value() throws -> ExerciseEntry {
        var entry = ExerciseEntry(exercise: try ModelCodec.decode(Exercise.self, exerciseSnapshot), sets: try sets.sorted { $0.order < $1.order }.map { try $0.value() })
        entry.id = id; entry.notes = notes; return entry
    }
}
@Model final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var order: Int
    var weightKg: Double?
    var reps: Int?
    var durationSeconds: Int?
    var setTypeRaw: String
    var rpe: Double?
    var rir: Double?
    var isCompleted: Bool
    var restSeconds: Int
    var notes: String
    var sessionExercise: SessionExercise?
    init(_ value: TrainingSet, order: Int) {
        id = value.id; self.order = order; weightKg = value.weightKg; reps = value.reps; durationSeconds = value.durationSeconds
        setTypeRaw = value.kind.rawValue; rpe = value.rpe; rir = value.rir; isCompleted = value.isCompleted; restSeconds = value.restSeconds; notes = value.notes
    }
    func apply(_ value: TrainingSet, order: Int) {
        self.order = order; weightKg = value.weightKg; reps = value.reps; durationSeconds = value.durationSeconds
        setTypeRaw = value.kind.rawValue; rpe = value.rpe; rir = value.rir; isCompleted = value.isCompleted; restSeconds = value.restSeconds; notes = value.notes
    }
    func value() throws -> TrainingSet {
        guard let kind = SetKind(rawValue: setTypeRaw) else { throw ValidationError("数据库中的训练组类型无效。") }
        var s = TrainingSet(weightKg: weightKg, reps: reps, durationSeconds: durationSeconds, kind: kind, rpe: rpe, rir: rir, isCompleted: isCompleted)
        s.id = id; s.restSeconds = restSeconds; s.notes = notes; return s
    }
}
@Model final class QuickMuscleEntry {
    @Attribute(.unique) var id: UUID
    var muscleRaw: String
    var intensityRaw: String?
    var workoutSession: WorkoutSession?
    init(_ value: QuickEntry) { id = value.id; muscleRaw = value.muscle.rawValue; intensityRaw = value.intensity?.rawValue }
    func value() throws -> QuickEntry {
        guard let muscle = MuscleGroup(rawValue: muscleRaw) else { throw ValidationError("数据库中的肌群标识无效。") }
        var q = QuickEntry(muscle: muscle, intensity: intensityRaw.flatMap(Intensity.init(rawValue:))); q.id = id; return q
    }
}
@Model final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var payload: Data
    init(_ value: Exercise) throws { id = value.id; name = value.name; payload = try ModelCodec.encode(value) }
    func value() throws -> Exercise { try ModelCodec.decode(Exercise.self, payload) }
}
@Model final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var configuration: Data
    init(_ value: TrainingTemplate) throws { id = value.id; name = value.name; configuration = try ModelCodec.encode(value) }
    func value() throws -> TrainingTemplate { try ModelCodec.decode(TrainingTemplate.self, configuration) }
}
@Model final class BodyWeightRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double
    init(_ value: BodyWeight) { id = value.id; date = value.date; weightKg = value.weightKg }
    func value() -> BodyWeight { var value = BodyWeight(date: date, weightKg: weightKg); value.id = id; return value }
}
@Model final class UserSettings {
    @Attribute(.unique) var key: String
    var payload: Data
    init(_ value: Settings) throws { key = "default"; payload = try ModelCodec.encode(value) }
    func value() throws -> Settings { try ModelCodec.decode(Settings.self, payload) }
}
enum TrainLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [WorkoutSession.self, SessionExercise.self, WorkoutSet.self, QuickMuscleEntry.self, ExerciseDefinition.self, WorkoutTemplate.self, BodyWeightRecord.self, UserSettings.self] }
}
// V1's stored properties remain unchanged. New optional activity payloads are
// separate rows so old strength records migrate without rewriting their graph.
@Model final class SessionActivityData {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(id: UUID, activity: ActivityRecord) throws { self.id = id; payload = try ModelCodec.encode(activity) }
}
enum TrainLogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { TrainLogSchemaV1.models + [SessionActivityData.self, WatchImportReceipt.self] }
}
@Model final class WatchImportReceipt {
    @Attribute(.unique) var id: UUID
    init(id: UUID) { self.id = id }
}
enum TrainLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TrainLogSchemaV1.self, TrainLogSchemaV2.self, TrainLogSchemaV3.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: TrainLogSchemaV1.self, toVersion: TrainLogSchemaV2.self), .lightweight(fromVersion: TrainLogSchemaV2.self, toVersion: TrainLogSchemaV3.self)] }
}

@Model final class SessionWatchData {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(session: Session) throws { id = session.id; payload = try ModelCodec.encode(SessionWatchMetadata(session: session)) }
}
enum TrainLogSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] { TrainLogSchemaV2.models + [SessionWatchData.self] }
}

