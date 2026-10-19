import SwiftUI
import UIKit
import TrainLogCore

struct FitnessCalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppClock.self) private var clock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealRequest = 0
    @State private var creatingPlan: TrainingPlan?
    @SceneStorage("fitnessCalendar.selectedDate") private var selectedTimestamp = Date().timeIntervalSince1970
    private var selectedDate: Binding<Date> {
        Binding(get: { Date(timeIntervalSince1970: selectedTimestamp) }, set: { selectedTimestamp = $0.timeIntervalSince1970 })
    }
    var body: some View {
        let calendar = clock.calendar
        let index = WorkoutCalendarIndex(sessions: store.sessions, calendar: calendar)
        let date = selectedDate.wrappedValue
        let records = index.records(on: date)
        let plans = store.plans.filter { calendar.isDate($0.scheduledAt, inSameDayAs: date) }
        let plannedDays = Set(store.plans.filter { plan in !plan.isSkipped && !store.sessions.contains(where: { $0.plan?.id == plan.id }) }.map { calendar.startOfDay(for: $0.scheduledAt) })
        ScrollViewReader { scroll in
        List {
            Section {
                NativeWorkoutCalendar(selectedDate: selectedDate, index: index, plannedDays: plannedDays, revealRequest: revealRequest)
                    .id(String(describing: calendar.identifier) + calendar.timeZone.identifier)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .id("calendar.top")
                DatePicker("跳转日期", selection: selectedDate, displayedComponents: .date)
                    .accessibilityIdentifier("calendar.datePicker")
            } footer: {
                Text("蓝点为已完成训练，橙点为待训练计划；同日优先显示蓝点。可查看任意日期，按当前时区归属。")
            }
            Section {
                HStack {
                    Button { selectedDate.wrappedValue = index.adjacentDay(to: date, offset: -1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("前一天").accessibilityIdentifier("calendar.previousDay")
                    Spacer(minLength: 0)
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.headline).multilineTextAlignment(.center)
                        .accessibilityIdentifier("calendar.selectedDay")
                    Spacer(minLength: 0)
                    Button { selectedDate.wrappedValue = index.adjacentDay(to: date, offset: 1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }.accessibilityLabel("后一天").accessibilityIdentifier("calendar.nextDay")
                }.buttonStyle(.borderless)
                if records.isEmpty {
                    ContentUnavailableView("这一天没有训练记录", systemImage: "calendar", description: Text("选择其他日期查看记录。过去的训练可在训练页补记。"))
                        .accessibilityIdentifier("calendar.emptyDay")
                } else {
                    ForEach(records) { session in
                        NavigationLink { SessionDetailView(sessionID: session.id) } label: { SessionRow(session: session) }
                    }
                }
            } header: { Text("当天训练 · \(records.count) 次").accessibilityIdentifier("calendar.dayCount") }
            Section("当天计划 · \(plans.count) 项") {
                ForEach(plans) { plan in NavigationLink { TrainingPlanDetailView(planID: plan.id) } label: { TrainingPlanRow(plan: plan) } }
                Button("安排这一天的训练", systemImage: "calendar.badge.plus") { creatingPlan = TrainingPlan(scheduledAt: date) }.accessibilityIdentifier("calendar.planDay")
            }
        }
        .navigationTitle("健身日历")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $creatingPlan) { plan in NavigationStack { TrainingPlanEditorView(plan: plan) } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("calendar.close") }
            ToolbarItem(placement: .primaryAction) {
                Button("今天") {
                    selectedDate.wrappedValue = clock.now
                    revealRequest += 1
                    withAnimation(reduceMotion ? nil : .smooth) { scroll.scrollTo("calendar.top", anchor: .top) }
                }.accessibilityIdentifier("calendar.today")
            }
        }
        }
    }
}

/// UIKit supplies month/year navigation, selection animation, Dynamic Type and VoiceOver.
struct NativeWorkoutCalendar: UIViewRepresentable {
    @Binding var selectedDate: Date
    var index: WorkoutCalendarIndex
    var plannedDays: Set<Date> = []
    var revealRequest = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = index.calendar
        view.locale = .autoupdatingCurrent
        view.timeZone = index.calendar.timeZone
        view.availableDateRange = DateInterval(start: .distantPast, end: .distantFuture)
        view.fontDesign = .default
        view.delegate = context.coordinator
        view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.accessibilityIdentifier = "calendar.native"
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }
    func updateUIView(_ view: UICalendarView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if view.calendar != index.calendar { view.calendar = index.calendar }
        let day = index.calendar.startOfDay(for: selectedDate)
        if coordinator.selection != day || coordinator.revealRequest != revealRequest {
            let animated = coordinator.selection != nil && !reduceMotion
            coordinator.selection = day
            coordinator.revealRequest = revealRequest
            let components = index.calendar.dateComponents([.era, .year, .month, .day], from: day)
            (view.selectionBehavior as? UICalendarSelectionSingleDate)?.setSelected(components, animated: animated)
            view.setVisibleDateComponents(components, animated: animated)
        }
        let newDays = index.recordedDays
        let changed = coordinator.decoratedDays.symmetricDifference(newDays).union(coordinator.plannedDays.symmetricDifference(plannedDays))
        coordinator.decoratedDays = newDays
        coordinator.plannedDays = plannedDays
        if !changed.isEmpty {
            view.reloadDecorations(forDateComponents: changed.map { index.calendar.dateComponents([.era, .year, .month, .day], from: $0) }, animated: !reduceMotion)
        }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: NativeWorkoutCalendar
        var selection: Date?
        var revealRequest = 0
        var decoratedDays: Set<Date> = []
        var plannedDays: Set<Date> = []
        init(_ parent: NativeWorkoutCalendar) { self.parent = parent }
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = parent.index.calendar.date(from: dateComponents) else { return }
            self.selection = parent.index.calendar.startOfDay(for: date)
            parent.selectedDate = date
        }
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = parent.index.calendar.date(from: dateComponents) else { return nil }
            if parent.index.count(on: date) > 0 { return .default(color: .systemBlue, size: .small) }
            return parent.plannedDays.contains(parent.index.calendar.startOfDay(for: date)) ? .default(color: .systemOrange, size: .small) : nil
        }
    }
}

struct FitnessCalendarAccess: ViewModifier {
    @Environment(AppRouter.self) private var router
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.calendarPresented = true } label: { Label("健身日历", systemImage: "calendar") }
                    .accessibilityIdentifier("openFitnessCalendar")
            }
        }
    }
}
extension View {
    func fitnessCalendarAccess() -> some View { modifier(FitnessCalendarAccess()) }
}
