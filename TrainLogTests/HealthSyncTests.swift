import XCTest
import TrainLogCore
@testable import TrainLog

@MainActor final class HealthSyncTests: XCTestCase {
    final class Client: WorkoutHealthClient {
        var authorization = WorkoutHealthAuthorization.authorized
        var fails = false
        var writes: [(HealthWorkoutExport, Int)] = []
        var deletes: [String] = []
        var onSave: (() async -> Void)?
        func requestAuthorization() async throws {}
        func save(_ workout: HealthWorkoutExport, version: Int) async throws {
            writes.append((workout, version)); await onSave?()
            if fails { throw ValidationError("Health store locked") }
        }
        func delete(syncIdentifier: String) async throws { deletes.append(syncIdentifier) }
    }
    final class Disk: HealthSyncPersistence {
        var ledger = HealthSyncLedger()
        var fails = false
        var failAfterNextSave = false
        func load() throws -> HealthSyncLedger { ledger }
        func save(_ ledger: HealthSyncLedger) throws {
            if fails { throw ValidationError("Disk unavailable") }
            self.ledger = ledger
            if failAfterNextSave { fails = true; failAfterNextSave = false }
        }
    }
    private func session() -> Session {
        var session = Session(mode: .quick, date: Date().addingTimeInterval(-3_600))
        session.manualDurationSeconds = 1_200
        session.quickEntries = [QuickEntry(muscle: .chest)]
        session.finish(); return session
    }
    func testConnectionDoesNotUploadExistingHistoryAndDenialDoesNotEnable() async {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        sync.refresh(sessions: [session]); sync.track(session)
        XCTAssertTrue(client.writes.isEmpty)
        client.authorization = .denied
        await sync.enable(sessions: [session])
        XCTAssertFalse(sync.enabled)
        client.authorization = .authorized
        await sync.enable(sessions: [session]); await sync.waitUntilIdle()
        XCTAssertTrue(client.writes.isEmpty)
        sync.export(session); await sync.waitUntilIdle()
        XCTAssertTrue(sync.isExported(session.id))
    }
    func testFailedWriteRetriesSameRevisionWithoutLosingLocalStatus() async {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session]); client.fails = true
        sync.track(session); await sync.waitUntilIdle()
        XCTAssertEqual(sync.pendingCount, 1); XCTAssertNotNil(sync.issue)
        client.fails = false; sync.retry(sessions: [session]); await sync.waitUntilIdle()
        XCTAssertEqual(client.writes.count, 2)
        XCTAssertEqual(client.writes.first?.1, client.writes.last?.1)
        XCTAssertTrue(sync.isExported(session.id))
    }
    func testDiskFailureBeforeSubmissionDoesNotWriteHealthData() async {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session]); disk.fails = true
        sync.track(session); await sync.waitUntilIdle()
        XCTAssertTrue(client.writes.isEmpty); XCTAssertNotNil(sync.issue)
        XCTAssertEqual(sync.pendingCount, 1)
        disk.fails = false; sync.retry(sessions: [session]); await sync.waitUntilIdle()
        XCTAssertTrue(sync.isExported(session.id))
    }
    func testDiskFailureAfterHealthSaveCanRecoverSameRevisionAfterRestart() async {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session]); disk.failAfterNextSave = true
        sync.track(session); await sync.waitUntilIdle()
        XCTAssertEqual(sync.pendingCount, 1)
        let version = client.writes.first?.1
        disk.fails = false
        let restored = HealthSyncCoordinator(client: client, persistence: disk)
        await restored.enable(sessions: [session]); await restored.waitUntilIdle()
        XCTAssertEqual(client.writes.last?.1, version)
        XCTAssertTrue(restored.isExported(session.id))
    }
    func testDeletionWhileWriteIsInFlightWins() async throws {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session])
        let started = expectation(description: "Health write started")
        var resume: CheckedContinuation<Void, Never>?
        client.onSave = { started.fulfill(); await withCheckedContinuation { resume = $0 } }
        sync.track(session)
        await fulfillment(of: [started], timeout: 2)
        sync.remove(session.id)
        let continuation = try XCTUnwrap(resume); continuation.resume()
        await sync.waitUntilIdle()
        XCTAssertEqual(client.deletes, ["com.trainlog.workout.\(session.id.uuidString)"])
        XCTAssertEqual(sync.pendingCount, 0); XCTAssertEqual(sync.exportedCount, 0)
    }
    func testDisconnectedEditsAreReconciledBeforeResumingWrites() async {
        let client = Client(), disk = Disk(); var session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session]); sync.track(session); await sync.waitUntilIdle()
        sync.disable(); session.manualDurationSeconds = 1_800
        sync.track(session); XCTAssertEqual(client.writes.count, 1)
        await sync.enable(sessions: [session]); await sync.waitUntilIdle()
        XCTAssertEqual(client.writes.last?.0.duration, 1_800)
        XCTAssertEqual(client.writes.count, 2)
    }
    func testReplacingLocalDataOnlyDeletesManagedHealthRecords() async {
        let client = Client(), disk = Disk(), session = session()
        let sync = HealthSyncCoordinator(client: client, persistence: disk)
        await sync.enable(sessions: [session]); sync.track(session); await sync.waitUntilIdle()
        sync.refresh(sessions: []); await sync.waitUntilIdle()
        XCTAssertEqual(client.deletes.count, 1)
        XCTAssertEqual(sync.exportedCount, 0)
    }
}
