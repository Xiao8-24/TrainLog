import SwiftUI
import TrainLogCore

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var step = 0
    @State private var settings = Settings()
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 12)
                Image(systemName: step == 0 ? "figure.strengthtraining.traditional" : step == 1 ? "target" : "scalemass").font(.system(size: 56, weight: .light)).foregroundStyle(.blue).accessibilityHidden(true)
                Text(step == 0 ? "欢迎使用\nTrainLog" : step == 1 ? "找到你的节奏" : "用习惯的单位记录").font(.largeTitle.bold())
                Text(step == 0 ? "记录每一次训练，\n看见每一点进步。" : step == 1 ? "目标只是提醒。按自己的节奏，让记录成为习惯。" : "所有重量统一存储为 kg，显示单位可随时更改。")
                    .font(.title3).foregroundStyle(.secondary)
                if step == 0 {
                    Label("完全离线，无需账号", systemImage: "wifi.slash")
                    Label("你的数据，留在你的设备", systemImage: "lock.shield")
                    Label("独立肌群地图与真实力量趋势", systemImage: "chart.xyaxis.line")
                } else if step == 1 {
                    Picker("训练目标", selection: $settings.trainingGoal) { ForEach(["保持规律", "提升力量", "增加肌肉", "记录与观察"], id: \.self) { Text($0).tag($0) } }
                    Stepper("每周 \(settings.weeklyGoal) 次", value: $settings.weeklyGoal, in: 1...14)
                } else { Picker("重量单位", selection: $settings.unit) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
                Spacer()
                HStack(spacing: 6) { ForEach(0..<3) { i in Capsule().fill(i == step ? Color.blue : Color(uiColor: .systemGray4)).frame(width: i == step ? 24 : 8, height: 5) } }.accessibilityLabel("第 \(step + 1) 步，共 3 步")
                PrimaryActionButton(title: step == 2 ? "开始记录" : "继续", symbol: "arrow.right") { if step < 2 { step += 1 } else { finish() } }.accessibilityIdentifier("onboardingNext")
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }.background(AppTheme.background)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("跳过") { finish() }.accessibilityIdentifier("skipOnboarding") }
                    if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("上一步") { step -= 1 } } }
                }
        }.onAppear { settings = store.settings }.errorAlert($errorMessage)
    }
    private func finish() { do { settings.hasOnboarded = true; try store.updateSettings(settings) } catch { errorMessage = error.localizedDescription } }
}

