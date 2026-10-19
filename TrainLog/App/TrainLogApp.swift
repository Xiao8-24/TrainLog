import SwiftUI
import TrainLogCore

@main struct TrainLogApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    @State private var pendingURL: URL?
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let store {
                    RootView(pendingURL: $pendingURL).environment(store)
                        #if DEBUG
                        .environment(\.trainLogMotionTestOverride, ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-ui-reduce-motion"))
                        #endif
                        .preferredColorScheme(store.settings.theme == .system ? nil : store.settings.theme == .dark ? .dark : .light)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("暂时无法读取训练档案", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("原始数据库已保留，没有重置或覆盖。\n\(startupError)")
                    } actions: { Button("重新尝试", action: load).buttonStyle(.borderedProminent) }
                } else { LoadingStateView() }
            }.tint(.blue).fontDesign(.default).task { if store == nil && startupError == nil { load() } }
                .onOpenURL {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-ui-testing") { NSLog("TrainLog UI URL received: %@", $0.absoluteString) }
                    #endif
                    pendingURL = $0
                }
        }
    }
    private func load() {
        do {
            #if DEBUG
            let inMemory = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            if inMemory, let value = ProcessInfo.processInfo.environment["TRAINLOG_UI_TEST_STORE"], let id = UUID(uuidString: value) {
                // A unique sandbox file lets URL-launch tests survive process
                // restarts without touching a real user's database or widgets.
                let url = FileManager.default.temporaryDirectory.appending(path: "ui-test-\(id.uuidString).store")
                store = try AppStore(storeURL: url); startupError = nil
                return
            }
            #else
            let inMemory = false
            #endif
            let loaded = try AppStore(inMemory: inMemory)
            #if DEBUG
            if inMemory, ProcessInfo.processInfo.arguments.contains("-ui-linked-watch") { try seedLinkedWatchPreview(loaded) }
            if inMemory, ProcessInfo.processInfo.arguments.contains("-ui-review-targets") { try seedReviewTargetsPreview(loaded) }
            #endif
            store = loaded; startupError = nil
        } catch { startupError = error.localizedDescription }
    }
    #if DEBUG
    /// Real app screens and storage, isolated synthetic records; no sensor/health requests.
    private func seedReviewTargetsPreview(_ store: AppStore) throws {
        let exercise = ExerciseCatalog.exercises[0]
        for days in [2, 1] {
            let start = Date().addingTimeInterval(-Double(days) * 86400)
            let plan = TrainingPlan(name: "计划复盘验证", scheduledAt: start, items: [TemplateItem(exerciseID: exercise.id, setCount: 2, weightKg: 60, reps: 8)])
            try store.savePlan(plan)
            var session = try plan.session(catalog: store.exercises, at: start)
            if days == 1 { session.id = UUID(uuidString: "81000000-0000-0000-0000-000000000002")! }
            session.notes = "界面测试数据，非真实运动记录"
            for index in session.exercises[0].sets.indices { session.exercises[0].sets[index].rpe = 7 }
            if days == 1 { session.exercises[0].sets[0].reps = 9 }
            let entry = session.exercises[0].id, first = session.exercises[0].sets[0].id
            try session.startSet(entryID: entry, setID: first, at: start.addingTimeInterval(5))
            try session.completeSet(entryID: entry, setID: first, at: start.addingTimeInterval(25))
            session.exercises[0].sets[1].isCompleted = true; session.finish(at: start.addingTimeInterval(120)); try store.save(session)
        }
        var next = TrainingPlan(name: "目标参考验证计划", scheduledAt: Date().addingTimeInterval(86400), items: [TemplateItem(exerciseID: exercise.id, setCount: 2, weightKg: 60, reps: 8)])
        next.id = UUID(uuidString: "81000000-0000-0000-0000-000000000003")!; try store.savePlan(next)
        var settings = store.settings; settings.trainingGoal = "提升力量"; try store.updateSettings(settings)
    }
    /// Synthetic, isolated UI-test data; never requests sensors or HealthKit.
    private func seedLinkedWatchPreview(_ store: AppStore) throws {
        let now = Date()
        var phone = Session(mode: .detailed, date: now.addingTimeInterval(-1200))
        var exercise = ExerciseCatalog.exercises[0]; exercise.name = "界面测试力量训练"
        phone.exercises = [ExerciseEntry(exercise: exercise, sets: [TrainingSet(weightKg: 60, reps: 8, isCompleted: true)])]
        phone.notes = "界面测试数据，非真实传感器测量"; phone.manualDurationSeconds = 1200
        try store.save(phone)
        let request = try store.prepareWatchLink(sessionID: phone.id)
        var watch = Session(mode: .cardio, date: now.addingTimeInterval(-600))
        watch.activity = ActivityRecord(kind: .traditionalStrength); watch.activity?.source = "appleWatch"
        watch.activity?.watchWorkoutID = UUID(); watch.activity?.averageHeartRate = 120
        watch.activity?.maximumHeartRate = 142; watch.activity?.activeEnergyKcal = 80
        let watchStart = watch.startTime
        watch.activity?.heartRate = [105.0, 119, 133, 142, 117, 104].enumerated().map { offset, value in
            HeartRatePoint(date: watchStart.addingTimeInterval(Double(offset * 60)), bpm: value)
        }
        watch.phoneLink = request.reference; watch.finish(at: now)
        try store.receiveWatchSession(watch)
        phone.finish(at: now); try store.save(phone)
    }
    #endif
}

