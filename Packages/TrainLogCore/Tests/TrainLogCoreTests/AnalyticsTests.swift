import XCTest
@testable import TrainLogCore

final class AnalyticsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_770_000_000)
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var bench: Exercise { ExerciseCatalog.exercises[0] }
    private func workout(_ sets: [TrainingSet], date: Date? = nil, exercise: Exercise? = nil) -> Session {
        var s = Session(mode: .detailed, date: date ?? now)
        s.exercises = [ExerciseEntry(exercise: exercise ?? bench, sets: sets)]; s.finish(at: date ?? now); return s
    }
    private func set(_ weight: Double = 60, reps: Int = 8, kind: SetKind = .working, completed: Bool = true) -> TrainingSet {
        TrainingSet(weightKg: weight, reps: reps, kind: kind, rpe: 8, isCompleted: completed)
    }
    func testBenchThreeSetsMapToPrimaryAndSecondary() {
        let session = workout([set(), set(), set()])
        let stats = MuscleHeatmapService.statistics([session], interval: TimeRange.today.interval(now: now, calendar: calendar), calendar: calendar)
        XCTAssertEqual(stats.first { $0.muscle == .chest }?.weightedSets, 3)
        XCTAssertEqual(stats.first { $0.muscle == .triceps }?.weightedSets, 1.5)
        XCTAssertEqual(stats.first { $0.muscle == .frontDeltoid }?.weightedSets, 1.5)
        XCTAssertEqual(stats.first { $0.muscle == .quadriceps }?.weightedSets, 0)
    }
    func testEpleySixtyByEightIsSeventySix() {
        XCTAssertEqual(StrengthAnalysisService.estimate(set(), exercise: bench), 76)
        XCTAssertEqual(StrengthAnalysisService.estimate(set(90, reps: 1), exercise: bench), 90)
        XCTAssertNil(StrengthAnalysisService.estimate(set(reps: 11), exercise: bench))
        var easy = set(); easy.rpe = 6
        XCTAssertNil(StrengthAnalysisService.estimate(easy, exercise: bench))
        easy.rpe = nil; XCTAssertNil(StrengthAnalysisService.estimate(easy, exercise: bench))
        easy.rir = 1; XCTAssertNotNil(StrengthAnalysisService.estimate(easy, exercise: bench))
        easy.rpe = 6; XCTAssertNil(StrengthAnalysisService.estimate(easy, exercise: bench))
    }
    func testQuickEntryCannotInventSetsVolumeOrStrengthAndDayDeduplicates() {
        var quick = Session(mode: .quick, date: now)
        quick.quickEntries = [QuickEntry(muscle: .chest, intensity: .hard)]; quick.finish(at: now)
        let total = WorkoutStatisticsService.totals([quick], calendar: calendar)
        XCTAssertEqual(total.workingSets, 0); XCTAssertNil(total.volumeKg)
        XCTAssertTrue(StrengthAnalysisService.performances([quick], exercise: bench).isEmpty)
        let both = [quick, workout([set()])]
        XCTAssertEqual(WorkoutStatisticsService.totals(both, calendar: calendar).sessions, 2)
        XCTAssertEqual(WorkoutStatisticsService.totals(both, calendar: calendar).trainingDays, 1)
        let chest = MuscleHeatmapService.statistics(both, interval: TimeRange.today.interval(now: now), calendar: calendar).first { $0.muscle == .chest }
        XCTAssertEqual(chest?.trainingDays, 1); XCTAssertEqual(chest?.weightedSets, 1)
    }
    func testWarmupDropFailureUnfinishedAndDraftExcludedFromWorkingTotals() {
        let s = workout([set(), set(kind: .warmup), set(kind: .drop), set(kind: .failed), set(completed: false)])
        let total = WorkoutStatisticsService.totals([s])
        XCTAssertEqual(total.workingSets, 1); XCTAssertEqual(total.volumeKg, 480)
        var draft = s; draft.status = .draft
        XCTAssertEqual(WorkoutStatisticsService.totals([draft]).sessions, 0)
        XCTAssertTrue(MuscleMappingService.coverage(of: draft).isEmpty)
    }
    func testZeroRepFailedAttemptIsStoredButNeverCountedAsWork() throws {
        let attempt = set(reps: 0, kind: .failed)
        try RecordValidator.trainingSet(attempt, exercise: bench)
        let session = workout([attempt])
        XCTAssertEqual(WorkoutStatisticsService.totals([session]).workingSets, 0)
        XCTAssertNil(WorkoutStatisticsService.totals([session]).volumeKg)
        XCTAssertTrue(MuscleMappingService.coverage(of: session).isEmpty)
        XCTAssertTrue(PersonalRecordService.records([session], exercise: bench).isEmpty)
    }
    func testEditAndDeleteRecomputeRecords() {
        let old = workout([set(50)], date: now.addingTimeInterval(-86400))
        var recent = workout([set(60)])
        XCTAssertEqual(PersonalRecordService.records([old, recent], exercise: bench).first { $0.type == .weight }?.value, 60)
        recent.exercises[0].sets[0].weightKg = 70
        XCTAssertEqual(WorkoutStatisticsService.totals([recent]).volumeKg, 560)
        XCTAssertEqual(StrengthAnalysisService.performances([recent], exercise: bench).first?.estimated1RM, 70 * (1 + 8.0 / 30))
        XCTAssertEqual(PersonalRecordService.records([old], exercise: bench).first { $0.type == .weight }?.value, 50)
        XCTAssertTrue(PersonalRecordService.records([], exercise: bench).isEmpty)
    }
    func testLatestPerformancePreservesEnteredSetOrder() {
        let session = workout([set(60), set(65), set(55)])
        let values = StrengthAnalysisService.performances([session], exercise: bench)
        XCTAssertEqual(values.map(\.weightKg), [60, 65, 55])
        XCTAssertEqual(values.last?.setID, session.exercises[0].sets.last?.id)
    }
    func testLoadingConventionsAndBodyweight() {
        let dumbbell = ExerciseCatalog.exercises[1]
        XCTAssertEqual(WorkoutStatisticsService.volume(set(20, reps: 10), exercise: dumbbell), 400)
        let pushup = ExerciseCatalog.exercises[3]
        let bodySet = TrainingSet(reps: 20, isCompleted: true)
        XCTAssertNil(WorkoutStatisticsService.volume(bodySet, exercise: pushup))
        XCTAssertEqual(WorkoutStatisticsService.totals([workout([bodySet], exercise: pushup)]).workingSets, 1)
        let assisted = ExerciseCatalog.exercises.first { $0.tracking == .assistedReps }!
        XCTAssertNil(WorkoutStatisticsService.volume(set(), exercise: assisted))
        XCTAssertNil(StrengthAnalysisService.estimate(set(), exercise: assisted))
    }
    func testCalendarHalfOpenIntervalsCrossYearAndLocalDay() {
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let range = TimeRange.week.interval(now: jan1, calendar: calendar)
        XCTAssertTrue(range.includes(jan1.addingTimeInterval(-6 * 86400)))
        XCTAssertFalse(range.includes(jan1.addingTimeInterval(-7 * 86400)))
        XCTAssertFalse(range.includes(jan1.addingTimeInterval(86400)))
        var shanghai = calendar; shanghai.timeZone = TimeZone(secondsFromGMT: 28800)!
        let two = [workout([set()], date: jan1.addingTimeInterval(15 * 3600)), workout([set()], date: jan1.addingTimeInterval(17 * 3600))]
        XCTAssertEqual(WorkoutStatisticsService.totals(two, calendar: shanghai).trainingDays, 2)
    }
    func testUnitRoundtripAndInvalidNumbers() {
        XCTAssertEqual(WeightUnit.lb.kilograms(WeightUnit.lb.display(60)), 60, accuracy: 0.0000001)
        XCTAssertThrowsError(try RecordValidator.trainingSet(set(-1), exercise: bench))
        XCTAssertThrowsError(try RecordValidator.trainingSet(set(reps: -1), exercise: bench))
        XCTAssertThrowsError(try RecordValidator.trainingSet(set(.nan), exercise: bench))
        XCTAssertThrowsError(try RecordValidator.trainingSet(TrainingSet(isCompleted: true), exercise: bench))
    }
    func testEmptyDataAndFixedHeatThresholds() {
        let stats = MuscleHeatmapService.statistics([], interval: TimeRange.all.interval(now: now))
        XCTAssertEqual(stats.count, MuscleGroup.allCases.count)
        XCTAssertTrue(stats.allSatisfy { MuscleHeatmapService.level($0, metric: .weightedSets) == 0 })
        let once = MuscleHeatmapService.statistics([workout([set()])], interval: TimeRange.today.interval(now: now))
        XCTAssertEqual(once.first { $0.muscle == .chest }.map { MuscleHeatmapService.level($0, metric: .weightedSets) }, 1)
    }
    func testSnapshotPreventsCatalogEditsChangingHistory() {
        let session = workout([set()])
        var edited = bench; edited.primary = [.quadriceps]; edited.loading = .perHand
        XCTAssertTrue(StrengthAnalysisService.performances([session], exercise: edited).isEmpty)
        XCTAssertEqual(MuscleMappingService.coverage(of: session), [.chest, .triceps, .frontDeltoid])
    }
    func testRelativeStrengthUsesContemporaneousBodyWeightOnly() {
        let p = StrengthAnalysisService.performances([workout([set()])], exercise: bench)[0]
        XCTAssertNil(StrengthAnalysisService.relativeStrength(p, weights: []))
        XCTAssertNil(StrengthAnalysisService.relativeStrength(p, weights: [BodyWeight(date: now.addingTimeInterval(-40 * 86400), weightKg: 70)]))
        XCTAssertEqual(StrengthAnalysisService.relativeStrength(p, weights: [BodyWeight(date: now, weightKg: 70)])!, 76.0 / 70, accuracy: 0.0001)
    }
    func testCycleComparisonNeedsTwoDaysPerPeriod() {
        let insufficient = StrengthAnalysisService.performances([workout([set()])], exercise: bench)
        XCTAssertNil(StrengthAnalysisService.compare(insufficient, now: now, calendar: calendar))
        let data = [workout([set(50)], date: now.addingTimeInterval(-40 * 86400)), workout([set(50)], date: now.addingTimeInterval(-35 * 86400)), workout([set(60)], date: now.addingTimeInterval(-10 * 86400)), workout([set(60)], date: now)]
        let comparison = StrengthAnalysisService.compare(StrengthAnalysisService.performances(data, exercise: bench), now: now, calendar: calendar)
        XCTAssertEqual(comparison!.percent, 20, accuracy: 0.0001)
    }
    func testTemplateSetsAreNotCompleted() throws {
        let s = try ExerciseCatalog.session(from: ExerciseCatalog.templates[0], catalog: ExerciseCatalog.exercises, date: now)
        XCTAssertTrue(s.exercises.flatMap(\.sets).allSatisfy { !$0.isCompleted })
        XCTAssertEqual(WorkoutStatisticsService.totals([s]).workingSets, 0)
    }
    func testPauseResumeUsesWallClockAndManualOverride() {
        var s = Session(mode: .detailed, date: now)
        s.pause(at: now.addingTimeInterval(60)); XCTAssertEqual(s.elapsed(at: now.addingTimeInterval(200)), 60)
        s.timerStartedAt = now.addingTimeInterval(200)
        s.finish(at: now.addingTimeInterval(230)); XCTAssertEqual(s.elapsed(), 90)
        s.manualDurationSeconds = 300; XCTAssertEqual(s.elapsed(), 300)
    }
}

