import XCTest
@testable import TrainLogCore

final class WatchLinkTests: XCTestCase {
    func testDiscardedRecoveryDoesNotReleaseHealthOwnershipAfterStatusWriteFailure() throws {
        let request = WatchTrainingRequest(phoneSessionID: UUID(), title: "已开始但状态未落盘")
        let prepared = WatchLinkUpdate(reference: request.reference, state: .prepared)
        let discarded = WatchLinkUpdate.discardingRecovery(reference: request.reference, previous: prepared)
        var phone = WatchTrainingLink(request: request)
        phone = try phone.applying(discarded)
        phone = try phone.applying(WatchLinkUpdate(reference: request.reference, state: .cancelled))
        XCTAssertEqual(phone.state, .recording)
        XCTAssertTrue(phone.ownsHealthRecord)
        let finished = WatchLinkUpdate(reference: request.reference, state: .finished)
        XCTAssertEqual(WatchLinkUpdate.discardingRecovery(reference: request.reference, previous: finished), finished)
        XCTAssertEqual(WatchLinkUpdate.discardingRecovery(reference: request.reference, previous: nil).state, .recording)
    }
    private func pair() -> (Session, Session) {
        let now = Date()
        var phone = Session(mode: .detailed, date: now.addingTimeInterval(-1800))
        phone.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8, isCompleted: true)])]
        phone.notes = "保留逐组记录"; phone.manualDurationSeconds = 1800
        phone.watchLink = WatchTrainingLink(request: WatchTrainingRequest(phoneSessionID: phone.id, title: "手机力量训练"))
        var watch = Session(mode: .cardio, date: now.addingTimeInterval(-600))
        watch.activity = ActivityRecord(kind: .traditionalStrength)
        watch.activity?.source = "appleWatch"; watch.activity?.watchWorkoutID = UUID()
        watch.activity?.averageHeartRate = 110; watch.activity?.maximumHeartRate = 130; watch.activity?.activeEnergyKcal = 80
        watch.activity?.heartRate = [HeartRatePoint(date: now.addingTimeInterval(-300), bpm: 115)]
        watch.phoneLink = phone.watchLink?.reference; watch.finish(at: now.addingTimeInterval(-1))
        return (phone, watch)
    }
    func testExplicitMergePreservesPhoneSetsNotesClockAndStatus() throws {
        let (phone, watch) = pair()
        let merged = try WatchTrainingLink.merging(watch, into: phone)
        XCTAssertEqual(merged.id, phone.id); XCTAssertEqual(merged.status, .draft)
        XCTAssertEqual(merged.exercises, phone.exercises); XCTAssertEqual(merged.notes, phone.notes)
        XCTAssertEqual(merged.manualDurationSeconds, 1800); XCTAssertNil(merged.activity)
        XCTAssertEqual(merged.watchLink?.summary?.activity.averageHeartRate, 110)
        XCTAssertEqual(merged.watchLink?.summary?.startedAt, watch.startTime)
        XCTAssertEqual(merged.watchLink?.state, .finished)
        XCTAssertEqual(try WatchTrainingLink.merging(watch, into: merged), merged)
    }
    func testUnmatchedRequestsAndCancelledLinksCannotBeGuessedIntoAnotherWorkout() throws {
        var (phone, watch) = pair()
        watch.phoneLink?.requestID = UUID()
        XCTAssertThrowsError(try WatchTrainingLink.merging(watch, into: phone))
        watch.phoneLink = phone.watchLink?.reference; phone.watchLink?.state = .cancelled
        XCTAssertThrowsError(try WatchTrainingLink.merging(watch, into: phone))
    }
    func testLinkUpdatesCannotRegressRecordingOrUndoFinishedMetrics() throws {
        let (phone, watch) = pair()
        let original = try XCTUnwrap(phone.watchLink)
        let recording = try original.applying(WatchLinkUpdate(reference: original.reference, state: .recording))
        XCTAssertEqual(try recording.applying(WatchLinkUpdate(reference: original.reference, state: .prepared)), recording)
        XCTAssertEqual(try recording.applying(WatchLinkUpdate(reference: original.reference, state: .cancelled)), recording)
        let finished = try XCTUnwrap(WatchTrainingLink.merging(watch, into: phone).watchLink)
        XCTAssertEqual(try finished.applying(WatchLinkUpdate(reference: finished.reference, state: .recording)), finished)
    }
    func testHealthOwnershipReservedBeforeMetricsArriveAndReleasedOnlyBeforeStart() throws {
        var (phone, _) = pair()
        phone.finish()
        XCTAssertThrowsError(try HealthWorkoutExport(session: phone))
        let link = try XCTUnwrap(phone.watchLink)
        phone.watchLink = try link.applying(WatchLinkUpdate(reference: link.reference, state: .cancelled))
        XCTAssertFalse(phone.watchManagesHealthRecord)
        XCTAssertNoThrow(try HealthWorkoutExport(session: phone))
    }
    func testEnvelopeVersionsAndBackupRoundTripPreserveAttachment() throws {
        let (phone, watch) = pair()
        let envelope = WatchWorkoutEnvelope(session: watch)
        XCTAssertEqual(envelope.version, 2)
        XCTAssertEqual(try WatchWorkoutEnvelope.decode(JSONEncoder().encode(envelope)).session.phoneLink, watch.phoneLink)
        let merged = try WatchTrainingLink.merging(watch, into: phone)
        let backup = Backup(sessions: [merged], exercises: [], templates: [], bodyWeights: [], settings: Settings())
        // Use the original catalog because snapshots still reference stable exercise IDs.
        var complete = backup; complete.exercises = ExerciseCatalog.exercises
        let restored = try XCTUnwrap(BackupService.decode(BackupService.encode(complete)).sessions[0].watchLink)
        XCTAssertEqual(restored.reference, merged.watchLink?.reference)
        XCTAssertEqual(restored.summary?.activity.averageHeartRate, 110)
        XCTAssertEqual(restored.summary?.activity.watchWorkoutID, watch.activity?.watchWorkoutID)
        XCTAssertEqual(try XCTUnwrap(restored.summary).startedAt.timeIntervalSince1970, watch.startTime.timeIntervalSince1970, accuracy: 1)
    }
    func testSummaryRejectsFabricatedSourceAndImpossibleDuration() throws {
        let (_, watch) = pair()
        var summary = try WatchTrainingSummary(workout: watch)
        summary.activity.source = "manual"
        XCTAssertThrowsError(try summary.validate())
        summary = try WatchTrainingSummary(workout: watch); summary.duration = 100_000
        XCTAssertThrowsError(try summary.validate())
    }
    func testLinkedCSVKeepsStrengthColumnsAndAppendsWatchSummary() throws {
        let (phone, watch) = pair()
        let linked = try WatchTrainingLink.merging(watch, into: phone)
        let rows = BackupService.csv([linked]).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].components(separatedBy: ",").count, 46)
        XCTAssertEqual(rows[1].components(separatedBy: ",").count, 46)
        XCTAssertTrue(rows[1].contains("\"60.0\"")); XCTAssertTrue(rows[1].contains("\"110.0\""))
        XCTAssertTrue(rows[1].contains(try XCTUnwrap(watch.activity?.watchWorkoutID).uuidString))
        XCTAssertTrue(rows[0].contains("linked_watch_started_at"))
    }
}
