import ActivityKit
import Foundation
import WidgetKit
import UIKit
import TrainLogCore
import Observation

/// Serializes ActivityKit calls; a finish queued during an update always wins.
@MainActor @Observable final class WorkoutSurfacesCoordinator {
    static let enabledKey = "workoutLiveActivitiesEnabled"
    private var pending: (Session?, Date?)?
    private var worker: Task<Void, Never>?
    private var lastSnapshot: WorkoutWidgetSnapshot?
    var issue: String?

    func publish(sessions: [Session], goal: Int, templates: [TrainingTemplate] = []) {
        let deadline = sessions.first { $0.status == .draft }.flatMap { UserDefaults.standard.object(forKey: "rest.\($0.id.uuidString)") as? Date }
        let snapshot = WorkoutWidgetSnapshot(sessions: sessions, weeklyGoal: goal, templates: templates, restDeadline: deadline)
        // Ignore the creation timestamp when deciding whether widget content changed.
        if let previous = lastSnapshot, previous.records == snapshot.records,
           previous.draftID == snapshot.draftID, previous.weeklyGoal == snapshot.weeklyGoal,
           previous.templates == snapshot.templates, previous.restDeadline == snapshot.restDeadline { return }
        do {
            try WidgetSnapshotStorage.write(snapshot)
            lastSnapshot = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStorage.kind)
        } catch { issue = "小组件暂未同步，下次打开 App 会重试。" }
    }
    func sync(session: Session?) {
        let deadline = session.flatMap { UserDefaults.standard.object(forKey: "rest.\($0.id.uuidString)") as? Date }
        pending = (session, deadline)
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while let value = self.pending {
                self.pending = nil
                await self.apply(session: value.0, restDeadline: value.1)
            }
            self.worker = nil
        }
    }
    private func apply(session: Session?, restDeadline: Date?) async {
        let enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        let eligible = enabled && session?.status == .draft && session?.mode != .quick
        for activity in Activity<WorkoutActivityAttributes>.activities where !eligible || activity.attributes.sessionID != session?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard eligible, let session else { return }
        let state = WorkoutLiveState(session: session, restDeadline: restDeadline)
        let content = ActivityContent(state: state, staleDate: state.staleDate)
        if let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id }) {
            guard activity.activityState == .active || activity.activityState == .stale else { return }
            let previous = activity.content
            if previous.state.hasSamePresentation(as: state),
               let expires = previous.staleDate, expires.timeIntervalSinceNow > 300 { return }
            await activity.update(content)
        } else {
            // Respect user-dismissed activities, including after an app relaunch.
            let key = "lastLiveActivitySession"
            guard UserDefaults.standard.string(forKey: key) != session.id.uuidString,
                  UIApplication.shared.applicationState == .active,
                  ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                _ = try Activity.request(attributes: WorkoutActivityAttributes(sessionID: session.id), content: content, pushType: nil)
                UserDefaults.standard.set(session.id.uuidString, forKey: key)
                issue = nil
            } catch { issue = "实时活动暂不可用，App 内计时不受影响。" }
        }
    }
}
