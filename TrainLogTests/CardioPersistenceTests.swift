import XCTest
import SwiftData
import HealthKit
import TrainLogCore
@testable import TrainLog

@MainActor final class CardioPersistenceTests: XCTestCase {
    private func workout(watch: Bool = false) -> Session {
        let date = Date().addingTimeInterval(-1800)
        var value = Session(mode: .cardio, date: date)
        value.activity = ActivityRecord(kind: .outdoorCycle); value.activity?.distanceMeters = 10_000
        value.manualDurationSeconds = 1800; value.finish()
        if watch { value.activity?.source = "appleWatch"; value.activity?.watchWorkoutID = UUID(); value.activity?.averageHeartRate = 135; value.activity?.maximumHeartRate = 165 }
        return value
    }
    func testLegacyDatabaseMigratesAndCatalogUpgradePreservesUserChoices() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "legacy.store")
        let sessionID = try createLegacyStore(at: url)
        let store = try AppStore(storeURL: url)
        XCTAssertEqual(store.sessions.first?.id, sessionID)
        XCTAssertEqual(store.sessions.first?.quickEntries.first?.muscle, .chest)
        XCTAssertNil(store.sessions.first?.activity)
        XCTAssertEqual(store.exercises.count, 128)
        let edited = try XCTUnwrap(store.exercises.first { $0.id == ExerciseCatalog.id(1) })
        XCTAssertTrue(edited.isFavorite); XCTAssertTrue(edited.isArchived); XCTAssertEqual(edited.name, "保留我的名称")
        try store.installMissingExercises(); XCTAssertEqual(store.exercises.count, 128)
    }
    private func createLegacyStore(at url: URL) throws -> UUID {
        let schema = Schema(versionedSchema: TrainLogSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [AppStore.configuration(schema: schema, storeURL: url)])
        let context = container.mainContext
        var session = Session(mode: .quick, date: Date().addingTimeInterval(-100))
        session.quickEntries = [QuickEntry(muscle: .chest)]; session.finish()
        let model = WorkoutSession(session); context.insert(model); try model.apply(session, context: context)
        var exercise = ExerciseCatalog.exercises[0]; exercise.name = "保留我的名称"; exercise.isFavorite = true; exercise.isArchived = true
        context.insert(try ExerciseDefinition(exercise)); context.insert(try UserSettings(Settings())); try context.save()
        return session.id
    }
    func testCardioDiskRoundTripEditDeleteAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "cardio.store")
        var value = workout()
        do { let store = try AppStore(storeURL: url); try store.save(value) }
        let store = try AppStore(storeURL: url)
        XCTAssertEqual(store.completed.first?.activity, value.activity)
        value.activity?.distanceMeters = 12_000; try store.save(value)
        XCTAssertEqual(try BackupService.decode(BackupService.encode(store.backup)).sessions.first?.activity?.distanceMeters, 12_000)
        try store.deleteSession(value.id)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<SessionActivityData>()), 0)
    }
    func testOfflineWatchDeliveryIsIdempotentAndCannotResurrectDeletedWorkout() throws {
        let store = try AppStore(inMemory: true)
        let value = workout(watch: true)
        try store.receiveWatchSession(value); try store.receiveWatchSession(value)
        XCTAssertEqual(store.completed.count, 1)
        XCTAssertEqual(store.completed.first?.activity?.averageHeartRate, 135)
        try store.deleteSession(value.id); try store.receiveWatchSession(value)
        XCTAssertTrue(store.completed.isEmpty)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<WatchImportReceipt>()), 1)
    }
    func testAllActivityMappingsAreSpecificAndPreserveIndoorOutdoorChoice() {
        for kind in CardioActivity.allCases {
            XCTAssertNotEqual(kind.healthKitType, .other)
            XCTAssertEqual(CardioActivity.matching(kind.workoutConfiguration), kind)
        }
    }
}
