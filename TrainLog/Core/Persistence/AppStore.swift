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
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    var completed: [Session] { sessions.filter { $0.status == .completed } }
    var draft: Session? { sessions.first { $0.status == .draft } }
    var backup: Backup { Backup(sessions: sessions, exercises: exercises, templates: templates, bodyWeights: bodyWeights, settings: settings) }

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        let schema = Schema(versionedSchema: TrainLogSchemaV1.self)
        let config: ModelConfiguration
        if let storeURL { config = ModelConfiguration("TrainLog", schema: schema, url: storeURL, cloudKitDatabase: .none) }
        else { config = ModelConfiguration("TrainLog", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none) }
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
    }
    private func reload() throws {
        // Decode into temporary values so a corrupt row cannot leave a half-refreshed screen.
        let newSessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map { try $0.value() }.sorted { $0.date > $1.date }
        let newExercises = try context.fetch(FetchDescriptor<ExerciseDefinition>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newWeights = try context.fetch(FetchDescriptor<BodyWeightRecord>()).map { $0.value() }.sorted { $0.date > $1.date }
        let newSettings = try context.fetch(FetchDescriptor<UserSettings>()).first?.value() ?? Settings()
        sessions = newSessions; exercises = newExercises; templates = newTemplates; bodyWeights = newWeights; settings = newSettings
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
    }
    func deleteSession(_ id: UUID) throws {
        try transact(refresh: false) {
            let sessionID = id
            let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
            for model in try context.fetch(descriptor) { context.delete(model) }
        }
        sessions.removeAll { $0.id == id }
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
    }
    func saveWeight(_ value: BodyWeight) throws {
        try RecordValidator.bodyWeight(value)
        try transact {
            if let model = try context.fetch(FetchDescriptor<BodyWeightRecord>()).first(where: { $0.id == value.id }) { model.date = value.date; model.weightKg = value.weightKg }
            else { context.insert(BodyWeightRecord(value)) }
        }
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
            for value in next.sessions {
                let model = existingSessions[value.id] ?? WorkoutSession(value)
                if existingSessions[value.id] == nil { context.insert(model) }
                try model.apply(value, context: context)
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
        return recovery
    }
}

