import SwiftUI
import TrainLogCore

@main struct TrainLogApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView().environment(store)
                        .preferredColorScheme(store.settings.theme == .system ? nil : store.settings.theme == .dark ? .dark : .light)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("暂时无法读取训练档案", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("原始数据库已保留，没有重置或覆盖。\n\(startupError)")
                    } actions: { Button("重新尝试", action: load).buttonStyle(.borderedProminent) }
                } else { LoadingStateView() }
            }.tint(.blue).task { if store == nil && startupError == nil { load() } }
        }
    }
    private func load() {
        do {
            #if DEBUG
            let inMemory = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            #else
            let inMemory = false
            #endif
            store = try AppStore(inMemory: inMemory); startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}

