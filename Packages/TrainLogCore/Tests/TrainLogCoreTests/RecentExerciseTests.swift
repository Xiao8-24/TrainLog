import XCTest
@testable import TrainLogCore

final class RecentExerciseTests: XCTestCase {
    func testHistoryIndexUsesLatestSnapshotExcludesCurrentDraftAndSeparatesLoading() {
        let now = Date()
        let exercise = ExerciseCatalog.exercises[0]
        var old = Session(mode: .detailed, date: now.addingTimeInterval(-200))
        old.exercises = [ExerciseEntry(exercise: exercise, sets: [TrainingSet(weightKg: 40, reps: 8, isCompleted: true)])]
        old.finish(at: now.addingTimeInterval(-100))
        var recent = old; recent.id = UUID(); recent.date = now.addingTimeInterval(-50)
        recent.exercises[0].sets[0].weightKg = 50
        var draft = Session(mode: .detailed); draft.exercises = recent.exercises; draft.exercises[0].sets[0].weightKg = 100
        let index = RecentExerciseIndex(sessions: [old, draft, recent])
        XCTAssertEqual(index.previous(for: exercise)?.sets.first?.weightKg, 50)
        XCTAssertEqual(RecentExerciseIndex(sessions: [recent, old], excluding: recent.id).previous(for: exercise)?.sets.first?.weightKg, 40)
        var otherLoading = exercise; otherLoading.loading = .perHand
        if exercise.loading == .perHand { otherLoading.loading = .total }
        XCTAssertNil(index.previous(for: otherLoading))
    }
}
