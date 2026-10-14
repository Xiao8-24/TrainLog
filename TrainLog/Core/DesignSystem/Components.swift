import SwiftUI
import Charts
import TrainLogCore

enum AppTheme {
    static let spacing: CGFloat = 20
    static let radius: CGFloat = 22
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static func heat(_ level: Int, dark: Bool) -> Color {
        let light: [Color] = [Color(uiColor: .systemGray5), Color(red: 0.80, green: 0.90, blue: 1), Color(red: 0.47, green: 0.73, blue: 0.98), .blue, Color(red: 0.04, green: 0.25, blue: 0.65)]
        let night: [Color] = [Color(uiColor: .systemGray5), Color(red: 0.12, green: 0.25, blue: 0.38), Color(red: 0.16, green: 0.41, blue: 0.66), Color(red: 0.28, green: 0.59, blue: 0.92), Color(red: 0.55, green: 0.76, blue: 1)]
        return (dark ? night : light)[max(0, min(level, 4))]
    }
}
struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 16) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.radius)) }
}
struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
struct StatValue: View {
    var value: String
    var unit: String = ""
    var body: some View { (Text(value).font(.title2.weight(.semibold)) + Text(unit.isEmpty ? "" : " \(unit)").font(.caption).foregroundColor(.secondary)).monospacedDigit() }
}
struct MetricCard: View {
    var title: String
    var value: String
    var unit: String = ""
    var symbol: String
    var body: some View {
        AppCard {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            StatValue(value: value, unit: unit)
        }.accessibilityElement(children: .combine)
    }
}
struct EmptyStateView: View {
    var title: String
    var message: String
    var symbol: String = "chart.bar.xaxis"
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(.blue).accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.vertical, 28).frame(maxWidth: .infinity)
    }
}
struct LoadingStateView: View { var body: some View { ProgressView("正在读取本地记录…").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct ChartContainer<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content
    var body: some View { AppCard { SectionHeader(title: title, subtitle: subtitle); content } }
}
struct PrimaryActionButton: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9) }.modifier(NativePrimaryActionStyle()).controlSize(.large) }
}
struct ExerciseRow: View {
    var exercise: Exercise
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.tracking == .duration ? "timer" : "dumbbell").font(.title3).foregroundStyle(.blue).frame(width: 40, height: 40).background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name).font(.body.weight(.medium))
                Text(exercise.primary.map(\.name).joined(separator: " · ") + " · " + exercise.equipment.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if exercise.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.orange) }
        }.padding(.vertical, 3).accessibilityElement(children: .combine)
    }
}
extension Double {
    var formattedValue: String { formatted(.number.precision(.fractionLength(0...1))) }
}
extension Session {
    var displayName: String {
        if mode == .quick { return quickEntries.map(\.muscle.name).joined(separator: "、") + "训练" }
        let names = exercises.map(\.exercise.name)
        return names.isEmpty ? "详细训练" : names.prefix(2).joined(separator: " · ")
    }
}
struct SessionRow: View {
    var session: Session
    var showsChevron = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.mode == .quick ? "figure.strengthtraining.functional" : "dumbbell.fill").foregroundStyle(.blue).frame(width: 36, height: 36).background(.blue.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                let total = WorkoutStatisticsService.totals([session])
                Text(session.mode == .quick ? "快速记录 · 不计入组数与容量" : "\(session.exercises.count) 个动作 · \(total.workingSets) 个正式组").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if showsChevron { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true) }
        }.padding(.vertical, 6).accessibilityElement(children: .combine)
    }
}
struct ErrorAlert: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.alert("未能完成操作", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}
extension View { func errorAlert(_ message: Binding<String?>) -> some View { modifier(ErrorAlert(message: message)) } }

/// A string-backed field keeps incomplete/invalid edits visible; it never silently saves the previous number.
struct OptionalNumberField: View {
    var title: String
    @Binding var value: Double?
    var integer = false
    @State private var text = ""
    @FocusState private var focused: Bool
    private func display(_ value: Double?) -> String { value.map { $0.isFinite ? $0.formatted(.number.grouping(.never).precision(.fractionLength(0...3))) : "" } ?? "" }
    var body: some View {
        TextField(title, text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad).multilineTextAlignment(.trailing).monospacedDigit().focused($focused)
            .accessibilityLabel(title)
            .onAppear { text = display(value) }
            .onChange(of: value) { _, new in if !focused { text = display(new) } }
            .onChange(of: text) { _, new in
                if new.isEmpty { value = nil }
                else {
                    let normalized = new.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
                    value = Double(normalized) ?? .nan
                }
            }
    }
}

