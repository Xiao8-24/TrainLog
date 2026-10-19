import SwiftUI
import TrainLogCore

struct WorkoutHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WatchLiveCard()
                AppCard {
                    Image(systemName: "dumbbell.fill").font(.largeTitle).foregroundStyle(.blue).accessibilityHidden(true)
                    Text(store.draft == nil ? "准备好，开始训练" : "训练还在进行中").font(.title2.weight(.semibold))
                    Text(store.draft == nil ? "开始后自动计时，边练边记录每一组。也可以提前安排训练计划。" : "组数与计时已保存在本机，继续这场训练。").font(.subheadline).foregroundStyle(.secondary)
                    PrimaryActionButton(title: store.draft == nil ? "开始训练" : "继续训练", symbol: "play.fill") { router.start(.detailed, store: store) }.accessibilityIdentifier("liveWorkout.start")
                    if store.draft == nil { Button { router.start(.quick, store: store) } label: { Label("快速记录肌群", systemImage: "figure.stand").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("quickWorkout") }
                    if store.draft == nil {
                        Button { router.start(.cardio, store: store) } label: { Label("有氧与其他运动", systemImage: "figure.run").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("cardioWorkout")
                    }
                    NavigationLink { WatchConnectionView() } label: { Label("Apple Watch 训练", systemImage: "applewatch").frame(maxWidth: .infinity, minHeight: 44) }
                }
                AppCard {
                    NavigationLink { TrainingPlanLibraryView() } label: { Label("训练计划", systemImage: "calendar.badge.clock").font(.headline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                        .accessibilityIdentifier("trainingPlans")
                    let upcoming = store.plans.filter { plan in !plan.isSkipped && !store.sessions.contains(where: { $0.plan?.id == plan.id }) }.prefix(3)
                    if upcoming.isEmpty { Text("先安排日期、动作与预设组，开练时再自动计时。").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(Array(upcoming)) { plan in NavigationLink { TrainingPlanDetailView(planID: plan.id) } label: { TrainingPlanRow(plan: plan) } }
                }
                AppCard {
                    HStack { SectionHeader(title: "从模板开始", subtitle: "模板只是配置，完成后才计入统计"); Spacer(); NavigationLink { TemplateLibraryView() } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("管理训练模板") }
                    ForEach(store.templates) { template in
                        Button { router.start(.detailed, store: store, template: template) } label: {
                            HStack { VStack(alignment: .leading, spacing: 4) { Text(template.name).font(.headline); Text("\(template.items.count) 个动作").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "play.circle.fill").font(.title2) }.padding(.vertical, 6)
                        }.buttonStyle(.plain)
                    }
                }
                AppCard {
                    NavigationLink { ExerciseLibraryView() } label: { Label("动作库", systemImage: "books.vertical").font(.headline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                    Divider()
                    NavigationLink { HistoryView() } label: { Label("训练历史", systemImage: "clock.arrow.circlepath").font(.headline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                }
            }.padding(20)
        }.background(AppTheme.background).navigationTitle("训练")
    }
}

