import Foundation
import Observation
import SwiftData
import TrainLogCore

@MainActor @Observable final class AppStore {
    private(set) var sessions: [Session] = []
    private(set) var exercises: [Exercise] = []
    private(set) var templates: [TrainingTemplate] = []
    private(set) var bodyWeights: [BodyWeight] = []
    private(set) var settings = Settings()
    var errorMessage: String?
    private let surfaces = WorkoutSurfacesCoordinator()
    private let publishesSurfaces: Bool
    let health: HealthSyncCoordinator
    let watch = WatchBridge()
    let healthInsights = HealthInsights()
    var surfaceIssue: String? { surfaces.issue }
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    var completed: [Session] { sessions.filter { $0.status == .completed } }
    var draft: Session? { sessions.first { $0.status == .draft } }
    var backup: Backup { Backup(sessions: sessions, exercises: exercises, templates: templates, bodyWeights: bodyWeights, settings: settings) }

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        publishesSurfaces = !inMemory && storeURL == nil
        health = !inMemory && storeURL == nil ? .production() : .isolated()
        let schema = Schema(versionedSchema: TrainLogSchemaV2.self)
        let config = Self.configuration(schema: schema, inMemory: inMemory, storeURL: storeURL)
        container = try ModelContainer(for: schema, migrationPlan: TrainLogMigrationPlan.self, configurations: [config])
        context.autosaveEnabled = false
        try reload()
        if try context.fetchCount(FetchDescriptor<UserSettings>()) == 0 {
            try transact {
                context.insert(try UserSettings(Settings()))
                for exercise in ExerciseCatalog.exercises { context.insert(try ExerciseDefinition(exercise)) }
                for template in ExerciseCatalog.templates { context.insert(try WorkoutTemplate(template)) }
            }
        }
        try installMissingExercises()
    }
    static func configuration(schema: Schema, inMemory: Bool = false, storeURL: URL? = nil) -> ModelConfiguration {
        if let storeURL { return ModelConfiguration("TrainLog", schema: schema, url: storeURL, cloudKitDatabase: .none) }
        // Keep the pre-widget database in the app sandbox. Only the minimal
        // widget snapshot belongs in the App Group, never the full database.
        return ModelConfiguration("TrainLog", schema: schema, isStoredInMemoryOnly: inMemory, groupContainer: .none, cloudKitDatabase: .none)
    }
    private func reload() throws {
        // Decode into temporary values so a corrupt row cannot leave a half-refreshed screen.
        let activityRows = try context.fetch(FetchDescriptor<SessionActivityData>())
        let activities = try Dictionary(uniqueKeysWithValues: activityRows.map { ($0.id, try ModelCodec.decode(ActivityRecord.self, $0.payload)) })
        let newSessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map { model in
            var value = try model.value(); value.activity = activities[value.id]
            if value.mode == .cardio && value.activity == nil { throw ValidationError("运动记录的扩展数据暂不可读，原始数据库已保留。") }
            return value
        }.sorted { $0.date > $1.date }
        let newExercises = try context.fetch(FetchDescriptor<ExerciseDefinition>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newWeights = try context.fetch(FetchDescriptor<BodyWeightRecord>()).map { $0.value() }.sorted { $0.date > $1.date }
        let newSettings = try context.fetch(FetchDescriptor<UserSettings>()).first?.value() ?? Settings()
        sessions = newSessions; exercises = newExercises; templates = newTemplates; bodyWeights = newWeights; settings = newSettings
        refreshSurfaces()
    }
    private func transact(refresh: Bool = true, _ operation: () throws -> Void) throws {
        do { try operation(); try context.save() }
        catch { context.rollback(); throw error }
        if refresh { try reload() }
    }
    func perform(_ operation: () throws -> Void) { do { try operation() } catch { errorMessage = error.localizedDescription } }
    func save(_ session: Session) throws {
        try RecordValidator.session(session)
        if session.status == .draft, let other = draft, other.id != session.id { throw ValidationError("请先完成或放弃当前草稿。") }
        try transact(refresh: false) { try upsert(session) }
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sessions.sort { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date }
        refreshSurfaces()
        health.track(session)
    }
    private func upsert(_ session: Session) throws {
        let sessionID = session.id
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        descriptor.fetchLimit = 1
        let models = try context.fetch(descriptor)
        let model: WorkoutSession
        if let existing = models.first(where: { $0.id == session.id }) { model = existing }
        else { model = WorkoutSession(session); context.insert(model) }
        try model.apply(session, context: context)
        try upsertActivity(session)
    }
    private func upsertActivity(_ session: Session) throws {
        let id = session.id
        let rows = try context.fetch(FetchDescriptor<SessionActivityData>(predicate: #Predicate { $0.id == id }))
        if let activity = session.activity {
            if let old = rows.first { old.payload = try ModelCodec.encode(activity) }
            else { context.insert(try SessionActivityData(id: id, activity: activity)) }
        } else { for row in rows { context.delete(row) } }
    }
    func installMissingExercises() throws {
        let ids = Set(exercises.map(\.id))
        let missing = ExerciseCatalog.exercises.filter { !ids.contains($0.id) }
        guard !missing.isEmpty else { return }
        try transact { for exercise in missing { context.insert(try ExerciseDefinition(exercise)) } }
    }
    /// Delivered messages are acknowledged only after this transaction commits.
    /// Replays keep existing edits rather than overwriting a user's history.
    func receiveWatchSession(_ session: Session) throws {
        try WatchWorkoutEnvelope(session: session).validate()
        let id = session.id
        if try context.fetchCount(FetchDescriptor<WatchImportReceipt>(predicate: #Predicate { $0.id == id })) > 0 { return }
        try RecordValidator.session(session)
        try transact {
            if !sessions.contains(where: { $0.id == id }) { try upsert(session) }
            context.insert(WatchImportReceipt(id: id))
        }
    }
    func activateWatch() {
        guard publishesSurfaces else { return }
        watch.activate { [weak self] session in
            guard let self else { throw ValidationError("训练档案尚未就绪。") }
            try self.receiveWatchSession(session)
        }
    }
    func deleteSession(_ id: UUID) throws {
        try transact(refresh: false) {
            let sessionID = id
            let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
            for model in try context.fetch(descriptor) { context.delete(model) }
            for row in try context.fetch(FetchDescriptor<SessionActivityData>()) where row.id == id { context.delete(row) }
        }
        sessions.removeAll { $0.id == id }
        refreshSurfaces()
        health.remove(id)
    }
    func saveExercise(_ exercise: Exercise) throws {
        try RecordValidator.exercise(exercise)
        var nextSettings = settings
        nextSettings.representatives = nextSettings.representatives.filter { $0.value != exercise.id || $0.key == exercise.pattern?.rawValue }
        try transact {
            if let model = try context.fetch(FetchDescriptor<ExerciseDefinition>()).first(where: { $0.id == exercise.id }) {
                model.name = exercise.name; model.payload = try ModelCodec.encode(exercise)
            } else { context.insert(try ExerciseDefinition(exercise)) }
            if let model = try context.fetch(FetchDescriptor<UserSettings>()).first { model.payload = try ModelCodec.encode(nextSettings) }
        }
    }
    func saveTemplate(_ template: TrainingTemplate) throws {
        var check = backup; check.templates.removeAll { $0.id == template.id }; check.templates.append(template)
        try BackupService.validate(check)
        try transact {
            if let model = try context.fetch(FetchDescriptor<WorkoutTemplate>()).first(where: { $0.id == template.id }) {
                model.name = template.name; model.configuration = try ModelCodec.encode(template)
            } else { context.insert(try WorkoutTemplate(template)) }
        }
    }
    func deleteTemplate(_ id: UUID) throws {
        try transact { for model in try context.fetch(FetchDescriptor<WorkoutTemplate>()) where model.id == id { context.delete(model) } }
    }
    func updateSettings(_ value: Settings) throws {
        try RecordValidator.settings(value)
        try transact(refresh: false) {
            if let model = try context.fetch(FetchDescriptor<UserSettings>()).first { model.payload = try ModelCodec.encode(value) }
            else { context.insert(try UserSettings(value)) }
        }
        settings = value
        refreshSurfaces()
    }
    func saveWeight(_ value: BodyWeight) throws {
        try RecordValidator.bodyWeight(value)
        try transact {
            if let model = try context.fetch(FetchDescriptor<BodyWeightRecord>()).first(where: { $0.id == value.id }) { model.date = value.date; model.weightKg = value.weightKg }
            else { context.insert(BodyWeightRecord(value)) }
        }
    }
    func refreshSurfaces() {
        guard publishesSurfaces else { return }
        surfaces.publish(sessions: settings.hasOnboarded ? sessions : [], goal: settings.weeklyGoal)
        surfaces.sync(session: settings.hasOnboarded ? draft : nil)
    }
    func deleteWeight(_ id: UUID) throws {
        try transact { for model in try context.fetch(FetchDescriptor<BodyWeightRecord>()) where model.id == id { context.delete(model) } }
    }
    func importBackup(_ incoming: Backup, mode: ImportMode) throws -> URL {
        let next = try BackupService.importing(incoming, into: backup, mode: mode)
        // A readable recovery backup is written before any database mutation.
        let directory = URL.documentsDirectory.appending(path: "Recovery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recovery = directory.appending(path: "before-import-\(UUID().uuidString).json")
        try BackupService.encode(backup).write(to: recovery, options: [.atomic, .completeFileProtection])
        try transact {
            let sessionIDs = Set(next.sessions.map(\.id))
            let sessionModels = try context.fetch(FetchDescriptor<WorkoutSession>())
            let existingSessions = Dictionary(uniqueKeysWithValues: sessionModels.map { ($0.id, $0) })
            for model in sessionModels where !sessionIDs.contains(model.id) { context.delete(model) }
            for row in try context.fetch(FetchDescriptor<SessionActivityData>()) where !sessionIDs.contains(row.id) { context.delete(row) }
            for value in next.sessions {
                let model = existingSessions[value.id] ?? WorkoutSession(value)
                if existingSessions[value.id] == nil { context.insert(model) }
                try model.apply(value, context: context)
                try upsertActivity(value)
            }
            let definitions = try context.fetch(FetchDescriptor<ExerciseDefinition>())
            let exerciseIDs = Set(next.exercises.map(\.id))
            for old in definitions where !exerciseIDs.contains(old.id) { context.delete(old) }
            for value in next.exercises {
                if let old = definitions.first(where: { $0.id == value.id }) { old.name = value.name; old.payload = try ModelCodec.encode(value) }
                else { context.insert(try ExerciseDefinition(value)) }
            }
            let templateModels = try context.fetch(FetchDescriptor<WorkoutTemplate>())
            let templateIDs = Set(next.templates.map(\.id))
            for old in templateModels where !templateIDs.contains(old.id) { context.delete(old) }
            for value in next.templates {
                if let old = templateModels.first(where: { $0.id == value.id }) { old.name = value.name; old.configuration = try ModelCodec.encode(value) }
                else { context.insert(try WorkoutTemplate(value)) }
            }
            let weights = try context.fetch(FetchDescriptor<BodyWeightRecord>()), weightIDs = Set(next.bodyWeights.map(\.id))
            for old in weights where !weightIDs.contains(old.id) { context.delete(old) }
            for value in next.bodyWeights {
                if let old = weights.first(where: { $0.id == value.id }) { old.date = value.date; old.weightKg = value.weightKg }
                else { context.insert(BodyWeightRecord(value)) }
            }
            if let model = try context.fetch(FetchDescriptor<UserSettings>()).first { model.payload = try ModelCodec.encode(next.settings) }
            else { context.insert(try UserSettings(next.settings)) }
        }
        health.reconcileManaged(sessions: sessions)
        return recovery
    }
}

