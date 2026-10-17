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
                    Text(store.draft == nil ? "留住今天的努力" : "训练还在进行中").font(.title2.weight(.semibold))
                    Text(store.draft == nil ? "记录力量、有氧与更多运动，也可以只记下训练部位。" : "草稿已保存在本机，随时继续。").font(.subheadline).foregroundStyle(.secondary)
                    PrimaryActionButton(title: store.draft == nil ? "详细记录" : "继续训练", symbol: "play.fill") { router.start(.detailed, store: store) }
                    if store.draft == nil { Button { router.start(.quick, store: store) } label: { Label("快速记录肌群", systemImage: "figure.stand").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("quickWorkout") }
                    if store.draft == nil {
                        Button { router.start(.cardio, store: store) } label: { Label("有氧与其他运动", systemImage: "figure.run").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("cardioWorkout")
                    }
                    NavigationLink { WatchConnectionView() } label: { Label("Apple Watch 训练", systemImage: "applewatch").frame(maxWidth: .infinity, minHeight: 44) }
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

