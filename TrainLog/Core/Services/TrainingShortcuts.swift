import AppIntents

struct TrainingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ContinueTrainingIntent(), phrases: ["在 \(.applicationName) 继续训练"], shortTitle: "继续训练", systemImageName: "play.fill")
        AppShortcut(intent: OpenTrainingCalendarIntent(), phrases: ["打开 \(.applicationName) 健身日历"], shortTitle: "健身日历", systemImageName: "calendar")
        AppShortcut(intent: StartTrainingTemplateIntent(), phrases: ["用 \(.applicationName) 按模板训练"], shortTitle: "按模板训练", systemImageName: "dumbbell.fill")
        AppShortcut(intent: EndTrainingRestIntent(), phrases: ["在 \(.applicationName) 结束休息"], shortTitle: "结束休息", systemImageName: "timer")
    }
}
