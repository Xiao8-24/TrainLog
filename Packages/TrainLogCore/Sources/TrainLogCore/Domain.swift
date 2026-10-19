import Foundation

public enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest, trapezius, upperBack, lats, frontDeltoid, sideDeltoid, rearDeltoid
    case biceps, triceps, forearms, abs, obliques, lowerBack, glutes, quadriceps, hamstrings, calves, tibialis
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .chest: return "胸部"
        case .trapezius: return "斜方肌"
        case .upperBack: return "中上背"
        case .lats: return "背阔肌"
        case .frontDeltoid: return "前肩"
        case .sideDeltoid: return "侧肩"
        case .rearDeltoid: return "后肩"
        case .biceps: return "肱二头肌"
        case .triceps: return "肱三头肌"
        case .forearms: return "前臂"
        case .abs: return "腹直肌"
        case .obliques: return "腹外斜肌"
        case .lowerBack: return "下背部"
        case .glutes: return "臀部"
        case .quadriceps: return "股四头肌"
        case .hamstrings: return "腘绳肌"
        case .calves: return "小腿后侧"
        case .tibialis: return "小腿前侧"
        }
    }
}

public enum WorkoutMode: String, Codable, Sendable { case quick, detailed, cardio }
public enum SessionStatus: String, Codable, Sendable { case draft, completed }
public enum SetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case working, warmup, drop, failed
    public var id: String { rawValue }
    public var name: String {
        switch self { case .working: return "正式"; case .warmup: return "热身"; case .drop: return "递减"; case .failed: return "失败" }
    }
}
public enum Intensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case light, moderate, hard
    public var id: String { rawValue }
    public var name: String { switch self { case .light: return "轻"; case .moderate: return "中"; case .hard: return "高" } }
    public var ordinal: Double { switch self { case .light: return 1; case .moderate: return 2; case .hard: return 3 } }
}
public enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell, dumbbell, cable, machine, bodyweight, other
    public var id: String { rawValue }
    public var name: String {
        switch self { case .barbell: return "杠铃"; case .dumbbell: return "哑铃"; case .cable: return "绳索"; case .machine: return "器械"; case .bodyweight: return "自重"; case .other: return "其他" }
    }
}
public enum TrackingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case weightReps, bodyweightReps, assistedReps, duration
    public var id: String { rawValue }
    public var name: String {
        switch self { case .weightReps: return "负重 × 次数"; case .bodyweightReps: return "自重 × 次数"; case .assistedReps: return "辅助重量 × 次数"; case .duration: return "持续时间" }
    }
}
public enum LoadingConvention: String, Codable, CaseIterable, Identifiable, Sendable {
    case total, perHand, bodyweight, assistance, timeOnly
    public var id: String { rawValue }
    public var name: String {
        switch self { case .total: return "总外部负重"; case .perHand: return "每只哑铃（双手同时）"; case .bodyweight: return "自重（不估算体重负荷）"; case .assistance: return "辅助重量（越小越难）"; case .timeOnly: return "仅时间" }
    }
    public var volumeMultiplier: Double { self == .perHand ? 2 : 1 }
}
public enum MovementPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull, squat, hinge
    public var id: String { rawValue }
    public var name: String {
        switch self { case .horizontalPush: return "水平推"; case .verticalPush: return "垂直推"; case .horizontalPull: return "水平拉"; case .verticalPull: return "垂直拉"; case .squat: return "蹲类"; case .hinge: return "髋铰链" }
    }
}
public enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kg, lb
    public var id: String { rawValue }
    public func display(_ kilograms: Double) -> Double { self == .kg ? kilograms : kilograms * 2.2046226218487757 }
    public func kilograms(_ value: Double) -> Double { self == .kg ? value : value / 2.2046226218487757 }
}
public enum ThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var name: String { switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" } }
}

public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var englishName: String
    public var primary: [MuscleGroup]
    public var secondary: [MuscleGroup]
    public var equipment: Equipment
    public var tracking: TrackingMode
    public var loading: LoadingConvention
    public var pattern: MovementPattern?
    public var allowsEstimate: Bool
    public var isCustom: Bool
    public var isFavorite: Bool
    public var isArchived: Bool
    public init(id: UUID = UUID(), name: String, englishName: String = "", primary: [MuscleGroup], secondary: [MuscleGroup] = [], equipment: Equipment = .barbell, tracking: TrackingMode = .weightReps, loading: LoadingConvention = .total, pattern: MovementPattern? = nil, allowsEstimate: Bool = false, isCustom: Bool = false, isFavorite: Bool = false, isArchived: Bool = false) {
        self.id = id; self.name = name; self.englishName = englishName
        self.primary = primary; self.secondary = secondary; self.equipment = equipment
        self.tracking = tracking; self.loading = loading; self.pattern = pattern
        self.allowsEstimate = allowsEstimate; self.isCustom = isCustom; self.isFavorite = isFavorite; self.isArchived = isArchived
    }
    // Historical snapshots keep mapping and loading conventions stable after catalog edits.
    public var comparisonKey: String { "\(id.uuidString)|\(tracking.rawValue)|\(loading.rawValue)|\(equipment.rawValue)" }
}

public struct TrainingSet: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var weightKg: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    public var kind: SetKind = .working
    public var rpe: Double?
    public var rir: Double?
    public var isCompleted: Bool = false
    public var restSeconds: Int = 90
    public var notes: String = ""
    public var timing: SetTiming?
    public init(weightKg: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, kind: SetKind = .working, rpe: Double? = nil, rir: Double? = nil, isCompleted: Bool = false) {
        self.weightKg = weightKg; self.reps = reps; self.durationSeconds = durationSeconds
        self.kind = kind; self.rpe = rpe; self.rir = rir; self.isCompleted = isCompleted
    }
    public func copied() -> TrainingSet { var copy = self; copy.id = UUID(); copy.isCompleted = false; copy.timing = nil; return copy }
}
public struct ExerciseEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var exercise: Exercise
    public var sets: [TrainingSet]
    public var notes: String = ""
    public init(exercise: Exercise, sets: [TrainingSet] = [TrainingSet()]) { self.exercise = exercise; self.sets = sets }
}
public struct QuickEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var muscle: MuscleGroup
    public var intensity: Intensity?
    public init(muscle: MuscleGroup, intensity: Intensity? = nil) { self.muscle = muscle; self.intensity = intensity }
}
public struct Session: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var date: Date
    public var startTime: Date
    public var endTime: Date?
    public var status: SessionStatus = .draft
    public var mode: WorkoutMode
    public var intensity: Intensity?
    public var sessionRPE: Double?
    public var notes: String = ""
    public var exercises: [ExerciseEntry] = []
    public var quickEntries: [QuickEntry] = []
    // Optional additions keep backups created before cardio/Watch readable.
    public var activity: ActivityRecord?
    public var watchLink: WatchTrainingLink?
    public var phoneLink: WatchLinkReference?
    public var plan: TrainingPlanReference?
    public var accumulatedSeconds: TimeInterval = 0
    public var timerStartedAt: Date?
    public var manualDurationSeconds: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var watchManagesHealthRecord: Bool { activity?.hasWatchMeasurements == true || watchLink?.ownsHealthRecord == true }
    public init(mode: WorkoutMode, date: Date = Date()) {
        self.mode = mode; self.date = date; self.startTime = date
        self.createdAt = date; self.updatedAt = date
        self.timerStartedAt = mode == .quick ? nil : date
        if mode == .cardio { self.activity = ActivityRecord() }
    }
    public func elapsed(at now: Date = Date()) -> TimeInterval {
        if let manualDurationSeconds { return Double(manualDurationSeconds) }
        return accumulatedSeconds + (timerStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }
    public mutating func pause(at now: Date = Date()) {
        accumulatedSeconds = elapsed(at: now); timerStartedAt = nil
        for e in exercises.indices { for s in exercises[e].sets.indices { exercises[e].sets[s].timing?.pause(at: now) } }
    }
    public mutating func finish(at now: Date = Date()) {
        pause(at: now)
        for e in exercises.indices { for s in exercises[e].sets.indices {
            if exercises[e].sets[s].timing?.endedAt == nil { exercises[e].sets[s].timing?.finish(at: now) }
        } }
        endTime = now; status = .completed; updatedAt = now
    }
}
public struct BodyWeight: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var date: Date
    public var weightKg: Double
    public init(date: Date = Date(), weightKg: Double) { self.date = date; self.weightKg = weightKg }
}
public struct TemplateItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var exerciseID: UUID
    public var setCount: Int
    public var weightKg: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    public var restSeconds: Int?
    public init(exerciseID: UUID, setCount: Int = 3, weightKg: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, restSeconds: Int? = nil) {
        self.exerciseID = exerciseID; self.setCount = setCount; self.weightKg = weightKg; self.reps = reps
        self.durationSeconds = durationSeconds; self.restSeconds = restSeconds
    }
}
public struct TrainingTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var items: [TemplateItem]
    public init(name: String, items: [TemplateItem]) { self.name = name; self.items = items }
}
public struct Settings: Codable, Hashable, Sendable {
    public var unit: WeightUnit = .kg
    public var weeklyGoal: Int = 4
    public var trainingGoal: String = "保持规律"
    public var theme: ThemePreference = .system
    public var hasOnboarded: Bool = false
    public var restSeconds: Int = 90
    public var notifyRest: Bool = false
    public var representatives: [String: UUID] = [:]
    public init() {}
}

public enum TimeRange: String, CaseIterable, Identifiable, Sendable {
    case today, week, month, quarter, year, all
    public var id: String { rawValue }
    public var name: String {
        switch self { case .today: return "今日"; case .week: return "7 天"; case .month: return "30 天"; case .quarter: return "90 天"; case .year: return "1 年"; case .all: return "全部" }
    }
    public func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let days: Int
        switch self { case .today: days = 1; case .week: days = 7; case .month: days = 30; case .quarter: days = 90; case .year: days = 365; case .all: return DateInterval(start: .distantPast, end: end) }
        return DateInterval(start: calendar.date(byAdding: .day, value: 1 - days, to: today) ?? today, end: end)
    }
}
public extension DateInterval {
    func includes(_ date: Date) -> Bool { date >= start && date < end }
}
public enum TrainingCalendar {
    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var cal = calendar; cal.firstWeekday = 2; cal.minimumDaysInFirstWeek = 4
        return cal.dateInterval(of: .weekOfYear, for: date) ?? TimeRange.week.interval(now: date, calendar: cal)
    }
}

