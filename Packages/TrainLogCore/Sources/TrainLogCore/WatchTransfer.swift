import Foundation

public struct WatchLiveSnapshot: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var kind: CardioActivity
    public var updatedAt: Date
    public var startedAt: Date
    public var elapsed: TimeInterval
    public var paused: Bool
    public var heartRate: Double?
    public var activeEnergyKcal: Double?
    public var distanceMeters: Double?
    public init(sessionID: UUID, kind: CardioActivity, updatedAt: Date, startedAt: Date, elapsed: TimeInterval, paused: Bool, heartRate: Double?, activeEnergyKcal: Double?, distanceMeters: Double?) {
        self.sessionID = sessionID; self.kind = kind; self.updatedAt = updatedAt; self.startedAt = startedAt
        self.elapsed = elapsed; self.paused = paused; self.heartRate = heartRate
        self.activeEnergyKcal = activeEnergyKcal; self.distanceMeters = distanceMeters
    }
    public func isFresh(at now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(updatedAt) >= -5 && now.timeIntervalSince(updatedAt) <= 20,
              elapsed.isFinite, elapsed >= 0, elapsed <= 604800, startedAt <= updatedAt else { return false }
        if let heartRate, !heartRate.isFinite || !(20...300).contains(heartRate) { return false }
        if let activeEnergyKcal, !activeEnergyKcal.isFinite || !(0...100_000).contains(activeEnergyKcal) { return false }
        if let distanceMeters, !distanceMeters.isFinite || !(0...2_000_000).contains(distanceMeters) { return false }
        return true
    }
}

/// Small, versioned envelope. A file transfer is used for heart-rate histories
/// rather than exceeding WatchConnectivity's message payload limit.
public struct WatchWorkoutEnvelope: Codable, Sendable {
    public var version = 1
    public var session: Session
    public init(session: Session) { self.session = session }
    public func validate() throws {
        guard version == 1, session.mode == .cardio, session.status == .completed,
              session.activity?.hasWatchMeasurements == true, session.activity?.watchWorkoutID != nil else { throw ValidationError("不支持的手表训练数据。") }
        try RecordValidator.session(session)
    }
    public static func decode(_ data: Data) throws -> WatchWorkoutEnvelope {
        guard data.count <= 4 * 1024 * 1024 else { throw ValidationError("手表训练文件过大。") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate(); return value
    }
}
