import SwiftUI
import TrainLogCore

struct TemplateLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: TrainingTemplate?
    @State private var deleting: TrainingTemplate?
    var body: some View {
        List {
            Section {
                ForEach(store.templates) { template in
                    Button { editing = template } label: {
                        VStack(alignment: .leading, spacing: 5) { Text(template.name).font(.headline); Text("\(template.items.count) 个动作 · \(template.items.reduce(0) { $0 + $1.setCount }) 个预设组").font(.caption).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain).swipeActions { Button("删除", role: .destructive) { deleting = template } }
                }
            } footer: { Text("点击模板编辑；拖动调整动作顺序。预设组不会自动标记完成。") }
        }.navigationTitle("训练模板")
            .toolbar { Button { editing = TrainingTemplate(name: "", items: []) } label: { Image(systemName: "plus") }.accessibilityLabel("新建模板") }
            .sheet(item: $editing) { item in NavigationStack { TemplateEditorView(template: item) } }
            .confirmationDialog("删除这个模板？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("删除模板", role: .destructive) { if let item = deleting { store.perform { try store.deleteTemplate(item.id) } }; deleting = nil }
            }
    }
}
struct TemplateEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var template: TrainingTemplate
    @State private var adding = false
    @State private var errorMessage: String?
    var body: some View {
        Form {
            Section { TextField("模板名称", text: $template.name) }
            Section("动作顺序") {
                ForEach($template.items) { $item in
                    if let exercise = store.exercises.first(where: { $0.id == item.exerciseID }) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(exercise.name).font(.headline)
                            Stepper("\(item.setCount) 组", value: $item.setCount, in: 1...30)
                            if exercise.tracking == .weightReps || exercise.tracking == .assistedReps {
                                HStack { Text("默认 \(store.settings.unit.rawValue)").font(.caption); OptionalNumberField(title: "可留空", value: Binding(get: { item.weightKg.map(store.settings.unit.display) }, set: { item.weightKg = $0.map(store.settings.unit.kilograms) })) }
                            }
                            if exercise.tracking != .duration {
                                HStack { Text("默认次数").font(.caption); OptionalNumberField(title: "可留空", value: Binding(get: { item.reps.map(Double.init) }, set: { value in item.reps = value.map { $0.isFinite && (1...1000).contains($0) && $0.rounded() == $0 ? Int($0) : -1 } }), integer: true) }
                            }
                            Button("使用上次重量和次数") {
                                if let previous = store.completed.lazy.compactMap({ $0.exercises.first { $0.exercise.comparisonKey == exercise.comparisonKey && $0.sets.contains { $0.isCompleted && $0.kind == .working } } }).first?.sets.last(where: { $0.isCompleted && $0.kind == .working }) {
                                    item.weightKg = previous.weightKg; item.reps = previous.reps
                                }
                            }.font(.caption).disabled(!store.completed.contains { $0.exercises.contains { $0.exercise.comparisonKey == exercise.comparisonKey && $0.sets.contains { $0.isCompleted && $0.kind == .working } } })
                        }.padding(.vertical, 4)
                    }
                }.onMove { template.items.move(fromOffsets: $0, toOffset: $1) }.onDelete { template.items.remove(atOffsets: $0) }
                Button("添加动作", systemImage: "plus") { adding = true }
            }
        }.navigationTitle("编辑模板").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { do { try store.saveTemplate(template); dismiss() } catch { errorMessage = error.localizedDescription } } }
            }
            .sheet(isPresented: $adding) { NavigationStack { ExerciseLibraryView { exercise in template.items.append(TemplateItem(exerciseID: exercise.id)); adding = false } } }
            .errorAlert($errorMessage)
    }
}

