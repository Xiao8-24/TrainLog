import Foundation

public struct Backup: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var exportedAt: Date = Date()
    public var sessions: [Session]
    public var exercises: [Exercise]
    public var templates: [TrainingTemplate]
    public var bodyWeights: [BodyWeight]
    public var settings: Settings
    public init(sessions: [Session], exercises: [Exercise], templates: [TrainingTemplate], bodyWeights: [BodyWeight], settings: Settings) {
        self.sessions = sessions; self.exercises = exercises; self.templates = templates; self.bodyWeights = bodyWeights; self.settings = settings
    }
}
public enum ImportMode { case merge, replace }
public enum BackupService {
    public static let maximumBytes = 32 * 1024 * 1024
    public static func encode(_ backup: Backup) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }
    public static func decode(_ data: Data) throws -> Backup {
        guard data.count <= maximumBytes else { throw ValidationError("备份超过 32 MB，请使用较小的备份文件。") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup: Backup
        do { backup = try decoder.decode(Backup.self, from: data) }
        catch { throw ValidationError("备份结构或字段格式无效：\(error.localizedDescription)") }
        try validate(backup)
        return backup
    }
    public static func validate(_ backup: Backup) throws {
        guard backup.schemaVersion == 1 else { throw ValidationError("不支持备份版本 \(backup.schemaVersion)，请使用兼容版本。") }
        guard backup.sessions.count <= 50_000, backup.exercises.count <= 5_000, backup.templates.count <= 1_000 else { throw ValidationError("备份记录数量超出安全导入范围。") }
        var ids = Set<UUID>()
        func register(_ id: UUID) throws {
            guard ids.insert(id).inserted else { throw ValidationError("备份中存在重复 ID：\(id.uuidString)") }
        }
        let exerciseIDs = Set(backup.exercises.map(\.id))
        for exercise in backup.exercises { try register(exercise.id); try RecordValidator.exercise(exercise) }
        guard backup.sessions.filter({ $0.status == .draft }).count <= 1 else { throw ValidationError("备份包含多个活动草稿。") }
        for session in backup.sessions {
            try register(session.id); try RecordValidator.session(session)
            for entry in session.exercises {
                try register(entry.id)
                guard exerciseIDs.contains(entry.exercise.id) else { throw ValidationError("训练记录引用了不存在的动作。") }
                for set in entry.sets { try register(set.id) }
            }
            for quick in session.quickEntries { try register(quick.id) }
        }
        for template in backup.templates {
            try register(template.id)
            guard !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.name.count <= 100, !template.items.isEmpty else { throw ValidationError("模板名称或动作列表为空。") }
            for item in template.items {
                try register(item.id)
                guard let exercise = backup.exercises.first(where: { $0.id == item.exerciseID }), (1...30).contains(item.setCount) else { throw ValidationError("模板动作引用或默认组数无效。") }
                try RecordValidator.trainingSet(TrainingSet(weightKg: item.weightKg, reps: item.reps), exercise: exercise)
            }
        }
        for weight in backup.bodyWeights { try register(weight.id); try RecordValidator.bodyWeight(weight) }
        try RecordValidator.settings(backup.settings)
        for (pattern, id) in backup.settings.representatives {
            guard backup.exercises.contains(where: { $0.id == id && $0.pattern?.rawValue == pattern }) else { throw ValidationError("代表动作与动作模式不匹配。") }
        }
    }
    public static func importing(_ imported: Backup, into current: Backup, mode: ImportMode) throws -> Backup {
        try validate(imported)
        guard mode == .merge else { return imported }
        func merged<T: Identifiable>(_ local: [T], _ incoming: [T]) -> [T] where T.ID == UUID {
            let existing = Set(local.map(\.id)); return local + incoming.filter { !existing.contains($0.id) }
        }
        var result = current
        // Existing IDs always win. Conflicting drafts require a user decision rather than silent data loss.
        result.sessions = merged(current.sessions, imported.sessions)
        result.exercises = merged(current.exercises, imported.exercises)
        result.templates = merged(current.templates, imported.templates)
        result.bodyWeights = merged(current.bodyWeights, imported.bodyWeights)
        try validate(result)
        return result
    }
    public static func csv(_ sessions: [Session]) -> String {
        let header = ["session_id", "date", "status", "mode", "exercise", "exercise_id", "set_id", "set_number", "set_type", "completed", "weight_kg", "loading_convention", "reps", "duration_seconds", "rpe", "rir", "volume_kg", "muscles", "subjective_intensity", "session_rpe", "session_duration_seconds", "session_notes", "exercise_notes", "set_notes", "rest_seconds"]
        let formatter = ISO8601DateFormatter()
        func cell(_ value: String) -> String {
            // Prevent formula evaluation when a CSV is opened in a spreadsheet.
            let trimmed = value.drop(while: { $0.isWhitespace })
            let safe = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        func number(_ value: Double?) -> String { value.map(String.init(describing:)) ?? "" }
        var rows = [header]
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            let common = [session.id.uuidString, formatter.string(from: session.date), session.status.rawValue, session.mode.rawValue]
            let tail = [session.intensity?.rawValue ?? "", number(session.sessionRPE), String(Int(session.elapsed())), session.notes]
            if session.mode == .quick {
                for entry in session.quickEntries {
                    var row = common + Array(repeating: "", count: 13)
                    row += [entry.muscle.rawValue, entry.intensity?.rawValue ?? session.intensity?.rawValue ?? "", number(session.sessionRPE), String(Int(session.elapsed())), session.notes]
                    rows.append(row + ["", "", ""])
                }
            } else {
                for entry in session.exercises {
                    for (index, set) in entry.sets.enumerated() {
                        let fields = [entry.exercise.name, entry.exercise.id.uuidString, set.id.uuidString, String(index + 1), set.kind.rawValue, String(set.isCompleted), number(set.weightKg), entry.exercise.loading.rawValue, set.reps.map(String.init) ?? "", set.durationSeconds.map(String.init) ?? "", number(set.rpe), number(set.rir), number(WorkoutStatisticsService.volume(set, exercise: entry.exercise)), (entry.exercise.primary + entry.exercise.secondary).map(\.rawValue).joined(separator: ";")]
                        rows.append(common + fields + tail + [entry.notes, set.notes, String(set.restSeconds)])
                    }
                }
            }
        }
        let activityColumns = ["activity_type", "distance_meters", "active_energy_kcal", "average_heart_rate_bpm", "maximum_heart_rate_bpm", "measurement_source", "watch_workout_id"]
        rows = rows.enumerated().map { index, row in row + (index == 0 ? activityColumns : Array(repeating: "", count: activityColumns.count)) }
        for session in sessions.sorted(by: { $0.date < $1.date }) where session.mode == .cardio {
            guard let activity = session.activity else { continue }
            var row = Array(repeating: "", count: header.count)
            row[0] = session.id.uuidString; row[1] = formatter.string(from: session.date)
            row[2] = session.status.rawValue; row[3] = session.mode.rawValue
            row[18] = session.intensity?.rawValue ?? ""; row[19] = number(session.sessionRPE)
            row[20] = String(Int(session.elapsed())); row[21] = session.notes
            row += [activity.kind.rawValue, number(activity.distanceMeters), number(activity.activeEnergyKcal), number(activity.averageHeartRate), number(activity.maximumHeartRate), activity.source, activity.watchWorkoutID?.uuidString ?? ""]
            rows.append(row)
        }
        return "\u{FEFF}" + rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}

