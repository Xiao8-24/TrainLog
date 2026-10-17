import SwiftUI
import TrainLogCore

struct ExerciseLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onPick: ((Exercise) -> Void)? = nil
    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @State private var equipment: Equipment?
    @State private var favoritesOnly = false
    @State private var creating = false
    private var results: [Exercise] {
        store.exercises.filter { !$0.isArchived && (!favoritesOnly || $0.isFavorite) && (equipment == nil || $0.equipment == equipment) && (muscle == nil || $0.primary.contains(muscle!) || $0.secondary.contains(muscle!)) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.englishName.localizedCaseInsensitiveContains(search)) }
            .sorted { $0.isFavorite == $1.isFavorite ? $0.name < $1.name : $0.isFavorite }
    }
    var body: some View {
        List {
            Section {
                Picker("肌群筛选", selection: $muscle) {
                    Text("全部肌群").tag(Optional<MuscleGroup>.none)
                    ForEach(MuscleGroup.allCases) { Text($0.name).tag(Optional($0)) }
                }
                Toggle("只看收藏", isOn: $favoritesOnly)
                Picker("器械筛选", selection: $equipment) {
                    Text("全部器械").tag(Optional<Equipment>.none)
                    ForEach(Equipment.allCases) { Text($0.name).tag(Optional($0)) }
                }
            }
            Section("\(results.count) 个动作") {
                ForEach(results) { exercise in
                    Group {
                        if let onPick { Button { onPick(exercise) } label: { ExerciseRow(exercise: exercise) }.buttonStyle(.plain) }
                        else { NavigationLink { ExerciseDetailView(exerciseID: exercise.id) } label: { ExerciseRow(exercise: exercise) } }
                    }.swipeActions(edge: .leading) {
                        Button { var value = exercise; value.isFavorite.toggle(); store.perform { try store.saveExercise(value) } } label: { Label(exercise.isFavorite ? "取消收藏" : "收藏", systemImage: "star") }.tint(.orange)
                    }
                }
                if results.isEmpty { EmptyStateView(title: "没有匹配的动作", message: "尝试更换筛选条件，或创建自定义动作。", symbol: "magnifyingglass") }
            }
        }
        .navigationTitle("动作库").searchable(text: $search, prompt: "搜索动作名称")
        .toolbar {
            if onPick != nil { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
            ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("创建自定义动作") }
        }
        .sheet(isPresented: $creating) { NavigationStack { ExerciseDefinitionEditor(exercise: Exercise(name: "", primary: [], isCustom: true)) } }
    }
}
struct ExerciseDetailView: View {
    @Environment(AppStore.self) private var store
    var exerciseID: UUID
    @State private var editing: Exercise?
    var body: some View {
        if let exercise = store.exercises.first(where: { $0.id == exerciseID }) {
            List {
                Section {
                    ExerciseRow(exercise: exercise)
                    LabeledContent("英文", value: exercise.englishName.isEmpty ? "未填写" : exercise.englishName)
                    LabeledContent("记录模式", value: exercise.tracking.name)
                    LabeledContent("负重口径", value: exercise.loading.name)
                    LabeledContent("动作模式", value: exercise.pattern?.name ?? "其他")
                    LabeledContent("e1RM 估算", value: exercise.allowsEstimate ? "满足条件时提供" : "不提供")
                }
                Section("肌群映射") {
                    LabeledContent("主要 · 1.0", value: exercise.primary.map(\.name).joined(separator: "、"))
                    LabeledContent("次要 · 0.5", value: exercise.secondary.isEmpty ? "未指定" : exercise.secondary.map(\.name).joined(separator: "、"))
                    Text("没有标注的部位不推定为已训练。保存训练时会保留这份映射快照。").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button(exercise.isFavorite ? "取消收藏" : "收藏动作", systemImage: exercise.isFavorite ? "star.slash" : "star") { var value = exercise; value.isFavorite.toggle(); store.perform { try store.saveExercise(value) } }
                    if exercise.isCustom { Button("编辑自定义动作", systemImage: "pencil") { editing = exercise } }
                }
                Section("使用说明") {
                    Text("双手同时使用哑铃且选择“每只哑铃”时，容量按单只重量 × 2 × 次数。单臂、单腿动作请分别记录左右两组，并填写该侧实际外部总负重。绳索和器械请使用同一台设备的标称重量。")
                    Text("不同动作、器械与负重口径之间不进行力量排名；自重、辅助和计时动作不虚构容量或 e1RM。")
                }.font(.subheadline)
            }.navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
                .sheet(item: $editing) { item in NavigationStack { ExerciseDefinitionEditor(exercise: item) } }
        } else { ContentUnavailableView("动作不存在", systemImage: "dumbbell") }
    }
}
struct ExerciseDefinitionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var exercise: Exercise
    @State private var errorMessage: String?
    var body: some View {
        Form {
            Section("基本信息") {
                TextField("动作名称", text: $exercise.name)
                TextField("英文名称（可选）", text: $exercise.englishName)
                Picker("器械", selection: $exercise.equipment) { ForEach(Equipment.allCases) { Text($0.name).tag($0) } }
                Picker("记录模式", selection: $exercise.tracking) { ForEach(TrackingMode.allCases) { Text($0.name).tag($0) } }
                if exercise.tracking == .weightReps {
                    Picker("重量口径", selection: $exercise.loading) { Text(LoadingConvention.total.name).tag(LoadingConvention.total); Text(LoadingConvention.perHand.name).tag(LoadingConvention.perHand) }
                } else { LabeledContent("重量口径", value: exercise.loading.name) }
                Picker("动作模式", selection: $exercise.pattern) { Text("其他").tag(Optional<MovementPattern>.none); ForEach(MovementPattern.allCases) { Text($0.name).tag(Optional($0)) } }
            }
            Section("主要肌群 · 至少选择一个") { MuscleSelectionList(selection: Binding(get: { Set(exercise.primary) }, set: { values in
                let secondary = exercise.secondary.filter { !values.contains($0) }
                exercise.primary = values.sorted { $0.rawValue < $1.rawValue }; exercise.secondary = secondary
            })) }
            Section("次要肌群 · 可选") { MuscleSelectionList(selection: Binding(get: { Set(exercise.secondary) }, set: { exercise.secondary = $0.subtracting(exercise.primary).sorted { $0.rawValue < $1.rawValue } })) }
            if exercise.tracking == .weightReps {
                Section {
                    Toggle("此动作适合估算 1RM", isOn: $exercise.allowsEstimate)
                    Text("仅在动作技术稳定、外部负重口径固定、1–10 次且 RPE ≥8 或 RIR ≤2 时估算。开启前请确认该公式对你记录的动作有意义。").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section { Text("更改名称或肌群分类不会重写历史训练。改变器械或负重口径后，不与旧口径直接比较。").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle(exercise.name.isEmpty ? "自定义动作" : "编辑动作").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                do { exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines); try store.saveExercise(exercise); dismiss() }
                catch { errorMessage = error.localizedDescription }
            } }
        }
        .onChange(of: exercise.tracking) { _, mode in
            switch mode { case .weightReps: exercise.loading = .total; case .bodyweightReps: exercise.loading = .bodyweight; case .assistedReps: exercise.loading = .assistance; case .duration: exercise.loading = .timeOnly }
            if mode != .weightReps { exercise.allowsEstimate = false }
        }.errorAlert($errorMessage)
    }
}

