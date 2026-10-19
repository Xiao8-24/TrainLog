import XCTest
@testable import TrainLogCore

final class CardioTests: XCTestCase {
    func testComparableEffortUsesOnlyPriorMatchedWatchWorkouts() {
        var current = workout(); current.activity?.source = "appleWatch"; current.activity?.watchWorkoutID = UUID()
        current.activity?.averageHeartRate = 140
        var earlier = current; earlier.id = UUID(); earlier.date = current.date.addingTimeInterval(-86400); earlier.activity?.averageHeartRate = 150
        var earlier2 = earlier; earlier2.id = UUID(); earlier2.date = earlier.date.addingTimeInterval(-86400); earlier2.activity?.averageHeartRate = 160
        var wrongKind = earlier; wrongKind.id = UUID(); wrongKind.activity?.kind = .outdoorCycle
        var wrongPace = earlier; wrongPace.id = UUID(); wrongPace.manualDurationSeconds = 3600
        var future = earlier; future.id = UUID(); future.date = current.date.addingTimeInterval(86400)
        let result = CardioAnalysis.comparableEffort(for: current, history: [current, earlier, earlier2, wrongKind, wrongPace, future])
        XCTAssertEqual(result?.count, 2); XCTAssertEqual(result?.previousMeanHeartRate, 155); XCTAssertEqual(result?.difference, -15)
        XCTAssertNil(CardioAnalysis.comparableEffort(for: current, history: [earlier, wrongKind]))
    }
    private func workout() -> Session {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        var value = Session(mode: .cardio, date: start)
        value.activity = ActivityRecord(kind: .outdoorRun); value.activity?.distanceMeters = 5000
        value.manualDurationSeconds = 1800; value.finish(at: start.addingTimeInterval(1800))
        return value
    }
    func testExpandedCatalogAndStableLegacyIdentifiers() throws {
        XCTAssertEqual(ExerciseCatalog.exercises.count, 128)
        XCTAssertEqual(CardioActivity.allCases.count, 38)
        XCTAssertEqual(Set(ExerciseCatalog.exercises.map(\.name)).count, 128)
        XCTAssertEqual(ExerciseCatalog.exercises[36].id, ExerciseCatalog.id(37))
        XCTAssertEqual(ExerciseCatalog.exercises[0].name, "杠铃卧推")
        for exercise in ExerciseCatalog.exercises { try RecordValidator.exercise(exercise) }
    }
    func testCardioCountsTimeAndCalendarWithoutStrengthOrMuscleMetrics() throws {
        let value = workout(); try RecordValidator.session(value)
        let total = WorkoutStatisticsService.totals([value])
        XCTAssertEqual(total.sessions, 1); XCTAssertEqual(total.durationSeconds, 1800)
        XCTAssertEqual(total.workingSets, 0); XCTAssertNil(total.volumeKg)
        XCTAssertTrue(MuscleMappingService.coverage(of: value).isEmpty)
        XCTAssertEqual(CardioAnalysis.totals([value]).distanceMeters, 5000)
        XCTAssertEqual(CardioAnalysis.totals([value]).sessions, 1)
        XCTAssertNil(CardioAnalysis.totals([value]).activeEnergyKcal)
        XCTAssertEqual(value.activity?.paceSecondsPerKilometer(duration: value.elapsed()), 360)
        XCTAssertEqual(value.activity?.speedKilometersPerHour(duration: value.elapsed()), 10)
        XCTAssertEqual(WorkoutWidgetSnapshot(sessions: [value], weeklyGoal: 4, now: value.date).records.first?.workingSets, 0)
    }
    func testMissingAndInvalidDistanceNeverProducePace() throws {
        var value = workout()
        for distance in [nil, 0.0, -1.0, .nan, .infinity] as [Double?] {
            value.activity?.distanceMeters = distance
            XCTAssertNil(value.activity?.paceSecondsPerKilometer(duration: 0))
        }
        value.activity?.distanceMeters = .nan; XCTAssertThrowsError(try RecordValidator.session(value))
        value.activity?.distanceMeters = -1; XCTAssertThrowsError(try RecordValidator.session(value))
        value.activity?.kind = .yoga; value.activity?.distanceMeters = 100
        XCTAssertThrowsError(try RecordValidator.session(value))
        value.activity?.distanceMeters = nil; try RecordValidator.session(value)
        value.manualDurationSeconds = 0; XCTAssertThrowsError(try RecordValidator.session(value))
    }
    func testCardioRoundTripAndPreCardioBackupDecoding() throws {
        let value = workout()
        let backup = Backup(sessions: [value], exercises: ExerciseCatalog.exercises, templates: [], bodyWeights: [], settings: Settings())
        let decoded = try BackupService.decode(BackupService.encode(backup))
        XCTAssertEqual(decoded.sessions, [value])
        var old = Session(mode: .quick, date: value.date); old.quickEntries = [QuickEntry(muscle: .chest)]; old.finish(at: value.date)
        let data = try JSONEncoder().encode(old)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "activity")
        let legacy = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.activity); XCTAssertEqual(legacy.quickEntries, old.quickEntries)
        var legacyBackup = backup; legacyBackup.schemaVersion = 1; legacyBackup.sessions = [old]
        XCTAssertEqual(try BackupService.decode(BackupService.encode(legacyBackup)).sessions, [old])
    }
    func testWatchEnvelopeAndHealthExportAvoidDuplicateWorkout() throws {
        var value = workout()
        value.activity?.source = "appleWatch"; value.activity?.watchWorkoutID = UUID()
        value.activity?.averageHeartRate = 140; value.activity?.maximumHeartRate = 175
        value.activity?.activeEnergyKcal = 250
        value.activity?.heartRate = [HeartRatePoint(date: value.date, bpm: 140)]
        let envelope = WatchWorkoutEnvelope(session: value)
        XCTAssertEqual(try WatchWorkoutEnvelope.decode(JSONEncoder().encode(envelope)).session, value)
        XCTAssertThrowsError(try HealthWorkoutExport(session: value))
        XCTAssertEqual(CardioAnalysis.totals([value]).activeEnergyKcal, 250)
        value.activity?.source = "manual"; XCTAssertThrowsError(try RecordValidator.session(value))
    }
    func testHeartRateValidationAndSourceIntegrity() throws {
        var value = workout(); value.activity?.source = "appleWatch"; value.activity?.watchWorkoutID = UUID()
        value.activity?.averageHeartRate = 150; value.activity?.maximumHeartRate = 130
        XCTAssertThrowsError(try RecordValidator.session(value))
        value.activity?.maximumHeartRate = 180; value.activity?.activeEnergyKcal = .infinity
        XCTAssertThrowsError(try RecordValidator.session(value))
        value.activity?.activeEnergyKcal = nil; value.activity?.heartRate = [HeartRatePoint(date: value.date, bpm: .nan)]
        XCTAssertThrowsError(try RecordValidator.session(value))
    }
    func testCardioHealthTypeAndOldLedgerCompatibility() throws {
        let export = try HealthWorkoutExport(session: workout())
        XCTAssertEqual(export.activityKind, .outdoorRun)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(export)) as? [String: Any])
        object.removeValue(forKey: "activityKind")
        XCTAssertNil(try JSONDecoder().decode(HealthWorkoutExport.self, from: JSONSerialization.data(withJSONObject: object)).activityKind)
    }
    func testCardioCSVRetainsMeasurementsAndColumnAlignment() {
        let csv = BackupService.csv([workout()])
        let rows = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].components(separatedBy: ",").count, 46)
        XCTAssertEqual(rows[1].components(separatedBy: ",").count, 46)
        XCTAssertTrue(csv.contains("\"outdoorRun\",\"5000.0\""))
        XCTAssertTrue(csv.contains("\"1800\""))
    }
    func testLiveWatchDataExpiresInsteadOfShowingStaleHeartRate() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let live = WatchLiveSnapshot(sessionID: UUID(), kind: .outdoorRun, updatedAt: start, startedAt: start, elapsed: 10, paused: false, heartRate: 140, activeEnergyKcal: 1, distanceMeters: 20)
        XCTAssertTrue(live.isFresh(at: start.addingTimeInterval(10)))
        XCTAssertFalse(live.isFresh(at: start.addingTimeInterval(21)))
        XCTAssertFalse(live.isFresh(at: start.addingTimeInterval(-6)))
        var invalid = live; invalid.heartRate = .nan
        XCTAssertFalse(invalid.isFresh(at: start))
    }
}
