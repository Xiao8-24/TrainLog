import Foundation
import HealthKit
import Observation
import TrainLogCore

struct HealthReference: Identifiable {
    var id: UUID
    var date: Date
    var value: Double
    var source: String
}
struct HealthReferenceSnapshot {
    var oxygen: HealthReference?
    var fitness: [HealthReference] = []
}

/// Read access is requested separately from workout export, on an explicit tap.
/// HealthKit intentionally doesn't reveal whether individual read scopes were denied.
@MainActor @Observable final class HealthInsights {
    private let store = HKHealthStore()
    private(set) var enabled = UserDefaults.standard.bool(forKey: "healthInsightsEnabled")
    private(set) var busy = false
    private(set) var issue: String?
    func enable() async {
        guard !busy else { return }
        guard HKHealthStore.isHealthDataAvailable(), !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { issue = "当前环境无法读取真实健康数据。"; return }
        busy = true; defer { busy = false }
        do {
            let types = [HKQuantityTypeIdentifier.oxygenSaturation, .vo2Max].compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            try await store.requestAuthorization(toShare: [], read: Set<HKObjectType>(types))
            enabled = true; UserDefaults.standard.set(true, forKey: "healthInsightsEnabled"); issue = nil
        } catch { issue = error.localizedDescription }
    }
    func disable() { enabled = false; UserDefaults.standard.set(false, forKey: "healthInsightsEnabled") }
    func references(at date: Date) async throws -> HealthReferenceSnapshot {
        guard enabled, !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return HealthReferenceSnapshot() }
        let oxygen = try await samples(.oxygenSaturation, end: date, days: 30, limit: 1, unit: .percent())
        let vo2Unit = HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute())
        let fitness = try await samples(.vo2Max, end: date, days: 180, limit: 2, unit: vo2Unit)
        return HealthReferenceSnapshot(oxygen: oxygen.first, fitness: fitness)
    }
    private func samples(_ identifier: HKQuantityTypeIdentifier, end: Date, days: Int, limit: Int, unit: HKUnit) async throws -> [HealthReference] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: end.addingTimeInterval(-Double(days) * 86400), end: end, options: [.strictStartDate, .strictEndDate])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let samples = (result as? [HKQuantitySample] ?? []).filter { $0.metadata?[HKMetadataKeyWasUserEntered] as? Bool != true }
                continuation.resume(returning: samples.compactMap { sample in
                    let value = sample.quantity.doubleValue(for: unit)
                    guard value.isFinite, value > 0, identifier != .oxygenSaturation || value <= 1 else { return nil }
                    return HealthReference(id: sample.uuid, date: sample.endDate, value: value, source: sample.sourceRevision.source.name)
                })
            }
            store.execute(query)
        }
    }
}
