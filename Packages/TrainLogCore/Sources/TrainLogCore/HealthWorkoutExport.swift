import Foundation

/// Only the workout summary crosses the HealthKit boundary. Notes, body weight,
/// exercise names and set details stay in TrainLog.
public struct HealthWorkoutExport: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var start: Date
    public var end: Date
    public var duration: TimeInterval
    public var syncIdentifier: String { "com.trainlog.workout.\(sessionID.uuidString)" }

    public init(session: Session, now: Date = Date()) throws {
        guard session.status == .completed else { throw ValidationError("完成训练后才可写入 Apple 健康。") }
        let duration = session.elapsed(at: session.endTime ?? session.updatedAt)
        guard duration.isFinite, duration > 0, duration <= 604_800 else {
            throw ValidationError("请为训练填写大于零的有效时长后，再写入 Apple 健康。")
        }
        guard session.date.timeIntervalSince1970.isFinite, session.date <= now,
              session.updatedAt.timeIntervalSince1970.isFinite,
              session.startTime.timeIntervalSince1970.isFinite,
              session.endTime?.timeIntervalSince1970.isFinite != false else {
            throw ValidationError("请检查训练日期；不能把未来的训练写入 Apple 健康。")
        }
        // A timed workout retains its wall-clock span while duration excludes
        // pauses. A quick/manual record uses its explicitly entered duration.
        let wallSpan = session.mode == .detailed && session.manualDurationSeconds == nil
            ? max(duration, (session.endTime ?? session.updatedAt).timeIntervalSince(session.startTime))
            : duration
        guard wallSpan.isFinite, wallSpan > 0, wallSpan <= 604_800 else {
            throw ValidationError("训练起止时间不适合写入 Apple 健康，请检查日期和时长。")
        }
        let recordedEnd = min(session.endTime ?? session.updatedAt, now)
        // Backfilled dates are treated as start times. For a just-entered quick
        // record, end at its saved completion time rather than in the future.
        let start = min(session.date, recordedEnd.addingTimeInterval(-wallSpan))
        self.sessionID = session.id
        self.start = start
        self.end = start.addingTimeInterval(wallSpan)
        self.duration = duration
    }
}

public struct HealthSyncRecord: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var workout: HealthWorkoutExport?
    public var version: Int
    public var acknowledgedVersion: Int?
    public var isPending: Bool { acknowledgedVersion != version }
    public var syncIdentifier: String { "com.trainlog.workout.\(sessionID.uuidString)" }
}

/// The desired revision is persisted BEFORE calling HealthKit. Retrying after
/// a process exit uses the same sync identifier/version, including deletions.
public struct HealthSyncLedger: Codable, Equatable, Sendable {
    public private(set) var records: [UUID: HealthSyncRecord] = [:]
    public init() {}
    public var pending: [HealthSyncRecord] {
        records.values.filter(\.isPending).sorted { $0.sessionID.uuidString < $1.sessionID.uuidString }
    }
    public mutating func stage(_ workout: HealthWorkoutExport, now: Date = Date()) {
        if records[workout.sessionID]?.workout == workout { return }
        let prior = records[workout.sessionID]?.version ?? 0
        records[workout.sessionID] = HealthSyncRecord(sessionID: workout.sessionID, workout: workout,
            version: max(prior + 1, Int(now.timeIntervalSince1970 * 1_000)), acknowledgedVersion: nil)
    }
    public mutating func remove(_ id: UUID) {
        guard var record = records[id], record.workout != nil else { return }
        record.workout = nil; record.version += 1; record.acknowledgedVersion = nil
        records[id] = record
    }
    public mutating func acknowledge(_ id: UUID, version: Int) {
        // A late completion must not overwrite a newer edit or deletion.
        guard var record = records[id], record.version == version else { return }
        if record.workout == nil { records.removeValue(forKey: id) }
        else { record.acknowledgedVersion = version; records[id] = record }
    }
}
