import SwiftUI
import TrainLogCore

@main struct TrainLogApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    @State private var pendingURL: URL?
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let store {
                    RootView(pendingURL: $pendingURL).environment(store)
                        .preferredColorScheme(store.settings.theme == .system ? nil : store.settings.theme == .dark ? .dark : .light)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("暂时无法读取训练档案", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("原始数据库已保留，没有重置或覆盖。\n\(startupError)")
                    } actions: { Button("重新尝试", action: load).buttonStyle(.borderedProminent) }
                } else { LoadingStateView() }
            }.tint(.blue).fontDesign(.default).task { if store == nil && startupError == nil { load() } }
                .onOpenURL {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-ui-testing") { NSLog("TrainLog UI URL received: %@", $0.absoluteString) }
                    #endif
                    pendingURL = $0
                }
        }
    }
    private func load() {
        do {
            #if DEBUG
            let inMemory = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            if inMemory, let value = ProcessInfo.processInfo.environment["TRAINLOG_UI_TEST_STORE"], let id = UUID(uuidString: value) {
                // A unique sandbox file lets URL-launch tests survive process
                // restarts without touching a real user's database or widgets.
                let url = FileManager.default.temporaryDirectory.appending(path: "ui-test-\(id.uuidString).store")
                store = try AppStore(storeURL: url); startupError = nil
                return
            }
            #else
            let inMemory = false
            #endif
            store = try AppStore(inMemory: inMemory); startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}

