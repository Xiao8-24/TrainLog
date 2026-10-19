import XCTest
@testable import TrainLogCore

final class LiveTrainingTests: XCTestCase {
    private let base = Date().addingTimeInterval(-3600)
    private func workout() -> Session {
        var value = Session(mode: .detailed, date: base)
        value.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8), TrainingSet(weightKg: 60, reps: 8)])]
        return value
    }
    func testOverallStartsAutomaticallyAndSetRestPauseHaveSeparateDurations() throws {
        var value = workout(); let entry = value.exercises[0].id, set = value.exercises[0].sets[0].id
        XCTAssertEqual(value.timerStartedAt, base)
        try value.startSet(entryID: entry, setID: set, at: base.addingTimeInterval(10))
        value.pause(at: base.addingTimeInterval(30))
        XCTAssertEqual(value.exercises[0].sets[0].timing?.elapsed(at: base.addingTimeInterval(60)), 20)
        value.resume(at: base.addingTimeInterval(60))
        try value.completeSet(entryID: entry, setID: set, at: base.addingTimeInterval(80))
        XCTAssertNil(value.activeSet)
        XCTAssertEqual(value.exercises[0].sets[0].timing?.elapsed(), 40)
        value.finish(at: base.addingTimeInterval(100))
        XCTAssertEqual(value.elapsed(), 70)
        try RecordValidator.session(value)
        XCTAssertEqual(WorkoutStatisticsService.totals([value]).volumeKg, 480)
    }
    func testOnlyOneSetCanRunAndMissingInputDoesNotStopItsTimer() throws {
        var value = workout(); value.exercises[0].sets[0].reps = nil
        let entry = value.exercises[0].id, first = value.exercises[0].sets[0].id, second = value.exercises[0].sets[1].id
        try value.startSet(entryID: entry, setID: first, at: base)
        XCTAssertThrowsError(try value.startSet(entryID: entry, setID: second, at: base.addingTimeInterval(1)))
        XCTAssertThrowsError(try value.completeSet(entryID: entry, setID: first, at: base.addingTimeInterval(10)))
        XCTAssertNotNil(value.exercises[0].sets[0].timing?.timerStartedAt)
        XCTAssertFalse(value.exercises[0].sets[0].isCompleted)
        value.exercises[0].sets[0].reps = 8
        try value.completeSet(entryID: entry, setID: first, at: base.addingTimeInterval(30))
        XCTAssertEqual(value.exercises[0].sets[0].timing?.elapsed(), 30)
    }
    func testTimedDurationExerciseGetsMeasuredSecondsAndCopyClearsClock() throws {
        var value = Session(mode: .detailed, date: base)
        value.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises.first(where: { $0.tracking == .duration })!)]
        let e = value.exercises[0].id, s = value.exercises[0].sets[0].id
        try value.startSet(entryID: e, setID: s, at: base)
        try value.completeSet(entryID: e, setID: s, at: base.addingTimeInterval(35))
        XCTAssertEqual(value.exercises[0].sets[0].durationSeconds, 35)
        value.exercises[0].sets[0].rpe = 7; value.exercises[0].sets[0].rir = 3
        XCTAssertNil(value.exercises[0].sets[0].copied().rpe)
        XCTAssertNil(value.exercises[0].sets[0].copied().rir)
        XCTAssertEqual(value.exercises[0].sets[0].rpe, 7, "Copy must not clear the source observation")
        XCTAssertNil(value.exercises[0].sets[0].copied().timing)
        XCTAssertFalse(value.exercises[0].sets[0].copied().isCompleted)
    }
    func testBackgroundRoundTripKeepsWallClockAndPausedState() throws {
        var value = workout(); let e = value.exercises[0].id, s = value.exercises[0].sets[0].id
        try value.startSet(entryID: e, setID: s, at: base)
        let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.exercises[0].sets[0].timing?.elapsed(at: base.addingTimeInterval(120)), 120)
        value.pause(at: base.addingTimeInterval(20))
        let paused = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(paused.exercises[0].sets[0].timing?.elapsed(at: base.addingTimeInterval(120)), 20)
    }
    func testFuturePlanCreatesNoStatisticsAndStartsAtActualTimeWithFreshIDs() throws {
        let plan = TrainingPlan(name: "下周胸部", scheduledAt: base.addingTimeInterval(864000), items: [TemplateItem(exerciseID: ExerciseCatalog.exercises[0].id, setCount: 3, weightKg: 60, reps: 8)])
        let first = try plan.session(catalog: ExerciseCatalog.exercises, at: base)
        let second = try plan.session(catalog: ExerciseCatalog.exercises, at: base)
        XCTAssertEqual(first.date, base); XCTAssertEqual(first.timerStartedAt, base)
        XCTAssertEqual(first.plan?.scheduledAt, plan.scheduledAt)
        XCTAssertNotEqual(first.id, second.id); XCTAssertNotEqual(first.exercises[0].sets[0].id, second.exercises[0].sets[0].id)
        XCTAssertEqual(WorkoutStatisticsService.totals([first]).workingSets, 0)
        XCTAssertTrue(first.exercises[0].sets.allSatisfy { !$0.isCompleted && $0.timing == nil })
        let copied = plan.copied(to: base)
        XCTAssertNotEqual(copied.id, plan.id); XCTAssertNotEqual(copied.items[0].id, plan.items[0].id)
    }
    func testLegacyBackupMissingPlansAndTimingsStillReadsAndV4PreservesBoth() throws {
        var value = workout(); let e = value.exercises[0].id, s = value.exercises[0].sets[0].id
        try value.startSet(entryID: e, setID: s, at: base)
        try value.completeSet(entryID: e, setID: s, at: base.addingTimeInterval(30)); value.finish(at: base.addingTimeInterval(50))
        let plan = TrainingPlan(items: [TemplateItem(exerciseID: ExerciseCatalog.exercises[0].id)])
        let backup = Backup(sessions: [value], exercises: ExerciseCatalog.exercises, templates: [], bodyWeights: [], settings: Settings(), plans: [plan])
        let restored = try BackupService.decode(BackupService.encode(backup))
        XCTAssertEqual(restored.plans?.first?.id, plan.id)
        XCTAssertEqual(restored.sessions[0].exercises[0].sets[0].timing?.elapsed(), 30)
        var object = try JSONSerialization.jsonObject(with: BackupService.encode(backup)) as! [String: Any]
        object["schemaVersion"] = 3; object.removeValue(forKey: "plans")
        var sessions = object["sessions"] as! [[String: Any]]
        var exercises = sessions[0]["exercises"] as! [[String: Any]]
        var sets = exercises[0]["sets"] as! [[String: Any]]
        for i in sets.indices { sets[i].removeValue(forKey: "timing") }
        exercises[0]["sets"] = sets; sessions[0]["exercises"] = exercises; object["sessions"] = sessions
        let legacy = try BackupService.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.plans); XCTAssertNil(legacy.sessions[0].exercises[0].sets[0].timing)
    }
    func testMultipleRunningSetsAndInvalidTimingAreRejected() throws {
        var value = workout()
        value.exercises[0].sets[0].timing = SetTiming(at: base)
        value.exercises[0].sets[1].timing = SetTiming(at: base)
        XCTAssertThrowsError(try RecordValidator.session(value))
        value.exercises[0].sets[1].timing = nil
        value.exercises[0].sets[0].timing?.accumulatedSeconds = .nan
        XCTAssertThrowsError(try RecordValidator.session(value))
    }
}
