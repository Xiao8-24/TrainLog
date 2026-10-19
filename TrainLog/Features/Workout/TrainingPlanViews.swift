import SwiftUI
import TrainLogCore

struct TrainingPlanRow: View {
    var plan: TrainingPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(plan.name).font(.headline)
            Text(plan.scheduledAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
            Text("\(plan.items.count) 个动作 · \(plan.items.reduce(0) { $0 + $1.setCount }) 个预设组" + (plan.isSkipped ? " · 已跳过" : ""))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
struct TrainingPlanLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var creating = false
    var body: some View {
        List {
            Section {
                ForEach(store.plans) { plan in NavigationLink { TrainingPlanDetailView(planID: plan.id) } label: {
                    TrainingPlanRow(plan: plan)
                    if let session = store.sessions.first(where: { $0.plan?.id == plan.id }) {
                        Text(session.status == .completed ? "已完成" : "进行中").font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("plan.row.\(plan.id.uuidString)") }
                if store.plans.isEmpty { ContentUnavailableView("提前安排下一次训练", systemImage: "calendar.badge.plus", description: Text("选择日期、动作和预设组。计划不计入已完成训练。")) }
            } footer: { Text("日期只是计划安排；开始时才创建训练并自动计时。不会自动开练或发送提醒。") }
        }.navigationTitle("训练计划")
            .toolbar { Button("新建计划", systemImage: "plus") { creating = true }.accessibilityIdentifier("plan.new") }
            .sheet(isPresented: $creating) { NavigationStack { TrainingPlanEditorView(plan: TrainingPlan()) } }
    }
}
struct TrainingPlanDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    var planID: UUID
    @State private var editing: TrainingPlan?
    @State private var deleting = false
    var body: some View {
        if let plan = store.plans.first(where: { $0.id == planID }) {
            List {
                Section { TrainingPlanRow(plan: plan); if !plan.notes.isEmpty { Text(plan.notes) } }
                Section("预设动作与组数") {
                    ForEach(plan.items) { item in
                        if let exercise = store.exercises.first(where: { $0.id == item.exerciseID }) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.headline)
                                Text("\(item.setCount) 组 · " + setDescription(TrainingSet(weightKg: item.weightKg, reps: item.reps, durationSeconds: item.durationSeconds), exercise: exercise, unit: store.settings.unit)).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    if let session = store.sessions.first(where: { $0.plan?.id == plan.id }), session.status == .completed {
                        NavigationLink("查看已完成训练") { SessionDetailView(sessionID: session.id) }
                    } else {
                        Button(store.draft?.plan?.id == plan.id ? "继续这次训练" : "开始计划训练", systemImage: "play.fill") { router.startPlan(plan.id, store: store) }
                            .disabled(plan.isSkipped).accessibilityIdentifier("plan.start")
                        Text("开始后按实际时间计时，预设组不会自动标记完成。已有其他训练时需先结束。").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("复制到另一个日期", systemImage: "calendar.badge.plus") { editing = plan.copied(to: Calendar.current.date(byAdding: .day, value: 1, to: plan.scheduledAt) ?? Date()) }
                    if !store.sessions.contains(where: { $0.plan?.id == plan.id }) {
                        Button(plan.isSkipped ? "恢复为待训练" : "跳过这次计划") { var next = plan; next.isSkipped.toggle(); store.perform { try store.savePlan(next) } }
                    }
                }
                Section { Button("删除计划", role: .destructive) { deleting = true } }
            }.navigationTitle("计划详情").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("编辑") { editing = plan }.accessibilityIdentifier("plan.edit") }
                .sheet(item: $editing) { value in NavigationStack { TrainingPlanEditorView(plan: value) } }
                .confirmationDialog("删除计划？已经开始或完成的训练会保留。", isPresented: $deleting) {
                    Button("删除计划", role: .destructive) { do { try store.deletePlan(plan.id); dismiss() } catch { store.errorMessage = error.localizedDescription } }
                }
        } else { ContentUnavailableView("计划已删除", systemImage: "calendar") }
    }
}
struct TrainingPlanEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var plan: TrainingPlan
    @State private var configuring = false
    @State private var issue: String?
    private var configuration: TrainingTemplate { var value = TrainingTemplate(name: plan.name, items: plan.items); value.id = plan.id; return value }
    var body: some View {
        Form {
            Section {
                TextField("计划名称", text: $plan.name).accessibilityIdentifier("plan.name")
                DatePicker("计划时间", selection: $plan.scheduledAt).accessibilityIdentifier("plan.date")
                TextField("计划备注（可选）", text: $plan.notes, axis: .vertical)
            }
            Section("训练内容") {
                Menu("从模板填入") {
                    ForEach(store.templates) { template in Button(template.name) {
                        plan.name = template.name
                        plan.items = template.items.map { item in var value = item; value.id = UUID(); return value }
                    }.accessibilityIdentifier("plan.template.\(template.id.uuidString)") }
                }.accessibilityIdentifier("plan.template")
                Button("配置动作与预设组", systemImage: "slider.horizontal.3") { configuring = true }.accessibilityIdentifier("plan.configure")
                ForEach(plan.items) { item in
                    if let exercise = store.exercises.first(where: { $0.id == item.exerciseID }) { LabeledContent(exercise.name, value: "\(item.setCount) 组") }
                }
            }
            Section { Text("计划只保存安排。开练时自动创建独立训练并开始计时，重量、次数和组数仍可现场调整。").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("编辑计划").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存计划") {
                    do { try store.savePlan(plan); dismiss() } catch { issue = error.localizedDescription }
                }.accessibilityIdentifier("plan.save") }
            }
            .sheet(isPresented: $configuring) { NavigationStack {
                TemplateEditorView(template: configuration, onSave: { value in
                    var next = plan; next.name = value.name; next.items = value.items
                    try next.validate(catalog: store.exercises); plan = next
                })
            } }
            .errorAlert($issue)
    }
}
