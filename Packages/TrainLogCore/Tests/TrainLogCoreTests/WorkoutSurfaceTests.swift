import XCTest
@testable import TrainLogCore

final class WorkoutSurfaceTests: XCTestCase {
    func testLivePresentationIgnoresNoteEditsButTracksPauseAndRestWithExactTimerOrigin() {
        let now = Date(timeIntervalSince1970: 1_700_000_000.123)
        var session = Session(mode: .detailed, date: now.addingTimeInterval(-10))
        session.accumulatedSeconds = 2.25
        let first = WorkoutLiveState(session: session, restDeadline: nil, now: now)
        session.notes = "仅修改备注"
        let later = WorkoutLiveState(session: session, restDeadline: nil, now: now.addingTimeInterval(3.789))
        XCTAssertEqual(first.timerOrigin, session.timerStartedAt?.addingTimeInterval(-2.25))
        XCTAssertTrue(first.hasSamePresentation(as: later))
        let resting = WorkoutLiveState(session: session, restDeadline: now.addingTimeInterval(60), now: now)
        XCTAssertFalse(first.hasSamePresentation(as: resting))
        session.pause(at: now)
        let paused = WorkoutLiveState(session: session, restDeadline: nil, now: now)
        XCTAssertFalse(first.hasSamePresentation(as: paused))
        session.accumulatedSeconds += 5
        XCTAssertFalse(paused.hasSamePresentation(as: WorkoutLiveState(session: session, restDeadline: nil, now: now)))
    }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        value.firstWeekday = 2; value.minimumDaysInFirstWeek = 4
        return value
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func testWidgetRollsAcrossMidnightWithoutCountingDraft() {
        let now = date("2026-10-15T06:59:00Z")
        var completed = Session(mode: .quick, date: now); completed.finish(at: now)
        let draft = Session(mode: .detailed, date: now)
        let value = WorkoutWidgetSnapshot(sessions: [completed, draft], weeklyGoal: 4, now: now, calendar: calendar)
        XCTAssertEqual(value.today(at: now, calendar: calendar).count, 1)
        XCTAssertEqual(value.today(at: now.addingTimeInterval(120), calendar: calendar).count, 0)
        XCTAssertEqual(value.draftID, draft.id)
    }
    func testWeekUsesCalendarBoundariesAndSurvivesDST() {
        let now = date("2026-11-01T20:00:00Z")
        var session = Session(mode: .quick, date: now); session.finish(at: now)
        let value = WorkoutWidgetSnapshot(sessions: [session], weeklyGoal: 3, now: now, calendar: calendar)
        let days = value.days(at: now, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(Set(days.map { calendar.component(.day, from: $0) }).count, 7)
        XCTAssertEqual(value.week(at: now, calendar: calendar).count, 1)
        XCTAssertTrue(value.week(at: date("2026-11-02T09:00:00Z"), calendar: calendar).isEmpty)
    }
    func testDeepLinksRoundTripAndRejectMalformedActions() {
        let id = UUID()
        XCTAssertEqual(WorkoutDeepLink(url: WorkoutDeepLink.workout(id).url), .workout(id))
        XCTAssertEqual(WorkoutDeepLink(url: WorkoutDeepLink.workout(nil).url), .workout(nil))
        XCTAssertEqual(WorkoutDeepLink(url: WorkoutDeepLink.calendar.url), .calendar)
        XCTAssertEqual(WorkoutDeepLink(url: WorkoutDeepLink.overview.url), .overview)
        for value in ["https://workout", "trainlog://workout/invalid", "trainlog://calendar/extra", "trainlog://workout?delete=true", "trainlog://delete", "trainlog://workout:123"] {
            XCTAssertNil(WorkoutDeepLink(url: URL(string: value)!))
        }
    }
    func testLiveStateCountsOnlyValidWorkingSetsAndPauseFreezesClock() {
        let now = date("2026-10-15T12:00:00Z")
        var session = Session(mode: .detailed, date: now.addingTimeInterval(-120))
        let exercise = ExerciseCatalog.exercises.first { $0.tracking == .weightReps }!
        session.exercises = [ExerciseEntry(exercise: exercise, sets: [
            TrainingSet(weightKg: 20, reps: 8, isCompleted: true),
            TrainingSet(weightKg: 20, reps: 8, kind: .warmup, isCompleted: true),
            TrainingSet(weightKg: 20, reps: 8, isCompleted: false)
        ])]
        let running = WorkoutLiveState(session: session, restDeadline: nil, now: now)
        XCTAssertEqual(running.workingSets, 1); XCTAssertEqual(running.phase, .training)
        XCTAssertEqual(running.timerOrigin, session.timerStartedAt)
        session.pause(at: now)
        let paused = WorkoutLiveState(session: session, restDeadline: nil, now: now.addingTimeInterval(60))
        XCTAssertEqual(paused.phase, .paused); XCTAssertEqual(paused.elapsedSeconds, 120)
        XCTAssertNil(paused.timerOrigin)
    }
    func testRestExpiryAndFinishNeverRestartCountdown() throws {
        let now = date("2026-10-15T12:00:00Z")
        var session = Session(mode: .detailed, date: now)
        let end = now.addingTimeInterval(90)
        let resting = WorkoutLiveState(session: session, restDeadline: end, now: now)
        XCTAssertEqual(resting.phase, .resting); XCTAssertEqual(resting.staleDate, end)
        XCTAssertEqual(resting.label(stale: true), "休息结束")
        XCTAssertNil(WorkoutLiveState(session: session, restDeadline: end, now: end).restDeadline)
        session.finish(at: end)
        let finished = WorkoutLiveState(session: session, restDeadline: end.addingTimeInterval(60), now: end)
        XCTAssertEqual(finished.phase, .finished); XCTAssertNil(finished.timerOrigin); XCTAssertNil(finished.restDeadline)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutLiveState.self, from: JSONEncoder().encode(resting)), resting)
    }
    func testWidgetRebuildRemovesDeletedHistoryAndExcludesPrivateFields() throws {
        var session = Session(mode: .quick)
        session.notes = "private note"; session.finish()
        let before = WorkoutWidgetSnapshot(sessions: [session], weeklyGoal: 4)
        let data = try JSONEncoder().encode(before)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private note"))
        XCTAssertEqual(try JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data), before)
        let after = WorkoutWidgetSnapshot(sessions: [], weeklyGoal: 4)
        XCTAssertTrue(after.records.isEmpty); XCTAssertNil(after.draftID)
    }
}
