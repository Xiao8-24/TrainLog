import XCTest
import SwiftData
import TrainLogCore
@testable import TrainLog

@MainActor final class LiveTrainingPersistenceTests: XCTestCase {
    private func plan() -> TrainingPlan {
        TrainingPlan(name: "明天力量训练", scheduledAt: Date().addingTimeInterval(86400), items: [TemplateItem(exerciseID: ExerciseCatalog.exercises[0].id, setCount: 2, weightKg: 60, reps: 8)])
    }
    func testPlanDoesNotCountAndStartingTwiceResumesSameSession() throws {
        let store = try AppStore(inMemory: true), plan = plan()
        try store.savePlan(plan)
        XCTAssertNil(store.draft); XCTAssertTrue(store.completed.isEmpty)
        let value = try store.startPlan(plan.id)
        XCTAssertEqual(value.plan?.id, plan.id); XCTAssertNotNil(value.timerStartedAt)
        XCTAssertEqual(try store.startPlan(plan.id).id, value.id)
        let other = plan.copied(to: Date()); try store.savePlan(other)
        XCTAssertThrowsError(try store.startPlan(other.id))
        XCTAssertEqual(store.draft?.id, value.id); XCTAssertEqual(store.sessions.count, 1)
    }
    func testPausedGroupAndPlanSurviveColdReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "live.store"), plan = plan(), base = Date().addingTimeInterval(-100)
        var sessionID: UUID?
        do {
            let store = try AppStore(storeURL: url); try store.savePlan(plan)
            var value = try store.startPlan(plan.id, at: base); sessionID = value.id
            try value.startSet(entryID: value.exercises[0].id, setID: value.exercises[0].sets[0].id, at: base.addingTimeInterval(1))
            value.pause(at: base.addingTimeInterval(11)); value.exercises[0].sets[0].weightKg = 65; try store.save(value)
        }
        do {
            let store = try AppStore(storeURL: url), value = try XCTUnwrap(store.draft)
            XCTAssertEqual(store.plans.first?.id, plan.id); XCTAssertEqual(value.id, sessionID)
            XCTAssertEqual(value.plan?.name, plan.name)
            XCTAssertEqual(value.plan?.targets?[0].sets[0].weightKg, 60)
            XCTAssertEqual(value.exercises[0].sets[0].weightKg, 65)
            XCTAssertEqual(value.exercises[0].sets[0].timing?.elapsed(), 10)
            XCTAssertNil(value.exercises[0].sets[0].timing?.timerStartedAt)
        }
    }
    func testV3MigrationPreservesOriginalStrengthRecord() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "legacy.store")
        var original = Session(mode: .detailed)
        original.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 55, reps: 9)])]
        original.notes = "原来的组数据"
        do {
            let schema = Schema(versionedSchema: TrainLogSchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: [AppStore.configuration(schema: schema, storeURL: url)])
            let row = WorkoutSession(original); container.mainContext.insert(row); try row.apply(original, context: container.mainContext)
            container.mainContext.insert(try UserSettings(Settings())); try container.mainContext.save()
        }
        do {
            let store = try AppStore(storeURL: url)
            XCTAssertEqual(store.draft?.id, original.id); XCTAssertEqual(store.draft?.exercises, original.exercises)
            XCTAssertEqual(store.draft?.notes, original.notes); XCTAssertTrue(store.plans.isEmpty)
            XCTAssertNil(store.draft?.exercises[0].sets[0].timing)
        }
    }
    func testBackupReplaceRestoresPlanAndMeasuredGroupTime() throws {
        let source = try AppStore(inMemory: true), plan = plan(), base = Date().addingTimeInterval(-100)
        try source.savePlan(plan)
        var value = try source.startPlan(plan.id, at: base)
        let entry = value.exercises[0].id, set = value.exercises[0].sets[0].id
        try value.startSet(entryID: entry, setID: set, at: base)
        value.exercises[0].sets[0].weightKg = 65
        var preferences = source.settings; preferences.targetSuggestionsEnabled = false; try source.updateSettings(preferences)
        try value.completeSet(entryID: entry, setID: set, at: base.addingTimeInterval(20))
        value.finish(at: base.addingTimeInterval(50)); try source.save(value)
        let target = try AppStore(inMemory: true)
        _ = try target.importBackup(BackupService.decode(BackupService.encode(source.backup)), mode: .replace)
        XCTAssertEqual(target.plans.first?.id, plan.id)
        XCTAssertEqual(target.completed.first?.plan?.id, plan.id)
        XCTAssertEqual(target.completed.first?.plan?.targets?[0].sets[0].weightKg, 60)
        XCTAssertEqual(target.completed.first?.exercises[0].sets[0].weightKg, 65)
        XCTAssertFalse(target.settings.showsTargetSuggestions)
        XCTAssertEqual(target.completed.first?.exercises[0].sets[0].timing?.elapsed(), 20)
    }
    func testDeletingWorkoutRemovesTimingButKeepsPlan() throws {
        let store = try AppStore(inMemory: true), plan = plan()
        try store.savePlan(plan); var value = try store.startPlan(plan.id)
        try value.startSet(entryID: value.exercises[0].id, setID: value.exercises[0].sets[0].id)
        try store.save(value)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionTrainingData>()), 1)
        try store.deleteSession(value.id)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionTrainingData>()), 0)
        XCTAssertEqual(store.plans.count, 1)
    }
}
