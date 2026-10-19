import XCTest
@testable import TrainLogCore

final class TrainingReviewTests: XCTestCase {
    private let base = Date().addingTimeInterval(-3600)
    private func planned() throws -> Session {
        try TrainingPlan(name: "目标", items: [TemplateItem(exerciseID: ExerciseCatalog.exercises[0].id, setCount: 2, weightKg: 60, reps: 8)]).session(catalog: ExerciseCatalog.exercises, at: base)
    }
    func testStartSnapshotStaysUnchangedAfterLiveEditsAndMetadataRoundTrip() throws {
        var value = try planned(); let target = try XCTUnwrap(value.plan?.targets)
        value.exercises[0].sets[0].weightKg = 65; value.exercises[0].sets[0].reps = 9
        let metadata = try JSONDecoder().decode(SessionTrainingMetadata.self, from: JSONEncoder().encode(SessionTrainingMetadata(session: value)))
        XCTAssertEqual(metadata.plan?.targets, target)
        XCTAssertEqual(metadata.plan?.targets?[0].sets[0].weightKg, 60)
        XCTAssertEqual(value.exercises[0].sets[0].weightKg, 65)
    }
    func testReviewTracksAddedRemovedChangedAndOnlyRecordedTimes() throws {
        var value = try planned()
        let e = value.exercises[0].id, first = value.exercises[0].sets[0].id
        value.exercises[0].sets[0].reps = 9
        try value.startSet(entryID: e, setID: first, at: base.addingTimeInterval(5))
        try value.completeSet(entryID: e, setID: first, at: base.addingTimeInterval(25))
        value.exercises[0].sets.removeLast()
        value.exercises[0].sets.append(TrainingSet(weightKg: 55, reps: 10, isCompleted: true))
        value.finish(at: base.addingTimeInterval(100))
        let review = try XCTUnwrap(PlanReviewService.review(value))
        XCTAssertEqual(review.plannedSets, 2); XCTAssertEqual(review.completedWorkingSets, 2)
        XCTAssertEqual(review.changedSets, 3); XCTAssertEqual(review.timedCompletedSets, 1)
        XCTAssertEqual(review.untimedCompletedSets, 1); XCTAssertEqual(review.recordedSetSeconds, 20)
        XCTAssertTrue(review.exercises[0].sets.contains { $0.target != nil && $0.actual == nil })
        XCTAssertTrue(review.exercises[0].sets.contains { $0.target == nil && $0.actual != nil })
    }
    func testLegacyReferenceDoesNotInventTargetsAndV5BackupKeepsSnapshot() throws {
        var value = try planned(); value.exercises[0].sets[0].isCompleted = true; value.finish(at: base.addingTimeInterval(20))
        let backup = Backup(sessions: [value], exercises: ExerciseCatalog.exercises, templates: [], bodyWeights: [], settings: Settings())
        let restored = try BackupService.decode(BackupService.encode(backup))
        XCTAssertEqual(restored.schemaVersion, 5)
        XCTAssertEqual(restored.sessions[0].plan?.targets, value.plan?.targets)
        var object = try JSONSerialization.jsonObject(with: BackupService.encode(backup)) as! [String: Any]
        object["schemaVersion"] = 4
        var records = object["sessions"] as! [[String: Any]]
        var plan = records[0]["plan"] as! [String: Any]; plan.removeValue(forKey: "targets"); records[0]["plan"] = plan; object["sessions"] = records
        let old = try BackupService.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(PlanReviewService.review(old.sessions[0]))
        XCTAssertTrue(old.settings.showsTargetSuggestions)
    }
    func testActualCopyPreservesVariedLoadsExcludesWarmupsAndCreatesFreshIDs() throws {
        var value = try planned()
        value.exercises[0].sets = [TrainingSet(weightKg: 30, reps: 10, kind: .warmup, isCompleted: true), TrainingSet(weightKg: 60, reps: 8, isCompleted: true), TrainingSet(weightKg: 65, reps: 6, isCompleted: true), TrainingSet(weightKg: 65, reps: 6, isCompleted: true), TrainingSet(weightKg: 70, reps: 4)]
        value.finish(at: base.addingTimeInterval(60))
        let copy = try PlanReviewService.copiedPlan(from: value, scheduledAt: Date().addingTimeInterval(86400), catalog: ExerciseCatalog.exercises)
        XCTAssertEqual(copy.items.count, 2); XCTAssertEqual(copy.items.map(\.setCount), [1, 2])
        XCTAssertEqual(copy.items.map(\.weightKg), [60, 65]); XCTAssertEqual(copy.items.map(\.reps), [8, 6])
        XCTAssertNotEqual(copy.id, value.plan?.id)
        let next = try copy.session(catalog: ExerciseCatalog.exercises)
        XCTAssertTrue(next.exercises.flatMap(\.sets).allSatisfy { !$0.isCompleted && $0.timing == nil })
        XCTAssertTrue(Set(next.exercises.flatMap(\.sets).map(\.id)).isDisjoint(with: value.exercises.flatMap(\.sets).map(\.id)))
    }
    func testSnapshotRejectsInvalidOrCompletedTargets() throws {
        var value = try planned()
        value.plan?.targets?[0].sets[0].isCompleted = true
        XCTAssertThrowsError(try RecordValidator.session(value))
        value.plan?.targets?[0].sets[0].isCompleted = false
        value.plan?.targets?[0].sets[0].weightKg = .nan
        XCTAssertThrowsError(try RecordValidator.session(value))
    }
}
