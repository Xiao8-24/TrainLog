import XCTest
@testable import TrainLogCore

final class BackupTests: XCTestCase {
    private func backup() -> Backup {
        var s = Session(mode: .quick, date: Date(timeIntervalSince1970: 1_760_000_000))
        s.quickEntries = [QuickEntry(muscle: .chest, intensity: .hard)]; s.finish(at: s.date)
        return Backup(sessions: [s], exercises: ExerciseCatalog.exercises, templates: ExerciseCatalog.templates, bodyWeights: [], settings: Settings())
    }
    func testRoundtripAndRepeatedImportIdempotency() throws {
        let original = backup(), decoded = try BackupService.decode(BackupService.encode(original))
        XCTAssertEqual(decoded.sessions, original.sessions)
        let once = try BackupService.importing(decoded, into: original, mode: .merge)
        let twice = try BackupService.importing(decoded, into: once, mode: .merge)
        XCTAssertEqual(twice.sessions.count, 1); XCTAssertEqual(twice.exercises.count, original.exercises.count)
    }
    func testDuplicateIDsUnsupportedVersionAndDanglingReferenceRejected() {
        var data = backup(); data.sessions.append(data.sessions[0])
        XCTAssertThrowsError(try BackupService.validate(data))
        data = backup(); data.schemaVersion = 99; XCTAssertThrowsError(try BackupService.validate(data))
        data = backup(); data.exercises = []; XCTAssertThrowsError(try BackupService.validate(data))
    }
    func testMergeRetainsLocalRecordsAndReplaceUsesImported() throws {
        let local = backup(); var changed = local; changed.sessions[0].notes = "外部修改"
        XCTAssertEqual(try BackupService.importing(changed, into: local, mode: .merge).sessions[0].notes, "")
        XCTAssertEqual(try BackupService.importing(changed, into: local, mode: .replace).sessions[0].notes, "外部修改")
    }
    func testCSVQuotesUnicodeAndSpreadsheetInjection() {
        var data = backup(); data.sessions[0].notes = "=SUM(1,2)\n\"胸部\""
        let csv = BackupService.csv(data.sessions)
        XCTAssertTrue(csv.contains("\"'=SUM(1,2)\n\"\"胸部\"\"\""))
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        XCTAssertEqual(csv.components(separatedBy: "\r\n")[0].components(separatedBy: ",").count, 46)
        var detailed = Session(mode: .detailed)
        var entry = ExerciseEntry(exercise: ExerciseCatalog.exercises[0], sets: [TrainingSet(weightKg: 60, reps: 8, isCompleted: true)])
        entry.notes = "动作备注"; entry.sets[0].notes = "训练组备注"
        detailed.exercises = [entry]; detailed.finish()
        let details = BackupService.csv([detailed])
        XCTAssertTrue(details.contains("\"动作备注\",\"训练组备注\",\"90\""))
        XCTAssertEqual(details.components(separatedBy: "\r\n")[1].components(separatedBy: ",").count, 46)
    }
    func testBadWeightAndConflictingDraftsRejectedBeforeImport() {
        var a = backup(); a.bodyWeights = [BodyWeight(weightKg: -1)]
        XCTAssertThrowsError(try BackupService.validate(a))
        a = backup(); a.sessions = [Session(mode: .detailed), Session(mode: .detailed)]
        XCTAssertThrowsError(try BackupService.validate(a))
    }
    func testBuiltInCatalogIsValid() throws {
        for exercise in ExerciseCatalog.exercises { try RecordValidator.exercise(exercise) }
        XCTAssertEqual(Set(ExerciseCatalog.exercises.map(\.id)).count, ExerciseCatalog.exercises.count)
    }
}

