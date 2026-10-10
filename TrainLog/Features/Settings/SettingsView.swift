import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import TrainLogCore

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct ImportCandidate: Identifiable { var id = UUID(); var backup: Backup }
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var exportDocument: ExportDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = "TrainLog-backup"
    @State private var sharingURL: URL?
    @State private var importing = false
    @State private var reading = false
    @State private var candidate: ImportCandidate?
    @State private var errorMessage: String?
    @State private var notice: String?
    private func binding<T>(_ path: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: path] }, set: { value in
            var settings = store.settings; settings[keyPath: path] = value
            do { try store.updateSettings(settings) } catch { errorMessage = error.localizedDescription }
        })
    }
    var body: some View {
        Form {
            Section("训练偏好") {
                Picker("重量单位", selection: binding(\.unit)) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }
                Stepper("每周目标 \(store.settings.weeklyGoal) 次", value: binding(\.weeklyGoal), in: 1...14)
                Picker("训练目标", selection: binding(\.trainingGoal)) { ForEach(["保持规律", "提升力量", "增加肌肉", "记录与观察"], id: \.self) { Text($0).tag($0) } }
                Picker("外观", selection: binding(\.theme)) { ForEach(ThemePreference.allCases) { Text($0.name).tag($0) } }
                NavigationLink("体重与历史") { BodyWeightHistoryView() }
            }
            Section("组间休息") {
                Picker("常用时间", selection: binding(\.restSeconds)) {
                    ForEach(Array(Set([60, 90, 120, 180, store.settings.restSeconds])).sorted(), id: \.self) { Text("\($0) 秒").tag($0) }
                }
                Stepper("自定义 \(store.settings.restSeconds) 秒", value: binding(\.restSeconds), in: 0...3600, step: 15)
                Toggle("休息结束时通知", isOn: Binding(get: { store.settings.notifyRest }, set: { enabled in setNotification(enabled) }))
                Text("通知为可选权限。拒绝通知后仍可使用全部记录与计时功能。").font(.caption).foregroundStyle(.secondary)
            }
            Section("数据备份") {
                Button("导出完整 JSON 备份", systemImage: "square.and.arrow.up") { prepareExport(csv: false) }
                Button("导出 CSV 训练明细", systemImage: "tablecells") { prepareExport(csv: true) }
                Button("导入 JSON 备份", systemImage: "square.and.arrow.down") { importing = true }.disabled(reading)
                if reading { ProgressView("正在校验备份…") }
                if let sharingURL { ShareLink(item: sharingURL) { Label("使用系统分享面板分享最近导出", systemImage: "square.and.arrow.up.on.square") } }
                if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                Text("训练与设置均保存在本机。请定期导出 JSON。CSV 用于分析，不作为完整恢复备份。导入前会生成恢复副本。").font(.caption).foregroundStyle(.secondary)
            }
            Section("关于") {
                NavigationLink("数据统计说明") { DataRulesView() }
                NavigationLink("隐私说明") { PrivacyView() }
                LabeledContent("TrainLog", value: "1.0 · 本地优先")
                Text("记录每一次训练，看见每一点进步。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
                switch result { case .success: notice = "文件已导出。"; case .failure(let error): errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): readImport(url)
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $candidate) { item in NavigationStack { ImportReviewView(incoming: item.backup) } }
            .errorAlert($errorMessage)
    }
    private func prepareExport(csv: Bool) {
        do {
            let data = try csv ? Data(BackupService.csv(store.sessions).utf8) : BackupService.encode(store.backup)
            exportType = csv ? .commaSeparatedText : .json
            exportName = "TrainLog-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))-\(csv ? "details" : "backup")"
            exportDocument = ExportDocument(data: data)
            let directory = URL.cachesDirectory.appending(path: "Exports", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: exportName + (csv ? ".csv" : ".json"))
            try data.write(to: url, options: [.atomic, .completeFileProtection]); sharingURL = url
            exporting = true
        } catch { errorMessage = error.localizedDescription }
    }
    private func readImport(_ url: URL) {
        reading = true
        Task { @MainActor in
            do {
                let backup = try await Task.detached(priority: .userInitiated) {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= BackupService.maximumBytes else { throw ValidationError("备份超过 32 MB。") }
                    return try BackupService.decode(Data(contentsOf: url, options: .mappedIfSafe))
                }.value
                candidate = ImportCandidate(backup: backup)
            } catch { errorMessage = error.localizedDescription }
            reading = false
        }
    }
    private func setNotification(_ enabled: Bool) {
        if !enabled {
            binding(\.notifyRest).wrappedValue = false
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                binding(\.notifyRest).wrappedValue = granted
                if !granted { notice = "通知未获授权。可在 iOS 设置中为 TrainLog 开启；训练功能不受影响。" }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
struct ImportReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var incoming: Backup
    @State private var replace = false
    @State private var confirming = false
    @State private var errorMessage: String?
    @State private var recoveryURL: URL?
    @State private var finished = false
    var body: some View {
        Form {
            Section("已通过格式与关联校验") {
                LabeledContent("备份版本", value: "\(incoming.schemaVersion)")
                LabeledContent("训练记录", value: "\(incoming.sessions.count)")
                LabeledContent("动作", value: "\(incoming.exercises.count)")
                LabeledContent("模板", value: "\(incoming.templates.count)")
                LabeledContent("体重记录", value: "\(incoming.bodyWeights.count)")
                Text("相同 ID 的训练记录：\(Set(incoming.sessions.map(\.id)).intersection(store.sessions.map(\.id)).count) 条").font(.caption)
            }
            if !finished {
                Section {
                    Picker("导入方式", selection: $replace) { Text("合并").tag(false); Text("替换全部").tag(true) }.pickerStyle(.segmented)
                    Text(replace ? "替换当前全部训练、动作、模板、体重及设置。写入前会保存本机恢复副本，并再次确认。" : "保留当前设置；相同 ID 保留本机版本，不重复导入。若双方各有不同草稿，请先完成或放弃其中一份。").font(.subheadline).foregroundStyle(.secondary)
                    Button(replace ? "替换并导入…" : "合并导入") { if replace { confirming = true } else { runImport() } }
                }
            } else {
                Section { Label("导入完成，统计已更新", systemImage: "checkmark.circle.fill").foregroundStyle(.green); if let recoveryURL { ShareLink("保存导入前的恢复副本", item: recoveryURL) } }
            }
        }.navigationTitle("导入预览").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(finished ? "完成" : "取消") { dismiss() } }
            .confirmationDialog("确认替换全部本地数据？", isPresented: $confirming, titleVisibility: .visible) { Button("保存恢复副本并替换", role: .destructive) { runImport() } }
            .errorAlert($errorMessage)
    }
    private func runImport() {
        do { recoveryURL = try store.importBackup(incoming, mode: replace ? .replace : .merge); finished = true }
        catch { errorMessage = error.localizedDescription }
    }
}

