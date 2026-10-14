import SwiftUI
import Observation
import TrainLogCore

enum AppTab: Hashable { case overview, workout, trends, strength }
struct SessionRoute: Identifiable { var id: UUID }
@MainActor @Observable final class AppRouter {
    var tab: AppTab = .overview
    var editing: Session?
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
        .sheet(isPresented: $settingsPresented) { NavigationStack { SettingsView() } }
        .sheet(item: $router.editing, onDismiss: {
            if let id = router.pendingSummary { router.pendingSummary = nil; router.summary = SessionRoute(id: id) }
        }) { session in
            NavigationStack {
                WorkoutEditorView(session: session) { id in router.pendingSummary = id; router.editing = nil }
            }.environment(router).interactiveDismissDisabled()
        }
        .sheet(item: $router.summary) { route in NavigationStack { WorkoutSummaryView(sessionID: route.id) } }
        .fullScreenCover(isPresented: Binding(get: { !store.settings.hasOnboarded }, set: { _ in })) { OnboardingView() }
        .errorAlert($store.errorMessage)
        .environment(clock)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            clock.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)); try Task.checkCancellation() } catch { return }
                clock.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in clock.refresh() }
    }
}

