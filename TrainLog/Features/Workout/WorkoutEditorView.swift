import SwiftUI
import TrainLogCore

struct WorkoutEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var session: Session
    @State private var restTimer: RestTimer
    @State private var draftSave: DraftSaveController
    @State private var recentExercises = RecentExerciseIndex(sessions: [])
    private let editingHistory: Bool
    private let originalSession: Session
    var onFinished: (UUID) -> Void
    @State private var bodyView = BodyView.front
    @State private var showingLibrary = false
    @State private var discardConfirmation = false
    @State private var discardEditsConfirmation = false
    @State private var errorMessage: String?
    @State private var saving = false
    init(session: Session, onFinished: @escaping (UUID) -> Void) {
        _session = State(initialValue: session); _restTimer = State(initialValue: RestTimer(sessionID: session.id))
        _draftSave = State(initialValue: DraftSaveController(saved: session))
        editingHistory = session.status == .completed; originalSession = session; self.onFinished = onFinished
    }
    private var selection: Binding<Set<MuscleGroup>> {
        Binding(get: { Set(session.quickEntries.map(\.muscle)) }, set: { values in
            session.quickEntries = values.sorted { $0.rawValue < $1.rawValue }.map { muscle in session.quickEntries.first { $0.muscle == muscle } ?? QuickEntry(muscle: muscle) }
        })
    }
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            LazyVStack(spacing: 18) {
                if !editingHistory && session.mode != .quick { sessionTimer }
                if session.mode == .detailed { detailedExercises }
                if !editingHistory && session.mode == .detailed {
                    LinkedWatchDraftCard(session: $session) { try draftSave.flush(session, save: store.save) }
                }
                AppCard {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("训练日期").font(.headline)
                        DatePicker("训练日期", selection: $session.date, in: ...max(clock.now, session.date), displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden()
                            .frame(maxWidth: .infinity).clipped()
                    } else {
                        DatePicker("训练日期", selection: $session.date, in: ...max(clock.now, session.date), displayedComponents: [.date, .hourAndMinute])
                    }
                    if editingHistory { Text("历史修改只有在点击保存后才生效；返回会保留原记录。").font(.caption).foregroundStyle(.secondary) }
                    else {
                        Text(draftSave.message).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("draftStatus")
                        if case .failed = draftSave.state { Button("重试保存") { persistDraft(showError: true) } }
                    }
                }
                if session.mode == .quick { quickSelection }
                else if session.mode == .cardio {
                    CardioEditorCard(activity: Binding(get: { session.activity ?? ActivityRecord() }, set: { session.activity = $0 }))
                }
                AppCard {
                    SectionHeader(title: "训练感受", subtitle: "可选 · 缺失信息不会被推算")
                    Picker("主观强度", selection: $session.intensity) {
                        Text("未填写").tag(Optional<Intensity>.none)
                        ForEach(Intensity.allCases) { Text($0.name).tag(Optional($0)) }
                    }
                    HStack { Text("整次训练 RPE"); Spacer(); OptionalNumberField(title: "1–10，可留空", value: $session.sessionRPE).frame(maxWidth: 150) }
                    if editingHistory || session.mode != .detailed {
                        HStack { Text("手动时长（分钟）"); Spacer(); OptionalNumberField(title: "使用计时", value: durationMinutes).frame(maxWidth: 140).accessibilityIdentifier("workout.manualMinutes") }
                    }
                    TextField("训练备注", text: $session.notes, axis: .vertical).lineLimit(2...5).accessibilityIdentifier("workout.notes")
                }
                if !editingHistory {
                    Button("放弃这份草稿", role: .destructive) { discardConfirmation = true }.frame(minHeight: 44)
                }
                Text(session.mode == .cardio ? "运动记录计入训练日历、次数和时长，不换算为力量组数、肌群覆盖或 e1RM。" : "仅已完成正式组计入组数、容量与力量统计。递减组只参与肌群覆盖，热身与失败组不参与统计。").font(.caption).foregroundStyle(.secondary)
            }.frame(width: max(0, geometry.size.width - 40)).padding(20)
        }
        // Keep focused numeric rows above the floating system keyboard toolbar.
        // This is a scroll safe-area inset, not a keyboard-height observer/timer.
        .safeAreaPadding(.bottom, 56)
        }
        .background(AppTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(editingHistory ? "编辑训练" : session.mode == .cardio ? "运动记录" : session.mode == .quick ? "快速记录" : "正在训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button(editingHistory ? "取消" : "稍后继续") { close() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) { Button(editingHistory ? "保存" : "结束训练") { finish() }.disabled(saving).accessibilityIdentifier("finishWorkout") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
        .nativeBottomBar {
            WorkoutFloatingBar(session: session, timer: restTimer) { entryID, setID in
                setAction(entryID: entryID, setID: setID, action: .complete)
            }
        }
        .sheet(isPresented: $showingLibrary) {
            NavigationStack { ExerciseLibraryView { exercise in
                var set = TrainingSet(); set.restSeconds = store.settings.restSeconds
                session.exercises.append(ExerciseEntry(exercise: exercise, sets: [set])); showingLibrary = false
            } }
        }
        .confirmationDialog(session.watchLink?.ownsHealthRecord == true ? "放弃手机草稿？手表健康记录保留；未结束的采集需在手表结束。" : "放弃草稿？已填写但未保存为完成训练的数据将删除。", isPresented: $discardConfirmation, titleVisibility: .visible) {
            Button("放弃草稿", role: .destructive) {
                saving = true
                do { try store.deleteSession(session.id); draftSave.stop(); restTimer.cancel(); dismiss() } catch { errorMessage = error.localizedDescription; saving = false }
            }
        }
        .errorAlert($errorMessage)
        .confirmationDialog("放弃本次修改？原训练记录会保留。", isPresented: $discardEditsConfirmation, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) { dismiss() }
        }
        .onAppear {
            recentExercises = RecentExerciseIndex(sessions: store.completed, excluding: session.id)
            if !editingHistory && !saving { draftSave.schedule(session, save: store.save) }
        }
        .onChange(of: session) { _, value in if !editingHistory && !saving { draftSave.schedule(value, save: store.save) } }
        .onChange(of: store.completed) { _, records in recentExercises = RecentExerciseIndex(sessions: records, excluding: session.id) }
        .onChange(of: store.draft?.watchLink) { _, link in
            if store.draft?.id == session.id, session.watchLink != link { session.watchLink = link }
        }
        .onDisappear { if !editingHistory && !saving { persistDraft(showError: false) }; draftSave.cancelPending() }
        .onChange(of: scenePhase) { _, phase in if phase != .active && !editingHistory && !saving { persistDraft(showError: false) } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Commit queued text before SwiftUI schedules a later scene update.
            // Unchanged snapshots are deduplicated by the existing save controller.
            if !editingHistory && !saving { persistDraft(showError: false) }
        }
        .onChange(of: restTimer.deadline) { _, _ in
            if !editingHistory && !saving { store.refreshSurfaces() }
        }
        .onReceive(NotificationCenter.default.publisher(for: RestTimer.endRequested)) { notification in
            if notification.object as? UUID == session.id { restTimer.cancel() }
        }
        .onChange(of: session.intensity) { _, value in
            // The global picker explicitly replaces older per-muscle quick intensities when edited.
            for index in session.quickEntries.indices { session.quickEntries[index].intensity = value }
        }
    }
    private var durationMinutes: Binding<Double?> {
        Binding(get: { session.manualDurationSeconds.map { Double($0) / 60 } }, set: { v in
            session.manualDurationSeconds = v.map { $0.isFinite && (0...10080).contains($0) ? Int(($0 * 60).rounded()) : -1 }
        })
    }
    private var sessionTimer: some View {
        AppCard {
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
                layout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.timerStartedAt == nil ? "训练计时 · 已暂停" : "训练计时").font(.caption).foregroundStyle(.secondary)
                        SessionElapsedLabel(session: session)
                    }
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Button {
                        if session.timerStartedAt == nil { session.resume() }
                        else { session.pause() }
                        persistDraft(showError: true)
                    } label: { Image(systemName: session.timerStartedAt == nil ? "play.fill" : "pause.fill").nativeSymbolTransition().nativeMotion(value: session.timerStartedAt == nil).frame(width: 44, height: 44) }.buttonStyle(.bordered).accessibilityLabel(session.timerStartedAt == nil ? "继续计时" : "暂停计时").accessibilityIdentifier("workout.toggleTimer")
                }
            if session.mode == .detailed {
            let sets = session.exercises.flatMap(\.sets)
            LabeledContent("已记录组数", value: "\(sets.filter(\.isCompleted).count) / \(sets.count) 组").font(.subheadline).nativeNumberTransition(value: "\(sets.filter(\.isCompleted).count)/\(sets.count)").accessibilityIdentifier("workout.setProgress")
            let restLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            restLayout {
                Text("组间休息").font(.subheadline)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Menu {
                    ForEach([60, 90, 120, 180], id: \.self) { seconds in Button("\(seconds) 秒") { restTimer.start(seconds: seconds, notify: store.settings.notifyRest) } }
                    Button("使用自定义 \(store.settings.restSeconds) 秒") { restTimer.start(seconds: store.settings.restSeconds, notify: store.settings.notifyRest) }
                } label: { Label("开始计时", systemImage: "timer") }.accessibilityIdentifier("startRestTimer")
            }
            if let warning = restTimer.notificationError { Text("提醒未能安排：\(warning)。屏幕计时仍可使用。").font(.caption).foregroundStyle(.orange) }
            }
        }
    }
    private var quickSelection: some View {
        AppCard {
            SectionHeader(title: "这次练了哪里？", subtitle: "点击人体或下方标签，可多选")
            Picker("人体视角", selection: $bodyView) { ForEach(BodyView.allCases) { Text($0.name).tag($0) } }.pickerStyle(.segmented)
            BodyMuscleMapView(view: bodyView, levels: Dictionary(uniqueKeysWithValues: selection.wrappedValue.map { ($0, 3) }), selected: selection.wrappedValue) { muscle in
                var value = selection.wrappedValue
                if value.contains(muscle) { value.remove(muscle) } else { value.insert(muscle) }; selection.wrappedValue = value
            }.frame(height: 340).frame(maxWidth: .infinity)
            MuscleSelectionList(selection: selection)
        }
        .sensoryFeedback(.selection, trigger: selection.wrappedValue)
    }
    private var detailedExercises: some View {
        LazyVStack(spacing: 18) {
            if !editingHistory {
                if let plan = session.plan { Label(plan.name, systemImage: "calendar").font(.headline).frame(maxWidth: .infinity, alignment: .leading) }
                Text("边练边记：开始本组 → 填写重量与次数 → 结束本组。勾选完成也可直接补记，未计时不会推算用时。")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach($session.exercises) { $entry in
                ExerciseEditorCard(entry: $entry, previous: recentExercises.previous(for: entry.exercise), unit: store.settings.unit, live: !editingHistory, activeSetID: session.activeSet?.setID, onAction: { id, action in
                    setAction(entryID: entry.id, setID: id, action: action)
                }, onDelete: { let id = entry.id; session.exercises.removeAll { $0.id == id } })
            }
            if session.exercises.isEmpty { AppCard { EmptyStateView(title: "选择第一个动作", message: "从动作库添加，也可以创建你的专属动作。", symbol: "dumbbell") } }
            Button { showingLibrary = true } label: { Label("添加动作", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 52) }.buttonStyle(.bordered).accessibilityIdentifier("addExercise")
        }.nativeMotion(value: session.exercises.map(\.id))
    }
    private func setAction(entryID: UUID, setID: UUID, action: TrainingSetAction) {
        do {
            var next = session
            switch action {
            case .start:
                try next.startSet(entryID: entryID, setID: setID)
            case .complete:
                try next.completeSet(entryID: entryID, setID: setID)
            }
            if !editingHistory { try draftSave.flush(next, save: store.save) }
            session = next
            if !editingHistory {
                if case .start = action { restTimer.cancel() }
                else if let set = next.exercises.first(where: { $0.id == entryID })?.sets.first(where: { $0.id == setID }) { restTimer.start(seconds: set.restSeconds, notify: store.settings.notifyRest) }
            }
        } catch { errorMessage = error.localizedDescription }
    }
    private func persistDraft(showError: Bool) {
        guard !editingHistory, !saving, session.status == .draft else { return }
        do {
            try draftSave.flush(session, save: store.save)
        } catch {
            if showError { errorMessage = error.localizedDescription }
        }
    }
    private func close() {
        if editingHistory {
            if session != originalSession { discardEditsConfirmation = true } else { dismiss() }
            return
        }
        do { try draftSave.flush(session, save: store.save); draftSave.stop(); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
    private func finish() {
        if !editingHistory && session.activeSet != nil { errorMessage = "请先结束正在计时的本组，再结束整场训练。"; return }
        saving = true
        do {
            var value = session
            if !editingHistory { value.finish() } else { value.updatedAt = Date() }
            try store.save(value); draftSave.stop(); session = value; restTimer.cancel()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if editingHistory { dismiss() } else { onFinished(value.id) }
        } catch { errorMessage = error.localizedDescription; saving = false }
    }
}
struct RestTimerBanner: View {
    var timer: RestTimer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Label("组间休息", systemImage: "timer").font(.subheadline)
                    .accessibilityIdentifier("restTimer.label")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                RestCountdownLabel(timer: timer)
                Button("结束") { timer.cancel() }.frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("restTimer.end")
            }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// System-managed timer text updates without reevaluating the editor or its
/// glass controls every second. Paused and manually entered time remain static.
struct SessionElapsedLabel: View {
    var session: Session
    var body: some View {
        Group {
            if session.manualDurationSeconds == nil, let running = session.timerStartedAt {
                let start = running.addingTimeInterval(-session.accumulatedSeconds)
                Text(timerInterval: start...max(start, .distantFuture), countsDown: false, showsHours: true)
            } else {
                Text(Duration.seconds(session.elapsed()).formatted(.time(pattern: .hourMinuteSecond)))
            }
        }.font(.title2.weight(.semibold)).monospacedDigit()
            .transaction { $0.animation = nil }
            .accessibilityIdentifier("workout.elapsed")
    }
}

private struct RestCountdownLabel: View {
    var timer: RestTimer
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(timer.remaining(at: context.date)) 秒").font(.headline).monospacedDigit()
                .accessibilityIdentifier("restTimer.remaining")
                .transaction { $0.animation = nil }
                .onChange(of: context.date) { _, now in timer.tick(at: now) }
        }
    }
}

/// One stable glass surface changes contents between a live set and its rest.
/// The timer text owns its updates; the editor is never animated on every tick.
private struct WorkoutFloatingBar: View {
    var session: Session
    var timer: RestTimer
    var finishSet: (UUID, UUID) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var active: (entry: ExerciseEntry, set: TrainingSet)? {
        guard let ids = session.activeSet,
              let entry = session.exercises.first(where: { $0.id == ids.entryID }),
              let set = entry.sets.first(where: { $0.id == ids.setID }) else { return nil }
        return (entry, set)
    }
    // Identity is the visible mode, never elapsed seconds, text input or a new deadline.
    private var mode: Int { active != nil ? 1 : timer.deadline != nil ? 2 : 0 }
    var body: some View {
        VStack(spacing: 0) {
            if mode != 0 {
                VStack(alignment: .leading, spacing: 8) {
                    if let active, let timing = active.set.timing {
                        Text(active.entry.exercise.name + (timing.timerStartedAt == nil ? " · 本组已暂停" : " · 本组进行中"))
                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("activeSet.status")
                        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                        layout {
                            SetElapsedLabel(timing: timing).font(.headline)
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            Button("结束本组") { finishSet(active.entry.id, active.set.id) }
                                .frame(minHeight: 44).accessibilityIdentifier("activeSet.finish")
                        }
                    } else { RestTimerBanner(timer: timer) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(NativeFloatingSurface())
                .padding(.horizontal).padding(.bottom, 8)
                .transition(.opacity)
            }
        }.nativeMotion(value: mode)
    }
}
