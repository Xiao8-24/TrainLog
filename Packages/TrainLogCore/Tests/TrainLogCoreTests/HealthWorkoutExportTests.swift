import XCTest
@testable import TrainLogCore

final class HealthWorkoutExportTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func workout(mode: WorkoutMode = .detailed) -> Session {
        var session = Session(mode: mode, date: now.addingTimeInterval(-3_600))
        session.accumulatedSeconds = 1_800; session.timerStartedAt = nil
        session.status = .completed; session.endTime = now; session.updatedAt = now
        return session
    }
    func testPausedWorkoutKeepsWallClockSpanAndActiveDuration() throws {
        let payload = try HealthWorkoutExport(session: workout(), now: now)
        XCTAssertEqual(payload.start, now.addingTimeInterval(-3_600))
        XCTAssertEqual(payload.end, now)
        XCTAssertEqual(payload.duration, 1_800)
    }
    func testQuickManualRecordEndsAtSavedCompletionWithoutFutureTime() throws {
        var session = workout(mode: .quick)
        session.date = now; session.manualDurationSeconds = 1_200
        let payload = try HealthWorkoutExport(session: session, now: now)
        XCTAssertEqual(payload.start, now.addingTimeInterval(-1_200))
        XCTAssertEqual(payload.end, now)
        XCTAssertEqual(payload, try HealthWorkoutExport(session: session, now: now.addingTimeInterval(10_000)))
    }
    func testBackfilledDateDoesNotUseTodayAsTrainingEnd() throws {
        var session = workout(mode: .quick)
        session.date = now.addingTimeInterval(-864_000); session.manualDurationSeconds = 1_200
        let payload = try HealthWorkoutExport(session: session, now: now)
        XCTAssertEqual(payload.start, session.date)
        XCTAssertEqual(payload.end, session.date.addingTimeInterval(1_200))
    }
    func testDraftZeroNegativeAndNonFiniteDurationAreRejected() {
        var session = workout(); session.status = .draft
        XCTAssertThrowsError(try HealthWorkoutExport(session: session, now: now))
        session.status = .completed
        for value in [0.0, -1, .infinity, .nan] {
            session.accumulatedSeconds = value
            XCTAssertThrowsError(try HealthWorkoutExport(session: session, now: now))
        }
    }
    func testFutureAndOverlongWallSpanAreRejected() {
        var session = workout(); session.date = now.addingTimeInterval(1)
        XCTAssertThrowsError(try HealthWorkoutExport(session: session, now: now))
        session.date = now.addingTimeInterval(-1_000_000); session.startTime = session.date
        XCTAssertThrowsError(try HealthWorkoutExport(session: session, now: now))
    }
    func testStablePayloadDoesNotSendNotesWeightsOrSetInformation() throws {
        var session = workout(); let payload = try HealthWorkoutExport(session: session, now: now)
        session.notes = "private note"; session.sessionRPE = 8; session.updatedAt = now.addingTimeInterval(10)
        XCTAssertEqual(payload, try HealthWorkoutExport(session: session, now: now.addingTimeInterval(10)))
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(payload), as: UTF8.self).contains("private note"))
    }
    func testLedgerRetriesKeepIdentityAndVersionAcrossSerialization() throws {
        let payload = try HealthWorkoutExport(session: workout(), now: now)
        var ledger = HealthSyncLedger(); ledger.stage(payload, now: now)
        let version = try XCTUnwrap(ledger.pending.first?.version)
        var restored = try JSONDecoder().decode(HealthSyncLedger.self, from: JSONEncoder().encode(ledger))
        restored.stage(payload, now: now.addingTimeInterval(100))
        XCTAssertEqual(restored.pending.first?.version, version)
        XCTAssertEqual(restored.pending.first?.syncIdentifier, payload.syncIdentifier)
    }
    func testLateAcknowledgementCannotEraseEditOrDeletion() throws {
        var payload = try HealthWorkoutExport(session: workout(), now: now)
        var ledger = HealthSyncLedger(); ledger.stage(payload, now: now)
        let version = try XCTUnwrap(ledger.pending.first?.version)
        payload.duration += 1; ledger.stage(payload, now: now)
        XCTAssertGreaterThan(try XCTUnwrap(ledger.pending.first?.version), version)
        ledger.acknowledge(payload.sessionID, version: version)
        XCTAssertEqual(ledger.pending.count, 1)
        let editedVersion = try XCTUnwrap(ledger.pending.first?.version)
        ledger.remove(payload.sessionID)
        ledger.acknowledge(payload.sessionID, version: editedVersion)
        XCTAssertNil(ledger.pending.first?.workout)
        let deletionVersion = try XCTUnwrap(ledger.pending.first?.version)
        ledger.acknowledge(payload.sessionID, version: deletionVersion)
        XCTAssertTrue(ledger.records.isEmpty)
    }
}
