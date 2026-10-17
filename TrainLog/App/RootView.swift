import SwiftUI
import Observation
import TrainLogCore

enum AppTab: Hashable { case overview, workout, trends, strength }
struct SessionRoute: Identifiable { var id: UUID }
@MainActor @Observable final class AppRouter {
    var tab: AppTab = .overview
    var editing: Session?
    var calendarPresented = false
    var summary: SessionRoute?
    var pendingSummary: UUID?
    func start(_ mode: WorkoutMode, store: AppStore, template: TrainingTemplate? = nil) {
        if let draft = store.draft { editing = draft; return }
        do {
            let session = try template.map { try ExerciseCatalog.session(from: $0, catalog: store.exercises) } ?? Session(mode: mode)
            try store.save(session); editing = session
        } catch { store.errorMessage = error.localizedDescription }
    }
}
struct RootView: View {
    @Binding var pendingURL: URL?
    @Environment(AppStore.self) private var store
    @State private var router = AppRouter()
    @State private var clock = AppClock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsPresented = false
    var body: some View {
        @Bindable var store = store
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("概览", systemImage: "square.grid.2x2.fill", value: AppTab.overview) {
                NavigationStack { OverviewView { settingsPresented = true }.fitnessCalendarAccess() }
            }
            Tab("训练", systemImage: "dumbbell.fill", value: AppTab.workout) {
                NavigationStack { WorkoutHomeView().fitnessCalendarAccess() }
            }
            Tab("趋势", systemImage: "chart.xyaxis.line", value: AppTab.trends) {
                NavigationStack { TrendsView().fitnessCalendarAccess() }
            }
            Tab("能力", systemImage: "trophy.fill", value: AppTab.strength) {
                NavigationStack { StrengthView().fitnessCalendarAccess() }
            }
        }
        .environment(router)
        .sheet(isPresented: $settingsPresented, onDismiss: routePendingURL) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $router.calendarPresented, onDismiss: routePendingURL) { NavigationStack { FitnessCalendarView() } }
        .sheet(item: $router.editing, onDismiss: {
            if let id = router.pendingSummary { router.pendingSummary = nil; router.summary = SessionRoute(id: id) }
        }) { session in
            NavigationStack {
                WorkoutEditorView(session: session) { id in router.pendingSummary = id; router.editing = nil }
            }.environment(router).interactiveDismissDisabled()
        }
        .sheet(item: $router.summary, onDismiss: routePendingURL) { route in NavigationStack { WorkoutSummaryView(sessionID: route.id) } }
        .fullScreenCover(isPresented: Binding(get: { !store.settings.hasOnboarded }, set: { _ in }), onDismiss: routePendingURL) { OnboardingView() }
        .errorAlert($store.errorMessage)
        .environment(clock)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            clock.refresh()
            store.refreshSurfaces()
            await Task.yield()
            guard !Task.isCancelled else { return }
            store.health.refresh(sessions: store.sessions)
            routePendingURL()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)); try Task.checkCancellation() } catch { return }
                clock.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in clock.refresh() }
        // A cold-launch URL can arrive before this view is created. A task
        // also handles its initial value after the root has joined the scene.
        .task(id: pendingURL) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            routePendingURL()
        }
    }
    private func routePendingURL() {
        #if DEBUG
        if pendingURL != nil, ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            NSLog("TrainLog UI URL route: active=%d onboarded=%d settings=%d calendar=%d", scenePhase == .active, store.settings.hasOnboarded, settingsPresented, router.calendarPresented)
        }
        #endif
        guard scenePhase == .active, store.settings.hasOnboarded, let url = pendingURL else { return }
        guard let route = WorkoutDeepLink(url: url) else { pendingURL = nil; return }
        guard router.editing == nil else { pendingURL = nil; return }
        // Wait for modal dismissal before presenting another destination.
        if settingsPresented { settingsPresented = false; return }
        if router.summary != nil { router.summary = nil; return }
        if router.calendarPresented && route != .calendar { router.calendarPresented = false; return }
        pendingURL = nil
        switch route {
        case .overview: router.tab = .overview
        case .calendar:
            // Avoid dismissing an editor with unsaved fields to show a calendar.
            guard router.editing == nil else { return }
            router.calendarPresented = true
        case .workout(let id):
            router.tab = .workout
            guard router.editing == nil else { return }
            if let id {
                if let draft = store.draft, draft.id == id { router.editing = draft }
                // A stale widget must never create a replacement workout implicitly.
            } else { router.start(.detailed, store: store) }
        }
    }
}

