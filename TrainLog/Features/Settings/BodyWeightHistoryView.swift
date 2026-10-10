import SwiftUI
import Charts
import TrainLogCore

struct BodyWeightHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: BodyWeight?
    @State private var deleting: BodyWeight?
    var body: some View {
        List {
            if !store.bodyWeights.isEmpty {
                Section("体重变化 · \(store.settings.unit.rawValue)") {
                    Chart(store.bodyWeights.sorted { $0.date < $1.date }) { value in
                        LineMark(x: .value("日期", value.date), y: .value("体重", store.settings.unit.display(value.weightKg))).foregroundStyle(.blue)
                        PointMark(x: .value("日期", value.date), y: .value("体重", store.settings.unit.display(value.weightKg))).foregroundStyle(.blue)
                    }.frame(height: 180)
                }
            }
            Section("记录") {
                ForEach(store.bodyWeights) { value in
                    Button { editing = value } label: { LabeledContent(value.date.formatted(date: .abbreviated, time: .shortened), value: "\(store.settings.unit.display(value.weightKg).formattedValue) \(store.settings.unit.rawValue)") }.buttonStyle(.plain)
                        .swipeActions { Button("删除", role: .destructive) { deleting = value } }
                }
                if store.bodyWeights.isEmpty { EmptyStateView(title: "体重是可选信息", message: "填写后可计算适用动作的相对力量。不会据此生成竞技等级标签。", symbol: "scalemass") }
            }
        }.navigationTitle("体重记录")
            .toolbar { Button { editing = BodyWeight(weightKg: 0) } label: { Image(systemName: "plus") }.accessibilityLabel("记录体重") }
            .sheet(item: $editing) { value in NavigationStack { BodyWeightEditor(value: value) } }
            .confirmationDialog("删除这条体重记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("删除", role: .destructive) { if let value = deleting { store.perform { try store.deleteWeight(value.id) } }; deleting = nil } }
    }
}
struct BodyWeightEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var value: BodyWeight
    @State private var entered: Double?
    @State private var errorMessage: String?
    var body: some View {
        Form {
            DatePicker("日期", selection: $value.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            HStack { Text("体重 \(store.settings.unit.rawValue)"); OptionalNumberField(title: "输入体重", value: $entered) }
        }.navigationTitle("记录体重").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { do { guard let entered else { throw ValidationError("请输入体重。") }; value.weightKg = store.settings.unit.kilograms(entered); try store.saveWeight(value); dismiss() } catch { errorMessage = error.localizedDescription } } }
            }.onAppear { entered = value.weightKg > 0 ? store.settings.unit.display(value.weightKg) : nil }.errorAlert($errorMessage)
    }
}

