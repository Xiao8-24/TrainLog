import Foundation

/// Stable activity identifiers are shared with the watch and backups.
public enum CardioActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case outdoorRun, indoorRun, outdoorWalk, indoorWalk, outdoorCycle, indoorCycle
    case swimming, openWaterSwimming, rowing, elliptical, stairClimbing, jumpRope
    case hiking, hiit, mixedCardio, dance, kickboxing, boxing, crossTraining
    case yoga, pilates, flexibility, coreTraining, functionalStrength, traditionalStrength
    case badminton, tennis, tableTennis, basketball, football, volleyball, squash
    case skating, crossCountrySkiing, downhillSkiing, snowboarding, climbing, paddling
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .outdoorRun: return "户外跑步"; case .indoorRun: return "室内跑步"
        case .outdoorWalk: return "户外步行"; case .indoorWalk: return "室内步行"
        case .outdoorCycle: return "户外骑行"; case .indoorCycle: return "室内单车"
        case .swimming: return "泳池游泳"; case .openWaterSwimming: return "开放水域游泳"
        case .rowing: return "划船机"; case .elliptical: return "椭圆机"
        case .stairClimbing: return "爬楼机"; case .jumpRope: return "跳绳"
        case .hiking: return "徒步"; case .hiit: return "高强度间歇训练"
        case .mixedCardio: return "混合有氧"; case .dance: return "健身舞"
        case .kickboxing: return "搏击健身"; case .boxing: return "拳击"
        case .crossTraining: return "交叉训练"; case .yoga: return "瑜伽"
        case .pilates: return "普拉提"; case .flexibility: return "柔韧性训练"
        case .coreTraining: return "核心训练"; case .functionalStrength: return "功能性力量训练"
        case .traditionalStrength: return "传统力量训练"; case .badminton: return "羽毛球"
        case .tennis: return "网球"; case .tableTennis: return "乒乓球"
        case .basketball: return "篮球"; case .football: return "足球"
        case .volleyball: return "排球"; case .squash: return "壁球"
        case .skating: return "滑冰与轮滑"; case .crossCountrySkiing: return "越野滑雪"
        case .downhillSkiing: return "高山滑雪"; case .snowboarding: return "单板滑雪"
        case .climbing: return "攀岩"; case .paddling: return "桨类运动"
        }
    }
    public var symbol: String {
        switch self {
        case .outdoorRun, .indoorRun: return "figure.run"
        case .outdoorWalk, .indoorWalk, .hiking: return "figure.walk"
        case .outdoorCycle, .indoorCycle: return "figure.outdoor.cycle"
        case .swimming, .openWaterSwimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"; case .yoga: return "figure.yoga"
        case .traditionalStrength, .functionalStrength: return "dumbbell.fill"
        default: return "figure.mixed.cardio"
        }
    }
    public var supportsDistance: Bool {
        [.outdoorRun, .indoorRun, .outdoorWalk, .indoorWalk, .outdoorCycle, .indoorCycle,
         .swimming, .openWaterSwimming, .rowing, .hiking, .skating, .crossCountrySkiing,
         .downhillSkiing, .snowboarding, .paddling].contains(self)
    }
    public var usesSpeed: Bool { [.outdoorCycle, .indoorCycle, .skating, .downhillSkiing, .snowboarding].contains(self) }
    public var isOutdoor: Bool {
        [.outdoorRun, .outdoorWalk, .outdoorCycle, .openWaterSwimming, .hiking,
         .skating, .crossCountrySkiing, .downhillSkiing, .snowboarding, .paddling].contains(self)
    }
    public var isAerobic: Bool { ![.yoga, .pilates, .flexibility, .coreTraining, .functionalStrength, .traditionalStrength].contains(self) }
}

public struct HeartRatePoint: Codable, Hashable, Sendable {
    public var date: Date
    public var bpm: Double
    public init(date: Date, bpm: Double) { self.date = date; self.bpm = bpm }
}

public struct ActivityRecord: Codable, Hashable, Sendable {
    public var kind: CardioActivity = .outdoorRun
    public var distanceMeters: Double?
    public var activeEnergyKcal: Double?
    public var averageHeartRate: Double?
    public var maximumHeartRate: Double?
    public var heartRate: [HeartRatePoint] = []
    /// Watch owns this HealthKit workout; the phone must never export a second copy.
    public var watchWorkoutID: UUID?
    public var source: String = "manual"
    public init(kind: CardioActivity = .outdoorRun) { self.kind = kind }
    public func paceSecondsPerKilometer(duration: TimeInterval) -> Double? {
        guard kind.supportsDistance, let meters = distanceMeters, meters.isFinite, meters > 0,
              duration.isFinite, duration > 0 else { return nil }
        return duration * 1000 / meters
    }
    public func speedKilometersPerHour(duration: TimeInterval) -> Double? {
        paceSecondsPerKilometer(duration: duration).map { 3600 / $0 }
    }
    public var hasWatchMeasurements: Bool { source == "appleWatch" }
}

public struct CardioTotals: Equatable, Sendable {
    public var sessions = 0
    public var durationSeconds = 0.0
    public var distanceMeters: Double?
    public var activeEnergyKcal: Double?
}

public enum CardioAnalysis {
    public struct EffortComparison: Equatable, Sendable {
        public var count: Int
        public var previousMeanHeartRate: Double
        public var difference: Double
    }
    /// A descriptive comparison, not a fitness classification. Narrow the
    /// context to the same activity, similar active pace and recorded distance.
    public static func comparableEffort(for current: Session, history: [Session]) -> EffortComparison? {
        guard current.status == .completed, current.elapsed() >= 600,
              let activity = current.activity, activity.kind.isAerobic, activity.hasWatchMeasurements,
              let mean = activity.averageHeartRate, let distance = activity.distanceMeters, distance > 0,
              let pace = activity.paceSecondsPerKilometer(duration: current.elapsed()) else { return nil }
        let candidates = history.filter { other in
            guard other.id != current.id, other.status == .completed, other.date < current.date, other.elapsed() >= 600,
                  let record = other.activity, record.kind == activity.kind, record.hasWatchMeasurements,
                  record.averageHeartRate != nil, let otherDistance = record.distanceMeters,
                  let otherPace = record.paceSecondsPerKilometer(duration: other.elapsed()) else { return false }
            return abs(otherPace / pace - 1) <= 0.05 && abs(otherDistance / distance - 1) <= 0.20
        }.sorted { $0.date > $1.date }.prefix(5)
        let values = candidates.compactMap { $0.activity?.averageHeartRate }
        guard values.count >= 2 else { return nil }
        let previous = values.reduce(0, +) / Double(values.count)
        return EffortComparison(count: values.count, previousMeanHeartRate: previous, difference: mean - previous)
    }
    public static func totals(_ sessions: [Session], interval: DateInterval? = nil) -> CardioTotals {
        let records = sessions.filter { $0.status == .completed && $0.mode == .cardio && (interval?.includes($0.date) ?? true) }
        let distances = records.compactMap { $0.activity?.distanceMeters }
        let energies = records.compactMap { $0.activity?.activeEnergyKcal }
        return CardioTotals(sessions: records.count, durationSeconds: records.reduce(0) { $0 + $1.elapsed() },
            distanceMeters: distances.isEmpty ? nil : distances.reduce(0, +),
            activeEnergyKcal: energies.isEmpty ? nil : energies.reduce(0, +))
    }
    /// Describes the recorded effort without diagnosing fitness or inventing VO₂ max.
    public static func observation(for session: Session) -> String {
        guard let record = session.activity else { return "暂无运动数据。" }
        guard record.kind.isAerobic else { return "这类训练以时长和运动感受为主，不换算为有氧适能。" }
        if record.averageHeartRate == nil { return "已记录运动时长。使用 Apple Watch 训练并允许心率读取后，可查看本次心率与能量数据。" }
        return "心率反映本次运动中的身体反应。可结合相同运动的配速、时长和主观感受观察变化；单次训练不能确定有氧适能。"
    }
}
