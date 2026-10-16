import SwiftUI
import WidgetKit
import ActivityKit
import TrainLogCore

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: symbol(context.state, stale: context.isStale)).font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.label(stale: context.isStale)).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                    Text("已完成 \(context.state.workingSets) 个正式组").font(.caption).foregroundStyle(.secondary)
                    Text("点按继续训练").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                LiveTimer(state: context.state, stale: context.isStale).font(.title2.weight(.semibold)).frame(maxWidth: 110)
            }.padding(14).privacySensitive()
                .widgetURL(WorkoutDeepLink.workout(context.attributes.sessionID).url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.label(stale: context.isStale), systemImage: symbol(context.state, stale: context.isStale))
                        .font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveTimer(state: context.state, stale: context.isStale).font(.headline).frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("已完成 \(context.state.workingSets) 个正式组").font(.subheadline)
                        Spacer()
                        Link("打开训练", destination: WorkoutDeepLink.workout(context.attributes.sessionID).url)
                            .font(.subheadline.weight(.semibold))
                    }.padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: symbol(context.state, stale: context.isStale)).foregroundStyle(.blue)
            } compactTrailing: {
                LiveTimer(state: context.state, stale: context.isStale).font(.caption.weight(.semibold)).frame(width: 58)
            } minimal: {
                if context.state.phase == .resting && !context.isStale {
                    LiveTimer(state: context.state, stale: false).font(.system(size: 11, weight: .semibold)).frame(width: 36)
                } else { Image(systemName: symbol(context.state, stale: context.isStale)) }
            }
            .widgetURL(WorkoutDeepLink.workout(context.attributes.sessionID).url)
            .keylineTint(.blue)
        }
    }
    private func symbol(_ state: WorkoutLiveState, stale: Bool) -> String {
        if stale { return state.phase == .resting ? "checkmark" : "arrow.clockwise" }
        switch state.phase {
        case .training: return "dumbbell.fill"
        case .paused: return "pause.fill"
        case .resting: return "timer"
        case .finished: return "checkmark"
        }
    }
}
struct LiveTimer: View {
    var state: WorkoutLiveState
    var stale: Bool
    var body: some View {
        Group {
            if stale { Text(state.phase == .resting ? "就绪" : "—") }
            else if let end = state.restDeadline {
                Text(timerInterval: min(state.updatedAt, end)...end, countsDown: true, showsHours: false)
            } else if let start = state.timerOrigin {
                Text(timerInterval: start...max(start, state.staleDate), countsDown: false, showsHours: true)
            } else {
                Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .hourMinuteSecond)))
            }
        }.monospacedDigit().lineLimit(1).minimumScaleFactor(0.65).multilineTextAlignment(.trailing)
    }
}
