import XCTest
import SwiftData
import TrainLogCore
@testable import TrainLog

@MainActor final class LinkedWatchPersistenceTests: XCTestCase {
    private func phone() -> Session {
        var value = Session(mode: .detailed, date: Date().addingTimeInterval(-1800))
        value.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8, isCompleted: true)])]
        value.notes = "手机组数与备注"; value.manualDurationSeconds = 1800
        return value
    }
    private func watch(_ request: WatchTrainingRequest) -> Session {
        var value = Session(mode: .cardio, date: Date().addingTimeInterval(-600))
        value.activity = ActivityRecord(kind: .traditionalStrength); value.activity?.source = "appleWatch"
        value.activity?.watchWorkoutID = UUID(); value.activity?.averageHeartRate = 120; value.activity?.maximumHeartRate = 145
        value.activity?.activeEnergyKcal = 90; value.phoneLink = request.reference; value.finish()
        return value
    }
    func testLinkedResultAndStaleAutosaveKeepExactlyOneStrengthRecord() throws {
        let store = try AppStore(inMemory: true)
        let original = phone(); try store.save(original)
        let request = try store.prepareWatchLink(sessionID: original.id)
        var staleEditor = try XCTUnwrap(store.draft)
        let result = watch(request)
        try store.receiveWatchSession(result); try store.receiveWatchSession(result)
        XCTAssertEqual(store.sessions.count, 1); XCTAssertTrue(store.completed.isEmpty)
        XCTAssertEqual(store.draft?.exercises, original.exercises)
        staleEditor.notes = "晚到的最新输入"; try store.save(staleEditor)
        XCTAssertEqual(store.draft?.watchLink?.summary?.activity.averageHeartRate, 120)
        XCTAssertEqual(store.draft?.notes, staleEditor.notes)
        staleEditor.finish(); try store.save(staleEditor)
        XCTAssertEqual(store.completed.count, 1); XCTAssertNil(store.draft)
        XCTAssertEqual(store.completed.first?.mode, .detailed)
        XCTAssertEqual(WorkoutStatisticsService.totals(store.completed).volumeKg, 480)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionWatchData>()), 1)
        XCTAssertThrowsError(try HealthWorkoutExport(session: XCTUnwrap(store.completed.first)))
    }
    func testDeletedLinkedPhoneRecordDoesNotReappearFromLateWatchFile() throws {
        let store = try AppStore(inMemory: true)
        let original = phone(); try store.save(original)
        let request = try store.prepareWatchLink(sessionID: original.id)
        let result = watch(request)
        try store.deleteSession(original.id)
        try store.receiveWatchSession(result); try store.receiveWatchSession(result)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<WatchImportReceipt>()), 2)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionWatchData>()), 0)
    }
    func testUnknownLinkDoesNotCreateAnUnrelatedSecondRecord() throws {
        let store = try AppStore(inMemory: true)
        let request = WatchTrainingRequest(phoneSessionID: UUID(), title: "尚未恢复的手机训练")
        XCTAssertThrowsError(try store.receiveWatchSession(watch(request)))
        XCTAssertTrue(store.sessions.isEmpty)
    }
    func testDelayedOldStatusCannotOverwriteNewRequestOrFinishedSummary() throws {
        let store = try AppStore(inMemory: true)
        let original = phone(); try store.save(original)
        let old = try store.prepareWatchLink(sessionID: original.id)
        try store.applyWatchLinkUpdate(WatchLinkUpdate(reference: old.reference, state: .cancelled))
        let new = try store.prepareWatchLink(sessionID: original.id)
        XCTAssertNotEqual(old.reference, new.reference)
        try store.applyWatchLinkUpdate(WatchLinkUpdate(reference: old.reference, state: .cancelled))
        XCTAssertEqual(store.draft?.watchLink?.reference, new.reference)
        try store.receiveWatchSession(watch(new))
        try store.applyWatchLinkUpdate(WatchLinkUpdate(reference: new.reference, state: .prepared))
        XCTAssertEqual(store.draft?.watchLink?.state, .finished)
    }
    func testV2DatabaseMigratesAndLinkedSummarySurvivesColdReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "v2.store")
        let original = phone()
        do {
            let schema = Schema(versionedSchema: TrainLogSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [AppStore.configuration(schema: schema, storeURL: url)])
            let model = WorkoutSession(original); container.mainContext.insert(model)
            try model.apply(original, context: container.mainContext)
            container.mainContext.insert(try UserSettings(Settings())); try container.mainContext.save()
        }
        var nativeID: UUID?
        do {
            let store = try AppStore(storeURL: url)
            XCTAssertEqual(store.draft?.id, original.id); XCTAssertNil(store.draft?.watchLink)
            let request = try store.prepareWatchLink(sessionID: original.id)
            let result = watch(request); nativeID = result.activity?.watchWorkoutID
            try store.receiveWatchSession(result)
        }
        do {
            let reopened = try AppStore(storeURL: url)
            XCTAssertEqual(reopened.draft?.watchLink?.summary?.activity.watchWorkoutID, nativeID)
            XCTAssertEqual(reopened.draft?.exercises, original.exercises)
        }
    }
    func testPendingWatchOwnershipPreventsPhoneHealthCopyUntilConfirmedCancel() async throws {
        let client = HealthSyncTests.Client(), disk = HealthSyncTests.Disk()
        let health = HealthSyncCoordinator(client: client, persistence: disk)
        var value = phone()
        value.watchLink = WatchTrainingLink(request: WatchTrainingRequest(phoneSessionID: value.id, title: "关联训练"))
        value.finish(); await health.enable(sessions: [])
        health.track(value); health.export(value); await health.waitUntilIdle()
        XCTAssertTrue(client.writes.isEmpty)
        let link = try XCTUnwrap(value.watchLink)
        value.watchLink = try link.applying(WatchLinkUpdate(reference: link.reference, state: .cancelled))
        health.track(value); await health.waitUntilIdle()
        XCTAssertEqual(client.writes.count, 1)
    }
}
