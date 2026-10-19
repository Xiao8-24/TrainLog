import Foundation

/// Wall-clock anchors survive backgrounding and relaunch; pauses exclude inactive time.
public struct SetTiming: Codable, Hashable, Sendable {
    public var startedAt: Date
    public var endedAt: Date?
    public var accumulatedSeconds: TimeInterval = 0
    public var timerStartedAt: Date?
    public init(at now: Date = Date()) { startedAt = now; timerStartedAt = now }
    public func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulatedSeconds + (timerStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }
    public mutating func pause(at now: Date) {
        guard timerStartedAt != nil else { return }
        accumulatedSeconds = elapsed(at: now); timerStartedAt = nil
    }
    public mutating func resume(at now: Date) { if endedAt == nil && timerStartedAt == nil { timerStartedAt = now } }
    public mutating func finish(at now: Date) { pause(at: now); endedAt = now }
    public func validate() throws {
        let dates = [startedAt] + [endedAt, timerStartedAt].compactMap { $0 }
        guard dates.allSatisfy({ $0.timeIntervalSince1970.isFinite && $0 <= Date().addingTimeInterval(60) }),
              accumulatedSeconds.isFinite, (0...604800).contains(accumulatedSeconds),
              endedAt.map({ $0 >= startedAt && timerStartedAt == nil && accumulatedSeconds <= $0.timeIntervalSince(startedAt) + 1 }) ?? true,
              timerStartedAt.map({ $0 >= startedAt }) ?? true else { throw ValidationError("本组计时资料无效。") }
    }
}
public struct ActiveTrainingSet: Hashable, Sendable {
    public var entryID: UUID
    public var setID: UUID
}
public extension Session {
    var activeSet: ActiveTrainingSet? {
        for entry in exercises { if let set = entry.sets.first(where: { $0.timing != nil && $0.timing?.endedAt == nil }) {
            return ActiveTrainingSet(entryID: entry.id, setID: set.id)
        } }
        return nil
    }
    mutating func resume(at now: Date = Date()) {
        guard status == .draft else { return }
        manualDurationSeconds = nil
        if timerStartedAt == nil { timerStartedAt = now }
        for e in exercises.indices { for s in exercises[e].sets.indices { exercises[e].sets[s].timing?.resume(at: now) } }
    }
    mutating func startSet(entryID: UUID, setID: UUID, at now: Date = Date()) throws {
        guard status == .draft, mode == .detailed else { throw ValidationError("请在正在进行的力量训练中开始一组。") }
        if let activeSet {
            guard activeSet.entryID == entryID && activeSet.setID == setID else { throw ValidationError("请先结束正在计时的那一组。") }
            resume(at: now); return
        }
        guard let e = exercises.firstIndex(where: { $0.id == entryID }), let s = exercises[e].sets.firstIndex(where: { $0.id == setID }),
              !exercises[e].sets[s].isCompleted else { throw ValidationError("这组已完成或已不存在，请新增一组。") }
        resume(at: now); exercises[e].sets[s].timing = SetTiming(at: now); updatedAt = now
    }
    mutating func completeSet(entryID: UUID, setID: UUID, at now: Date = Date()) throws {
        if let activeSet, activeSet != ActiveTrainingSet(entryID: entryID, setID: setID) { throw ValidationError("请先结束正在计时的那一组。") }
        guard let e = exercises.firstIndex(where: { $0.id == entryID }), let s = exercises[e].sets.firstIndex(where: { $0.id == setID }) else { throw ValidationError("这组已不存在。") }
        var value = exercises[e].sets[s]
        if value.timing != nil && value.timing?.endedAt == nil {
            value.timing?.finish(at: now)
            if exercises[e].exercise.tracking == .duration, value.durationSeconds == nil {
                let measured = value.timing!.elapsed(at: now)
                guard measured > 0, measured <= 86400 else { throw ValidationError("请记录大于零且不超过一天的本组持续时间。") }
                value.durationSeconds = Int(ceil(measured))
            }
        }
        try RecordValidator.trainingSet(value, exercise: exercises[e].exercise, requireComplete: true)
        value.isCompleted = true; exercises[e].sets[s] = value; updatedAt = now
    }
}

/// Stored separately from V1–V3 graph entities to preserve existing databases.
public struct SessionTrainingMetadata: Codable, Hashable, Sendable {
    public var plan: TrainingPlanReference?
    public var timings: [UUID: SetTiming]
    public init(session: Session) {
        plan = session.plan
        timings = Dictionary(uniqueKeysWithValues: session.exercises.flatMap(\.sets).compactMap { set in set.timing.map { (set.id, $0) } })
    }
    public func applying(to session: Session) -> Session {
        var value = session; value.plan = plan
        for e in value.exercises.indices { for s in value.exercises[e].sets.indices { value.exercises[e].sets[s].timing = timings[value.exercises[e].sets[s].id] } }
        return value
    }
    public var isEmpty: Bool { plan == nil && timings.isEmpty }
}
