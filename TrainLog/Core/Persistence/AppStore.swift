import Foundation
import Observation
import SwiftData
import TrainLogCore

@MainActor @Observable final class AppStore {
    private(set) var sessions: [Session] = []
    private(set) var completed: [Session] = []
    private(set) var draft: Session?
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
    var backup: Backup { Backup(sessions: sessions, exercises: exercises, templates: templates, bodyWeights: bodyWeights, settings: settings) }

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        publishesSurfaces = !inMemory && storeURL == nil
        health = !inMemory && storeURL == nil ? .production() : .isolated()
        let schema = Schema(versionedSchema: TrainLogSchemaV3.self)
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
        let watchRows = try context.fetch(FetchDescriptor<SessionWatchData>())
        let watchMetadata = try Dictionary(uniqueKeysWithValues: watchRows.map { ($0.id, try ModelCodec.decode(SessionWatchMetadata.self, $0.payload)) })
        let newSessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map { model in
            var value = try model.value(); value.activity = activities[value.id]
            value.watchLink = watchMetadata[value.id]?.link; value.phoneLink = watchMetadata[value.id]?.phoneLink
            if value.mode == .cardio && value.activity == nil { throw ValidationError("运动记录的扩展数据暂不可读，原始数据库已保留。") }
            return value
        }.sorted(by: Self.newestFirst)
        let newExercises = try context.fetch(FetchDescriptor<ExerciseDefinition>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>()).map { try $0.value() }.sorted { $0.name < $1.name }
        let newWeights = try context.fetch(FetchDescriptor<BodyWeightRecord>()).map { $0.value() }.sorted { $0.date > $1.date }
        let newSettings = try context.fetch(FetchDescriptor<UserSettings>()).first?.value() ?? Settings()
        sessions = newSessions; exercises = newExercises; templates = newTemplates; bodyWeights = newWeights; settings = newSettings
        completed = newSessions.filter { $0.status == .completed }
        draft = newSessions.first { $0.status == .draft }
        refreshSurfaces()
    }
    private func transact(refresh: Bool = true, _ operation: () throws -> Void) throws {
        do { try operation(); try context.save() }
        catch { context.rollback(); throw error }
        if refresh { try reload() }
    }
    func perform(_ operation: () throws -> Void) { do { try operation() } catch { errorMessage = error.localizedDescription } }
    func save(_ incoming: Session) throws {
        var session = incoming
        let previous = sessions.first { $0.id == session.id }
        // A delayed editor save cannot erase a newly received sensor attachment.
        if let authoritativeLink = previous?.watchLink { session.watchLink = authoritativeLink }
        try RecordValidator.session(session)
        if session.status == .draft, let other = draft, other.id != session.id { throw ValidationError("请先完成或放弃当前草稿。") }
        if previous == session { return }
        try transact(refresh: false) { try upsert(session) }
        publishSavedSession(session, previous: previous)
    }
    private func publishSavedSession(_ session: Session, previous: Session?) {
        Self.replace(session, in: &sessions)
        if session.status == .completed { Self.replace(session, in: &completed) }
        else if previous?.status == .completed { completed.removeAll { $0.id == session.id } }
        if session.status == .draft { draft = session }
        else if draft?.id == session.id { draft = nil }
        refreshSurfaces(publishWidget: previous?.status != .draft || session.status != .draft)
        health.track(session)
    }
    private static func newestFirst(_ lhs: Session, _ rhs: Session) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
    private static func replace(_ value: Session, in records: inout [Session]) {
        if let index = records.firstIndex(where: { $0.id == value.id }) {
            let previous = records[index]
            if previous.date == value.date && previous.createdAt == value.createdAt {
                records[index] = value; return
            }
            records.remove(at: index)
        }
        // Preserve ordering without sorting the whole archive after every keystroke.
        var low = 0, high = records.count
        while low < high {
            let middle = (low + high) / 2
            if newestFirst(records[middle], value) { low = middle + 1 } else { high = middle }
        }
        records.insert(value, at: low)
    }
    private func upsert(_ session: Session) throws {
        let sessionID = session.id
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        descriptor.fetchLimit = 1
        let models = try context.fetch(descriptor)
        let model: WorkoutSession
        if let existing = models.first(where: { $0.id == session.id }) { model = existing }
        else { model = WorkoutSession(session); context.insert(model) }
        try model.apply(session, context: context, previous: sessions.first { $0.id == session.id })
        try upsertActivity(session)
        try upsertWatchMetadata(session)
    }
    private func upsertWatchMetadata(_ session: Session) throws {
        let id = session.id
        let rows = try context.fetch(FetchDescriptor<SessionWatchData>(predicate: #Predicate { $0.id == id }))
        if session.watchLink != nil || session.phoneLink != nil {
            if let previous = sessions.first(where: { $0.id == id }), !rows.isEmpty,
               previous.watchLink == session.watchLink, previous.phoneLink == session.phoneLink { return }
            if let old = rows.first { old.payload = try ModelCodec.encode(SessionWatchMetadata(session: session)) }
            else { context.insert(try SessionWatchData(session: session)) }
        } else { for row in rows { context.delete(row) } }
    }
    private func commitWatchMetadata(_ session: Session) throws {
        try RecordValidator.session(session)
        let previous = sessions.first { $0.id == session.id }
        guard previous != session else { return }
        try transact(refresh: false) { try upsert(session) }
        publishSavedSession(session, previous: previous)
    }
    func prepareWatchLink(sessionID: UUID) throws -> WatchTrainingRequest {
        guard var value = draft, value.id == sessionID, value.mode == .detailed else { throw ValidationError("请先打开当前手机力量训练。") }
        if let link = value.watchLink, link.state != .cancelled { return link.request }
        let name = value.exercises.prefix(2).map(\.exercise.name).joined(separator: " · ")
        let request = WatchTrainingRequest(phoneSessionID: value.id, title: name.isEmpty ? "手机力量训练" : name)
        value.watchLink = WatchTrainingLink(request: request); value.updatedAt = Date()
        try commitWatchMetadata(value)
        return request
    }
    func applyWatchLinkUpdate(_ update: WatchLinkUpdate) throws {
        guard var value = sessions.first(where: { $0.id == update.reference.phoneSessionID }), let link = value.watchLink, link.reference == update.reference else { return }
        let next = try link.applying(update)
        guard next != link else { return }
        value.watchLink = next; value.updatedAt = Date()
        try commitWatchMetadata(value)
    }
    func connectWatch(sessionID: UUID) async throws {
        watch.refresh()
        guard watch.installed, watch.reachable else { throw ValidationError("请先在已配对的 Apple Watch 打开 TrainLog，再连接这次训练。") }
        let request = try prepareWatchLink(sessionID: sessionID)
        let response = try await watch.send(WatchLinkCommand(kind: .prepare, request: request))
        try applyWatchLinkUpdate(response)
    }
    private func upsertActivity(_ session: Session) throws {
        let id = session.id
        let rows = try context.fetch(FetchDescriptor<SessionActivityData>(predicate: #Predicate { $0.id == id }))
        if let activity = session.activity {
            if !rows.isEmpty, sessions.first(where: { $0.id == id })?.activity == activity { return }
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
        if let reference = session.phoneLink {
            let phoneID = reference.phoneSessionID
            guard let phone = sessions.first(where: { $0.id == phoneID }) else {
                if try context.fetchCount(FetchDescriptor<WatchImportReceipt>(predicate: #Predicate { $0.id == phoneID })) > 0 {
                    try transact(refresh: false) { context.insert(WatchImportReceipt(id: id)) }; return
                }
                throw ValidationError("关联的手机训练尚未找到，接收文件已保留，请恢复原训练档案后重试。")
            }
            let merged = try WatchTrainingLink.merging(session, into: phone)
            try transact(refresh: false) { try upsert(merged); context.insert(WatchImportReceipt(id: id)) }
            publishSavedSession(merged, previous: phone)
            return
        }
        try RecordValidator.session(session)
        try transact {
            if !sessions.contains(where: { $0.id == id }) { try upsert(session) }
            context.insert(WatchImportReceipt(id: id))
        }
    }
    func activateWatch() {
        guard publishesSurfaces else { return }
        watch.activate(receive: { [weak self] session in
            guard let self else { throw ValidationError("训练档案尚未就绪。") }
            try self.receiveWatchSession(session)
        }, receiveUpdate: { [weak self] update in
            guard let self else { throw ValidationError("训练档案尚未就绪。") }
            try self.applyWatchLinkUpdate(update)
        })
    }
    func deleteSession(_ id: UUID) throws {
        try transact(refresh: false) {
            let sessionID = id
            if sessions.first(where: { $0.id == id })?.watchLink != nil,
               try context.fetchCount(FetchDescriptor<WatchImportReceipt>(predicate: #Predicate { $0.id == sessionID })) == 0 { context.insert(WatchImportReceipt(id: id)) }
            let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
            for model in try context.fetch(descriptor) { context.delete(model) }
            for row in try context.fetch(FetchDescriptor<SessionActivityData>(predicate: #Predicate { $0.id == sessionID })) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<SessionWatchData>(predicate: #Predicate { $0.id == sessionID })) { context.delete(row) }
        }
        sessions.removeAll { $0.id == id }
        if completed.contains(where: { $0.id == id }) { completed.removeAll { $0.id == id } }
        if draft?.id == id { draft = nil }
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
    func refreshSurfaces(publishWidget: Bool = true) {
        guard publishesSurfaces else { return }
        if publishWidget { surfaces.publish(sessions: settings.hasOnboarded ? sessions : [], goal: settings.weeklyGoal, templates: settings.hasOnboarded ? templates : []) }
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
            for row in try context.fetch(FetchDescriptor<SessionWatchData>()) where !sessionIDs.contains(row.id) { context.delete(row) }
            for value in next.sessions {
                let model = existingSessions[value.id] ?? WorkoutSession(value)
                if existingSessions[value.id] == nil { context.insert(model) }
                try model.apply(value, context: context)
                try upsertActivity(value)
                try upsertWatchMetadata(value)
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

