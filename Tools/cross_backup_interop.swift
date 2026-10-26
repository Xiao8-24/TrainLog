import Foundation

@main
struct CrossBackupInterop {
    static func main() throws {
        let paths = CommandLine.arguments
        guard paths.count == 4 else { fatalError("Usage: interop validate|generate INPUT OUTPUT") }
        let output = URL(fileURLWithPath: paths[3])
        if paths[1] == "validate" {
            let backup = try BackupService.decode(Data(contentsOf: URL(fileURLWithPath: paths[2])))
            try BackupService.encode(backup).write(to: output)
            print("Native Swift decoder validated \(backup.sessions.count) sessions, \(backup.exercises.count) exercises and \(backup.plans?.count ?? 0) plans")
        } else {
            let now = Date().addingTimeInterval(-7200)
            let plan = TrainingPlan(name: "Native interoperability fixture", scheduledAt: now, items: [TemplateItem(exerciseID: ExerciseCatalog.exercises[0].id, setCount: 3, weightKg: 40, reps: 8)])
            var strength = try plan.session(catalog: ExerciseCatalog.exercises, at: now)
            let entryID = strength.exercises[0].id, setID = strength.exercises[0].sets[0].id
            try strength.startSet(entryID: entryID, setID: setID, at: now)
            try strength.completeSet(entryID: entryID, setID: setID, at: now.addingTimeInterval(30))
            strength.exercises[0].sets[0].rpe = 8
            strength.finish(at: now.addingTimeInterval(600))
            var cardio = Session(mode: .cardio, date: now)
            cardio.activity = ActivityRecord(kind: .outdoorRun)
            cardio.activity?.source = "appleWatch"; cardio.activity?.watchWorkoutID = UUID()
            cardio.activity?.distanceMeters = 3000; cardio.activity?.activeEnergyKcal = 200
            cardio.activity?.averageHeartRate = 130; cardio.activity?.maximumHeartRate = 150
            cardio.activity?.heartRate = [HeartRatePoint(date: now.addingTimeInterval(60), bpm: 130)]
            cardio.finish(at: now.addingTimeInterval(1200))
            var settings = Settings(); settings.unit = .lb; settings.targetSuggestionsEnabled = false
            settings.representatives = ["horizontalPush": ExerciseCatalog.exercises[0].id]
            let backup = Backup(sessions: [strength, cardio], exercises: ExerciseCatalog.exercises, templates: ExerciseCatalog.templates, bodyWeights: [BodyWeight(date: now, weightKg: 70)], settings: settings, plans: [plan])
            try BackupService.encode(backup).write(to: output)
            print("Generated native schema 5 backup with frozen targets, effort, Watch ownership, measurements, templates, body weight and settings")
        }
    }
}
