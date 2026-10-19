import SwiftUI
import TrainLogCore

struct TrainingReviewCard: View {
    @Environment(AppStore.self) private var store
    var session: Session
    @State private var copied: TrainingPlan?
    @State private var issue: String?
    var body: some View {
        if session.status == .completed && session.plan != nil {
            AppCard {
                SectionHeader(title: "计划与实际", subtitle: "目标保留开练时快照，后续改计划不改写本次对照。")
                if let review = PlanReviewService.review(session) {
                    LabeledContent("预设组 / 完成正式组", value: "\(review.plannedSets) / \(review.completedWorkingSets)")
                    LabeledContent("配置变化的组", value: "\(review.changedSets)")
                    NavigationLink("逐组查看对照") { TrainingReviewDetailView(sessionID: session.id) }
                        .accessibilityIdentifier("review.details")
                } else { Text("这条旧记录没有开练时目标快照，无法还原当时计划。实际训练记录保留。").font(.subheadline).foregroundStyle(.secondary) }
                Button("按实际创建下次计划", systemImage: "calendar.badge.plus") {
                    do { copied = try PlanReviewService.copiedPlan(from: session, scheduledAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(), catalog: store.exercises) }
                    catch { issue = error.localizedDescription }
                }.accessibilityIdentifier("review.copyActual")
                Text("只复制已完成正式组；保留不同重量与次数配置。先预览、修改日期，再保存新计划。").font(.caption).foregroundStyle(.secondary)
            }
            .sheet(item: $copied) { plan in NavigationStack { TrainingPlanEditorView(plan: plan) } }
            .errorAlert($issue)
        }
    }
}
struct TrainingReviewDetailView: View {
    @Environment(AppStore.self) private var store
    var sessionID: UUID
    var body: some View {
        if let session = store.completed.first(where: { $0.id == sessionID }), let review = PlanReviewService.review(session) {
            List {
                Section {
                    LabeledContent("预设组", value: "\(review.plannedSets)")
                    LabeledContent("完成正式组", value: "\(review.completedWorkingSets)")
                    LabeledContent("已计时完成组", value: "\(review.timedCompletedSets)")
                    LabeledContent("未计时完成组", value: "\(review.untimedCompletedSets)").accessibilityElement(children: .ignore).accessibilityIdentifier("review.untimedCount").accessibilityLabel("未计时完成组").accessibilityValue("\(review.untimedCompletedSets)")
                    LabeledContent("已记录组用时合计", value: Duration.seconds(review.recordedSetSeconds).formatted(.time(pattern: .hourMinuteSecond)))
                } footer: { Text("组用时仅累加真实启动并完成的计时。整场用时与组用时的差额不当作实际休息时间。") }
                ForEach(review.exercises) { entry in
                    Section {
                        if entry.wasAdded { Label("临时新增动作", systemImage: "plus.circle") }
                        if entry.wasRemoved { Label("训练中移除动作", systemImage: "minus.circle") }
                        if entry.conventionChanged, let actual = entry.actualExercise { Text("实际动作：" + actual.name + " · " + actual.loading.name).font(.subheadline).foregroundStyle(.secondary) }
                        ForEach(entry.sets) { row in
                            VStack(alignment: .leading, spacing: 7) {
                                Text("第 \(row.number) 组 · " + (row.target == nil ? "临时新增" : row.actual == nil ? "已移除" : row.changed ? "配置有调整" : "配置未变")).font(.subheadline.weight(.semibold))
                                Text("计划：" + (row.target.map { reviewSetDescription($0, exercise: entry.exercise, unit: store.settings.unit) } ?? "无预设"))
                                Text("实际：" + (row.actual.map { reviewSetDescription($0, exercise: entry.actualExercise ?? entry.exercise, unit: store.settings.unit) + ($0.isCompleted ? " · 已完成" : " · 未完成") } ?? "未记录"))
                                if let target = row.target, let actual = row.actual, target.kind != actual.kind || target.restSeconds != actual.restSeconds {
                                    Text("计划：\(target.kind.name)组 · 休息目标\(target.restSeconds)秒；实际配置：\(actual.kind.name)组 · 休息目标\(actual.restSeconds)秒").font(.caption).foregroundStyle(.secondary)
                                }
                                if let actual = row.actual {
                                    Text("本组计时：" + (actual.timing.flatMap { timing in timing.endedAt.map { _ in Duration.seconds(timing.elapsed()).formatted(.time(pattern: .hourMinuteSecond)) } } ?? "未计时")).foregroundStyle(.secondary)
                                }
                            }.font(.subheadline).padding(.vertical, 4)
                        }
                    } header: { Text(entry.exercise.name + " · " + entry.exercise.loading.name) }
                }
            }.navigationTitle("计划与实际").navigationBarTitleDisplayMode(.inline)
        } else { ContentUnavailableView("暂无计划对照", systemImage: "list.clipboard", description: Text("旧记录没有开练时目标快照，或训练已删除。")) }
    }
}
func reviewSetDescription(_ set: TrainingSet, exercise: Exercise, unit: WeightUnit) -> String {
    if exercise.tracking == .duration { return set.durationSeconds.map { "\($0) 秒" } ?? "未设持续时长" }
    let reps = set.reps.map { "\($0) 次" } ?? "未设次数"
    if exercise.tracking == .bodyweightReps { return "自重 × " + reps }
    return (set.weightKg.map { unit.display($0).formattedValue + " " + unit.rawValue } ?? "未设重量") + " × " + reps
}

struct TargetSuggestionRequest: Identifiable {
    var id: UUID { item.id }
    var exercise: Exercise
    var item: TemplateItem
    var suggestion: TargetSuggestion
}
struct TargetSuggestionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var request: TargetSuggestionRequest
    var apply: (TemplateItem) throws -> Void
    @State private var weightKg: Double?
    @State private var reps: Double?
    @State private var issue: String?
    init(request: TargetSuggestionRequest, apply: @escaping (TemplateItem) throws -> Void) {
        self.request = request; self.apply = apply
        _weightKg = State(initialValue: request.suggestion.proposed?.weightKg)
        _reps = State(initialValue: request.suggestion.proposed?.reps.map(Double.init))
    }
    var body: some View {
        Form {
            Section {
                Text(request.exercise.name).font(.headline)
                Text(request.exercise.loading.name).font(.caption).foregroundStyle(.secondary)
                Text(request.suggestion.title).font(.headline).accessibilityIdentifier("suggestion.title")
                Text("当前目标：" + reviewSetDescription(TrainingSet(weightKg: request.item.weightKg, reps: request.item.reps), exercise: request.exercise, unit: store.settings.unit))
                ForEach(request.suggestion.reasons, id: \.self) { Text($0).font(.subheadline) }
            }
            if request.suggestion.canApply {
                Section("下次目标 · 可先修改") {
                    if request.exercise.tracking == .weightReps {
                        HStack { Text("重量（\(store.settings.unit.rawValue)）"); OptionalNumberField(title: "重量", value: Binding(get: { weightKg.map(store.settings.unit.display) }, set: { weightKg = $0.map(store.settings.unit.kilograms) })).accessibilityIdentifier("suggestion.weight") }
                    }
                    HStack { Text("次数"); OptionalNumberField(title: "次数", value: $reps, integer: true).accessibilityIdentifier("suggestion.reps") }
                    Text("按器械刻度和当日状态确认。只更新正在编辑的这一项预设，不改已完成训练，也不自动开练。").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("参考记录") {
                ForEach(request.suggestion.evidence) { evidence in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(evidence.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        Text("\(evidence.sets.count) 个可比完成正式组")
                        ForEach(Array(evidence.sets.enumerated()), id: \.element.id) { index, set in
                            Text("\(index + 1) · " + reviewSetDescription(set, exercise: request.exercise, unit: store.settings.unit) + " · RPE " + (set.rpe.map(\.formattedValue) ?? "未填") + " / RIR " + (set.rir.map(\.formattedValue) ?? "未填")).font(.caption)
                        }
                    }.padding(.vertical, 4)
                }
                if request.suggestion.evidence.isEmpty { Text("暂无足够的可比记录。") }
                Text("请确认参考记录中的强度确为当次感受。复制新组不会带入上次RPE/RIR。").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("这是可关闭的本地计划参考。60天、两次记录及强度门槛属于App规划规则，不是个人恢复或医学结论。").font(.caption).foregroundStyle(.secondary)
                Link("训练进阶与个体化依据（ACSM 2026）", destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/")!)
            }
        }.safeAreaPadding(.bottom, 56).navigationTitle("下次目标参考").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.accessibilityIdentifier("suggestion.cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    if request.suggestion.canApply {
                        Button("采用此项目标") {
                            do {
                                guard store.settings.showsTargetSuggestions else { throw ValidationError("目标建议已关闭。") }
                                guard let reps, reps.isFinite, reps.rounded() == reps, (1...1000).contains(reps) else { throw ValidationError("请填写有效的整数次数。") }
                                var next = request.item; next.weightKg = weightKg; next.reps = Int(reps)
                                try RecordValidator.trainingSet(TrainingSet(weightKg: next.weightKg, reps: next.reps), exercise: request.exercise, requireComplete: true)
                                try apply(next); dismiss()
                            } catch { issue = error.localizedDescription }
                        }.accessibilityIdentifier("suggestion.apply")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }.errorAlert($issue)
    }
}
