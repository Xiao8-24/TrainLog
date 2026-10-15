import Foundation

/// A small, read-only projection. Never shares notes, body weight or the database.
public struct WorkoutWidgetSnapshot: Codable, Equatable, Sendable {
    public struct Record: Codable, Equatable, Sendable {
        public var date: Date
        public var minutes: Int
        public var workingSets: Int
    }
    public var version = 1
    public var updatedAt: Date
    public var weeklyGoal: Int
    public var draftID: UUID?
    public var records: [Record]

    public init(sessions: [Session], weeklyGoal: Int, now: Date = Date(), calendar: Calendar = .current) {
        updatedAt = now; self.weeklyGoal = weeklyGoal
        draftID = sessions.first { $0.status == .draft }?.id
        let cutoff = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)) ?? now
        records = sessions.filter { $0.status == .completed && $0.date >= cutoff }.map {
            Record(date: $0.date, minutes: Int($0.elapsed(at: now) / 60),
                   workingSets: $0.exercises.reduce(0) { $0 + WorkoutStatisticsService.workingSets($1).count })
        }
    }
    public func today(at date: Date, calendar: Calendar = .current) -> [Record] {
        records.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    public func week(at date: Date, calendar: Calendar = .current) -> [Record] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    public func days(at date: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

public enum WorkoutDeepLink: Equatable, Sendable {
    case workout(UUID?), calendar
    public init?(url: URL) {
        guard url.scheme == "trainlog", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "workout":
            if parts.isEmpty { self = .workout(nil) }
            else if parts.count == 1, let id = UUID(uuidString: parts[0]) { self = .workout(id) }
            else { return nil }
        case "calendar": guard parts.isEmpty else { return nil }; self = .calendar
        default: return nil
        }
    }
    public var url: URL {
        switch self {
        case .workout(let id): return URL(string: "trainlog://workout" + (id.map { "/\($0.uuidString)" } ?? ""))!
        case .calendar: return URL(string: "trainlog://calendar")!
        }
    }
}

public struct WorkoutLiveState: Codable, Hashable, Sendable {
    public enum Phase: String, Codable, Sendable { case training, paused, resting, finished }
    public var phase: Phase
    public var workingSets: Int
    public var elapsedSeconds: Int
    public var timerOrigin: Date?
    public var restDeadline: Date?
    public var updatedAt: Date

    public init(session: Session, restDeadline: Date?, now: Date = Date()) {
        updatedAt = now
        workingSets = session.exercises.reduce(0) { $0 + WorkoutStatisticsService.workingSets($1).count }
        elapsedSeconds = Int(session.elapsed(at: now))
        timerOrigin = session.timerStartedAt != nil && session.manualDurationSeconds == nil
            ? now.addingTimeInterval(-Double(elapsedSeconds)) : nil
        self.restDeadline = restDeadline.flatMap { $0 > now ? $0 : nil }
        if session.status == .completed { phase = .finished; self.restDeadline = nil; timerOrigin = nil }
        else if self.restDeadline != nil { phase = .resting }
        else { phase = timerOrigin == nil ? .paused : .training }
    }
    public var staleDate: Date { restDeadline ?? updatedAt.addingTimeInterval(4 * 3600) }
    public func label(stale: Bool) -> String {
        if phase == .finished { return "训练已完成" }
        if stale { return phase == .resting ? "休息结束" : "打开训练更新状态" }
        switch phase {
        case .training: return "训练中"
        case .paused: return "计时已暂停"
        case .resting: return "组间休息"
        case .finished: return "训练已完成"
        }
    }
}
