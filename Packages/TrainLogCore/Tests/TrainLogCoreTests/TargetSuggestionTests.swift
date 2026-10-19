import XCTest
@testable import TrainLogCore

final class TargetSuggestionTests: XCTestCase {
    private var exercise: Exercise { ExerciseCatalog.exercises[0] }
    private var target: TemplateItem { TemplateItem(exerciseID: exercise.id, setCount: 2, weightKg: 60, reps: 8) }
    private func history(reps: Int = 8, rpe: Double? = 7, rir: Double? = nil) -> [Session] {
        [2.0, 1.0].map { days in
            let start = Date().addingTimeInterval(-days * 86400)
            var session = Session(mode: .detailed, date: start)
            session.exercises = [ExerciseEntry(exercise: exercise, sets: (0..<2).map { _ in TrainingSet(weightKg: 60, reps: reps, rpe: rpe, rir: rir, isCompleted: true) })]
            session.finish(at: start.addingTimeInterval(120)); return session
        }
    }
    private func suggest(_ records: [Session], item: TemplateItem? = nil, goal: String = "提升力量") -> TargetSuggestion {
        TargetSuggestionService.suggest(exercise: exercise, target: item ?? target, sessions: records, goal: goal)
    }
    func testTwoComparableLowEffortRecordsOfferOneRepWithoutMutatingHistory() {
        let records = history(); let result = suggest(records)
        XCTAssertEqual(result.kind, .addRepetition); XCTAssertEqual(result.proposed?.reps, 9)
        XCTAssertEqual(result.proposed?.weightKg, 60); XCTAssertEqual(result.evidence.count, 2)
        XCTAssertEqual(records[0].exercises[0].sets[0].reps, 8)
    }
    func testRepeatedExceedingTargetsOffersSmallEditableLoadReference() {
        let result = suggest(history(reps: 10))
        XCTAssertEqual(result.kind, .increaseLoad)
        XCTAssertEqual(result.proposed?.weightKg ?? 0, 61.2, accuracy: 0.0001)
        XCTAssertEqual(result.proposed?.reps, 8)
        XCTAssertTrue(result.reasons[0].contains("器械刻度"))
    }
    func testMissingOrConflictingPerSetEffortNeverGeneratesProgression() {
        XCTAssertEqual(suggest(history(rpe: nil)).kind, .unavailable)
        XCTAssertEqual(suggest(history(rpe: 3, rir: 0)).kind, .unavailable)
        var records = history(); records[0].sessionRPE = 7; records[0].exercises[0].sets[0].rpe = nil
        XCTAssertEqual(suggest(records).kind, .unavailable)
    }
    func testHighEffortIncompleteOrFailureSetsMaintain() {
        XCTAssertEqual(suggest(history(rpe: 9)).kind, .maintain)
        var records = history(); records[0].exercises[0].sets[0].isCompleted = false
        XCTAssertEqual(suggest(records).kind, .maintain)
        records = history(); records[0].exercises[0].sets.append(TrainingSet(weightKg: 60, reps: 2, kind: .failed, isCompleted: true))
        XCTAssertEqual(suggest(records).kind, .maintain)
    }
    func testStaleSingleDuplicatedAndDraftRecordsAreInsufficient() {
        let single = history()[0]
        XCTAssertEqual(suggest([single]).kind, .unavailable)
        XCTAssertEqual(suggest([single, single]).kind, .unavailable)
        var records = history(); records[0].date = Date().addingTimeInterval(-61 * 86400)
        XCTAssertEqual(suggest(records).kind, .unavailable)
        records = history(); records[0].status = .draft
        XCTAssertEqual(suggest(records).kind, .unavailable)
    }
    func testDifferentWeightsAndConventionsAreNeverMerged() {
        var records = history(); records[0].exercises[0].sets[0].weightKg = 65
        XCTAssertEqual(suggest(records).kind, .unavailable)
        records = history(); records[0].exercises[0].exercise.loading = .perHand
        XCTAssertEqual(suggest(records).kind, .unavailable)
    }
    func testMaintenanceGoalRIRAndRepUpperBoundAreExplicit() {
        XCTAssertEqual(suggest(history(), goal: "保持规律").kind, .maintain)
        XCTAssertEqual(suggest(history(rpe: nil, rir: 3)).kind, .addRepetition)
        var item = target; item.reps = 20
        XCTAssertEqual(suggest(history(reps: 20), item: item).kind, .maintain)
    }
}
