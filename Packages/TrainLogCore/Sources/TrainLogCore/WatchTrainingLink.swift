import Foundation

public struct WatchLinkReference: Codable, Hashable, Sendable {
    public var requestID: UUID
    public var phoneSessionID: UUID
    public init(requestID: UUID = UUID(), phoneSessionID: UUID) {
        self.requestID = requestID; self.phoneSessionID = phoneSessionID
    }
}
public struct WatchTrainingRequest: Codable, Hashable, Sendable {
    public var reference: WatchLinkReference
    public var requestedAt: Date
    public var title: String
    public init(phoneSessionID: UUID, title: String, now: Date = Date()) {
        reference = WatchLinkReference(phoneSessionID: phoneSessionID)
        requestedAt = now; self.title = String(title.prefix(80))
    }
    public func validate() throws {
        guard requestedAt.timeIntervalSince1970.isFinite, requestedAt <= Date().addingTimeInterval(300),
              !title.isEmpty, title.count <= 80 else { throw ValidationError("手机训练连接资料无效。") }
    }
}
public enum WatchLinkState: String, Codable, Hashable, Sendable {
    case requested, prepared, recording, finished, cancelled
}
public struct WatchTrainingSummary: Codable, Hashable, Sendable {
    public var watchSessionID: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var duration: TimeInterval
    public var activity: ActivityRecord
    public init(workout: Session) throws {
        guard let activity = workout.activity, let end = workout.endTime else { throw ValidationError("手表结果不完整。") }
        watchSessionID = workout.id; startedAt = workout.startTime; endedAt = end
        duration = workout.elapsed(at: end); self.activity = activity
        try validate()
    }
    public var session: Session {
        var value = Session(mode: .cardio, date: startedAt)
        value.id = watchSessionID; value.startTime = startedAt; value.endTime = endedAt
        value.createdAt = startedAt; value.updatedAt = endedAt; value.status = .completed
        value.timerStartedAt = nil; value.accumulatedSeconds = duration; value.activity = activity
        return value
    }
    public func validate() throws {
        guard duration.isFinite, duration > 0, startedAt <= endedAt,
              duration <= endedAt.timeIntervalSince(startedAt) + 5,
              activity.kind == .traditionalStrength, activity.hasWatchMeasurements,
              activity.watchWorkoutID != nil else { throw ValidationError("关联手表训练的时间或来源无效。") }
        try RecordValidator.session(session)
    }
}
public struct WatchLinkUpdate: Codable, Hashable, Sendable {
    public var reference: WatchLinkReference
    public var state: WatchLinkState
    public var updatedAt: Date
    public init(reference: WatchLinkReference, state: WatchLinkState, now: Date = Date()) {
        self.reference = reference; self.state = state; updatedAt = now
    }
    /// An active journal means sampling may have started even if its status write failed.
    public static func discardingRecovery(reference: WatchLinkReference, previous: Self?, now: Date = Date()) -> Self {
        if let previous, previous.reference == reference, previous.state == .finished { return previous }
        return Self(reference: reference, state: .recording, now: now)
    }
}
public struct WatchTrainingLink: Codable, Hashable, Sendable {
    public var request: WatchTrainingRequest
    public var state: WatchLinkState = .requested
    public var summary: WatchTrainingSummary?
    public init(request: WatchTrainingRequest) { self.request = request }
    public var reference: WatchLinkReference { request.reference }
    public var ownsHealthRecord: Bool { state != .cancelled }
    public func validate(phoneSessionID: UUID) throws {
        try request.validate()
        guard reference.phoneSessionID == phoneSessionID else { throw ValidationError("手表连接与手机训练不匹配。") }
        if state == .finished {
            guard let summary else { throw ValidationError("关联手表结果尚未保存。") }
            try summary.validate()
            guard summary.watchSessionID != phoneSessionID else { throw ValidationError("手表与手机训练标识不能相同。") }
        } else if summary != nil { throw ValidationError("关联手表训练状态无效。") }
    }
    public func applying(_ update: WatchLinkUpdate) throws -> Self {
        guard update.reference == reference, update.updatedAt.timeIntervalSince1970.isFinite,
              update.updatedAt <= Date().addingTimeInterval(300) else { throw ValidationError("手表连接确认与本次请求不匹配。") }
        var result = self
        guard state != .finished && state != .cancelled else { return result }
        switch update.state {
        case .requested: break
        case .prepared: if state == .requested { result.state = .prepared }
        case .recording, .finished: result.state = .recording // Finished metrics commit only with the durable file.
        case .cancelled: if state == .requested || state == .prepared { result.state = .cancelled }
        }
        return result
    }
    public static func merging(_ watch: Session, into phone: Session) throws -> Session {
        try WatchWorkoutEnvelope(session: watch).validate()
        guard phone.mode == .detailed, let reference = watch.phoneLink,
              var link = phone.watchLink, link.reference == reference,
              phone.id == reference.phoneSessionID, link.state != .cancelled else { throw ValidationError("找不到匹配的手机训练，手表原始记录已保留。") }
        let summary = try WatchTrainingSummary(workout: watch)
        if let old = link.summary {
            guard old.activity.watchWorkoutID == summary.activity.watchWorkoutID else { throw ValidationError("该手机训练已经关联另一条手表结果。") }
            return phone
        }
        link.state = .finished; link.summary = summary
        var result = phone; result.watchLink = link; result.updatedAt = max(phone.updatedAt, watch.updatedAt)
        try RecordValidator.session(result)
        return result
    }
}
public struct WatchLinkCommand: Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case prepare, cancel, status }
    public var kind: Kind
    public var request: WatchTrainingRequest
    public init(kind: Kind, request: WatchTrainingRequest) { self.kind = kind; self.request = request }
}
public struct SessionWatchMetadata: Codable, Sendable {
    public var link: WatchTrainingLink?
    public var phoneLink: WatchLinkReference?
    public init(session: Session) { link = session.watchLink; phoneLink = session.phoneLink }
}
