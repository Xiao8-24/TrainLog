import SwiftUI
import TrainLogCore

struct WorkoutMonthCalendar: View {
    var sessions: [Session]
    @Environment(AppClock.self) private var clock
    @State private var selectedDate = Date()
    var body: some View {
        let index = WorkoutCalendarIndex(sessions: sessions, calendar: clock.calendar)
        NativeWorkoutCalendar(selectedDate: $selectedDate, index: index)
            .id(String(describing: clock.calendar.identifier) + clock.calendar.timeZone.identifier)
        NavigationLink {
            DayHistoryView(date: selectedDate)
        } label: {
            Label("查看 \(selectedDate.formatted(date: .abbreviated, time: .omitted)) · \(index.count(on: selectedDate)) 次训练", systemImage: "list.bullet")
                .frame(minHeight: 44)
        }
    }
}
enum CalendarHeatMetric: String, CaseIterable, Identifiable {
    case coverage, sessions, sets, rpe
    var id: String { rawValue }
    var name: String { switch self { case .coverage: return "是否训练"; case .sessions: return "训练次数"; case .sets: return "正式组数"; case .rpe: return "会话 RPE" } }
    var legend: [String] { switch self { case .coverage: return ["无", "有记录"]; case .sessions: return ["0", "1", "2", "3", "≥4 次"]; case .sets: return ["0", "1–5", "6–10", "11–15", "≥16 组"]; case .rpe: return ["未填写", "1–<4", "4–<6", "6–<8", "8–10"] } }
    func level(_ daily: DailyStatistic?) -> Int {
        guard let day = daily else { return 0 }
        switch self {
        case .coverage: return day.totals.sessions > 0 ? 3 : 0
        case .sessions: return min(day.totals.sessions, 4)
        case .sets: return day.totals.workingSets == 0 ? 0 : min(4, (day.totals.workingSets - 1) / 5 + 1)
        case .rpe: guard let value = day.meanRPE else { return 0 }; return value < 4 ? 1 : value < 6 ? 2 : value < 8 ? 3 : 4
        }
    }
}
struct AnnualHeatmap: View {
    @Environment(AppClock.self) private var clock
    var sessions: [Session]
    @Environment(\.colorScheme) private var scheme
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var metric = CalendarHeatMetric.coverage
    @State private var selectedDate = Date()
    private var cal: Calendar { clock.calendar }
    private var first: Date { cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date() }
    private var end: Date { cal.date(byAdding: .year, value: 1, to: first) ?? Date() }
    private var days: Int { cal.dateComponents([.day], from: first, to: end).day ?? 365 }
    private var offset: Int { (cal.component(.weekday, from: first) + 5) % 7 }
    private var data: [Date: DailyStatistic] { Dictionary(uniqueKeysWithValues: TrendAnalysisService.daily(sessions, interval: DateInterval(start: first, end: end), calendar: cal).map { ($0.date, $0) }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "年度活动", subtitle: "按设备当前时区统计")
                Spacer()
                Stepper("\(String(year)) 年", value: $year).font(.caption)
            }
            Picker("年度热力指标", selection: $metric) { ForEach(CalendarHeatMetric.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
            let daily = data
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(0..<((days + offset + 6) / 7), id: \.self) { week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { weekday in
                                let index = week * 7 + weekday - offset
                                if index >= 0 && index < days, let date = cal.date(byAdding: .day, value: index, to: first) {
                                    NavigationLink { DayHistoryView(date: date) } label: {
                                        RoundedRectangle(cornerRadius: 3).fill(AppTheme.heat(metric.level(daily[date]), dark: scheme == .dark)).frame(width: 12, height: 12)
                                    }.buttonStyle(.plain).accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(daily[date]?.totals.sessions ?? 0) 次训练")
                                } else { Color.clear.frame(width: 12, height: 12) }
                            }
                        }
                    }
                }.padding(.vertical, 4)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 9) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            DatePicker("按日期查看", selection: $selectedDate, displayedComponents: .date).font(.subheadline)
            NavigationLink("打开 \(selectedDate.formatted(date: .abbreviated, time: .omitted)) 的记录") { DayHistoryView(date: selectedDate) }.font(.subheadline).frame(minHeight: 44)
        }
    }
    @ViewBuilder private var legend: some View {
        ForEach(Array(metric.legend.enumerated()), id: \.offset) { index, label in
            HStack(spacing: 4) { RoundedRectangle(cornerRadius: 3).fill(AppTheme.heat(metric == .coverage && index == 1 ? 3 : index, dark: scheme == .dark)).frame(width: 10, height: 10); Text(label).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}

