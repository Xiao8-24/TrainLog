import SwiftUI
import WidgetKit
import TrainLogCore

@main struct TrainLogWidgets: WidgetBundle {
    var body: some Widget { TrainingWidget(); WorkoutLiveActivity() }
}

struct TrainingEntry: TimelineEntry {
    var date: Date
    var snapshot: WorkoutWidgetSnapshot?
}
struct TrainingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingEntry {
        TrainingEntry(date: .now, snapshot: WorkoutWidgetSnapshot(sessions: [], weeklyGoal: 4))
    }
    func getSnapshot(in context: Context, completion: @escaping (TrainingEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : TrainingEntry(date: .now, snapshot: WidgetSnapshotStorage.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingEntry>) -> Void) {
        let now = Date(), calendar = Calendar.current
        let snapshot = WidgetSnapshotStorage.read()
        // Precompute day boundaries: a suspended app must not freeze yesterday's totals.
        let midnight = calendar.startOfDay(for: now)
        let dates = [now] + (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: midnight) }
        completion(Timeline(entries: dates.map { TrainingEntry(date: $0, snapshot: snapshot) }, policy: .after(now.addingTimeInterval(3600))))
    }
}
struct TrainingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStorage.kind, provider: TrainingProvider()) { entry in
            TrainingWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(WorkoutDeepLink.workout(entry.snapshot?.draftID).url)
        }
        .configurationDisplayName("训练日程")
        .description("查看今日训练、本周进度，或继续未完成的训练。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
struct TrainingWidgetView: View {
    var entry: TrainingEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if let snapshot = entry.snapshot {
            if family == .accessoryRectangular {
                VStack(alignment: .leading) {
                    Label("本周 \(snapshot.week(at: entry.date).count) / \(snapshot.weeklyGoal) 次", systemImage: "dumbbell.fill").font(.headline)
                    Text(snapshot.draftID == nil ? "打开 TrainLog 开始训练" : "有未完成训练 · 点按继续").font(.caption)
                }.privacySensitive()
            } else {
                HStack(spacing: 16) {
                    today(snapshot)
                    if family == .systemMedium {
                        Divider()
                        week(snapshot)
                    }
                }.privacySensitive()
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("TrainLog", systemImage: "dumbbell.fill").font(.headline).widgetAccentable()
                Text("打开 App 同步训练").font(.subheadline)
                Text("解锁后查看本机记录").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func today(_ snapshot: WorkoutWidgetSnapshot) -> some View {
        let records = snapshot.today(at: entry.date)
        return VStack(alignment: .leading, spacing: 5) {
            Label("今日训练", systemImage: "dumbbell.fill").font(.caption.weight(.semibold)).widgetAccentable()
            Text("\(records.count) 次").font(.system(.largeTitle, design: .rounded, weight: .semibold)).minimumScaleFactor(0.7).lineLimit(1)
            Text("\(records.reduce(0) { $0 + $1.minutes }) 分钟 · \(records.reduce(0) { $0 + $1.workingSets }) 组")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Label(snapshot.draftID == nil ? "开始训练" : "继续草稿", systemImage: snapshot.draftID == nil ? "plus.circle.fill" : "play.circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.blue).widgetAccentable()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func week(_ snapshot: WorkoutWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("本周").font(.caption); Spacer(); Text("\(snapshot.week(at: entry.date).count) / \(snapshot.weeklyGoal) 次").font(.caption.weight(.semibold)) }
            ProgressView(value: Double(min(snapshot.week(at: entry.date).count, snapshot.weeklyGoal)), total: Double(max(1, snapshot.weeklyGoal)))
                .tint(.blue).widgetAccentable().accessibilityLabel("本周训练目标")
            HStack(spacing: 3) {
                ForEach(snapshot.days(at: entry.date), id: \.self) { day in
                    let count = snapshot.today(at: day).count
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10))
                        Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle").font(.caption2)
                            .foregroundStyle(count > 0 ? Color.blue : Color.secondary).widgetAccentable()
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted))，\(count) 次训练")
                }
            }
            Spacer(minLength: 0)
            Link(destination: WorkoutDeepLink.calendar.url) { Label("健身日历", systemImage: "calendar").font(.caption.weight(.semibold)) }
        }.frame(maxWidth: .infinity)
    }
}
