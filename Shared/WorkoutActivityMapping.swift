import HealthKit
import TrainLogCore

extension CardioActivity {
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .outdoorRun, .indoorRun: return .running
        case .outdoorWalk, .indoorWalk: return .walking
        case .outdoorCycle, .indoorCycle: return .cycling
        case .swimming, .openWaterSwimming: return .swimming
        case .rowing: return .rowing; case .elliptical: return .elliptical
        case .stairClimbing: return .stairClimbing; case .jumpRope: return .jumpRope
        case .hiking: return .hiking; case .hiit: return .highIntensityIntervalTraining
        case .mixedCardio: return .mixedCardio; case .dance: return .cardioDance
        case .kickboxing: return .kickboxing; case .boxing: return .boxing
        case .crossTraining: return .crossTraining; case .yoga: return .yoga
        case .pilates: return .pilates; case .flexibility: return .flexibility
        case .coreTraining: return .coreTraining; case .functionalStrength: return .functionalStrengthTraining
        case .traditionalStrength: return .traditionalStrengthTraining; case .badminton: return .badminton
        case .tennis: return .tennis; case .tableTennis: return .tableTennis
        case .basketball: return .basketball; case .football: return .soccer
        case .volleyball: return .volleyball; case .squash: return .squash
        case .skating: return .skatingSports; case .crossCountrySkiing: return .crossCountrySkiing
        case .downhillSkiing: return .downhillSkiing; case .snowboarding: return .snowboarding
        case .climbing: return .climbing; case .paddling: return .paddleSports
        }
    }
    var workoutConfiguration: HKWorkoutConfiguration {
        let value = HKWorkoutConfiguration()
        value.activityType = healthKitType
        value.locationType = isOutdoor ? .outdoor : .indoor
        if self == .swimming { value.swimmingLocationType = .pool }
        if self == .openWaterSwimming { value.swimmingLocationType = .openWater }
        return value
    }
    static func matching(_ configuration: HKWorkoutConfiguration) -> CardioActivity {
        allCases.first { $0.healthKitType == configuration.activityType && $0.isOutdoor == (configuration.locationType == .outdoor) } ?? .mixedCardio
    }
}
