import Foundation
import HealthKit
import TrainLogCore

enum WorkoutHealthAuthorization { case unavailable, notDetermined, denied, authorized }

@MainActor final class UnavailableWorkoutHealthClient: WorkoutHealthClient {
    var authorization: WorkoutHealthAuthorization { .unavailable }
    func requestAuthorization() async throws { throw ValidationError("此环境不连接 Apple 健康。") }
    func save(_ workout: HealthWorkoutExport, version: Int) async throws {}
    func delete(syncIdentifier: String) async throws {}
}

@MainActor protocol WorkoutHealthClient {
    var authorization: WorkoutHealthAuthorization { get }
    func requestAuthorization() async throws
    func save(_ workout: HealthWorkoutExport, version: Int) async throws
    func delete(syncIdentifier: String) async throws
}

@MainActor final class AppleWorkoutHealthClient: WorkoutHealthClient {
    private let store = HKHealthStore()
    var authorization: WorkoutHealthAuthorization {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        case .sharingAuthorized: return .authorized
        @unknown default: return .unavailable
        }
    }
    func requestAuthorization() async throws {
        guard authorization != .unavailable else { throw ValidationError("这台设备暂不支持 Apple 健康。") }
        // Writing a workout doesn't require reading someone else's health data.
        try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
    }
    func save(_ value: HealthWorkoutExport, version: Int) async throws {
        let workout = HKWorkout(activityType: value.activityKind?.healthKitType ?? .traditionalStrengthTraining, start: value.start, end: value.end,
            duration: value.duration, totalEnergyBurned: nil, totalDistance: nil,
            metadata: [HKMetadataKeySyncIdentifier: value.syncIdentifier,
                       HKMetadataKeySyncVersion: NSNumber(value: version),
                       HKMetadataKeyWorkoutBrandName: "TrainLog"])
        // No fabricated calorie or heart-rate samples. HKWorkout's explicit
        // duration preserves paused/manual timing without inventing pause events.
        try await store.save(workout)
    }
    func delete(syncIdentifier: String) async throws {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncIdentifier]),
            HKQuery.predicateForObjects(from: HKSource.default())
        ])
        _ = try await store.deleteObjects(of: HKObjectType.workoutType(), predicate: predicate)
    }
}
