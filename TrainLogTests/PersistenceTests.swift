import XCTest
import SwiftData
import TrainLogCore
@testable import TrainLog

@MainActor final class PersistenceTests: XCTestCase {
    func testDiskRoundTripIncludesDraftSettingsAndCompletedSets() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "test.store")
        let draftID: UUID
        let completedID: UUID
        do {
            let store = try AppStore(storeURL: url)
            var completed = Session(mode: .detailed)
            completed.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8, rpe: 8, isCompleted: true)])]
            completed.finish(); try store.save(completed); completedID = completed.id
            var draft = Session(mode: .quick); draft.quickEntries = [QuickEntry(muscle: .quadriceps, intensity: .hard)]
            try store.save(draft); draftID = draft.id
            var settings = store.settings; settings.unit = .lb; settings.weeklyGoal = 5; try store.updateSettings(settings)
            try store.saveWeight(BodyWeight(weightKg: 70))
        }
        let reopened = try AppStore(storeURL: url)
        XCTAssertEqual(reopened.draft?.id, draftID)
        XCTAssertEqual(reopened.completed.first?.id, completedID)
        XCTAssertEqual(WorkoutStatisticsService.totals(reopened.sessions).volumeKg, 480)
        XCTAssertEqual(reopened.settings.unit, .lb); XCTAssertEqual(reopened.settings.weeklyGoal, 5)
        XCTAssertEqual(reopened.bodyWeights.count, 1)
    }
    func testCascadeDeletionAndHistoryEdit() throws {
        let store = try AppStore(inMemory: true)
        var session = Session(mode: .detailed)
        session.exercises = [ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8, rpe: 8, isCompleted: true)])]
        session.finish(); try store.save(session)
        session.exercises[0].sets[0].weightKg = 70; try store.save(session)
        XCTAssertEqual(store.completed[0].exercises[0].sets[0].weightKg, 70)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<WorkoutSet>()), 1)
        try store.deleteSession(session.id)
        XCTAssertTrue(store.completed.isEmpty)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionExercise>()), 0)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<WorkoutSet>()), 0)
    }
    func testInvalidSaveDoesNotOverwriteValidSession() throws {
        let store = try AppStore(inMemory: true)
        var session = Session(mode: .quick); session.quickEntries = [QuickEntry(muscle: .chest)]; session.finish(); try store.save(session)
        session.quickEntries = []
        XCTAssertThrowsError(try store.save(session))
        XCTAssertEqual(store.completed.first?.quickEntries.count, 1)
    }
    func testSnapshotsRemainStableAfterCatalogEdit() throws {
        let store = try AppStore(inMemory: true)
        var session = Session(mode: .detailed)
        var exercise = Exercise(name: "自定义推", primary: [.chest], isCustom: true)
        try store.saveExercise(exercise)
        session.exercises = [ExerciseEntry(exercise: exercise, sets: [TrainingSet(weightKg: 30, reps: 8, isCompleted: true)])]
        session.finish(); try store.save(session)
        exercise.primary = [.quadriceps]; try store.saveExercise(exercise)
        XCTAssertEqual(store.completed[0].exercises[0].exercise.primary, [.chest])
    }
    func testImportIsIdempotentAndInvalidImportKeepsCurrentData() throws {
        let store = try AppStore(inMemory: true)
        var session = Session(mode: .quick); session.quickEntries = [QuickEntry(muscle: .chest)]; session.finish(); try store.save(session)
        let backup = store.backup
        let recovery = try store.importBackup(backup, mode: .merge)
        defer { try? FileManager.default.removeItem(at: recovery) }
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(try BackupService.decode(Data(contentsOf: recovery)).sessions.count, 1)
        var invalid = backup; invalid.sessions.append(session)
        XCTAssertThrowsError(try store.importBackup(invalid, mode: .replace))
        XCTAssertEqual(store.sessions.count, 1)
        var replacement = backup; replacement.sessions = []
        let recovery2 = try store.importBackup(replacement, mode: .replace)
        defer { try? FileManager.default.removeItem(at: recovery2) }
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<QuickMuscleEntry>()), 0)
    }
    func testVectorRegionsHaveUniqueIDsAndCorrectChestHit() {
        let regions = MuscleVectorData.front + MuscleVectorData.back
        XCTAssertEqual(Set(regions.map(\.id)).count, regions.count)
        XCTAssertTrue(regions.allSatisfy { $0.vectorPath.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) } })
        XCTAssertEqual(MuscleRegionInteraction.hit(at: CGPoint(x: 82, y: 102), size: CGSize(width: 200, height: 440), view: .front), .chest)
        XCTAssertEqual(MuscleRegionInteraction.hit(at: CGPoint(x: 164, y: 204), size: CGSize(width: 400, height: 880), view: .front), .chest)
        XCTAssertNil(MuscleRegionInteraction.hit(at: CGPoint(x: 0, y: 0), size: CGSize(width: 200, height: 440), view: .front))
    }
}

