import ActivityKit
import Foundation
import TrainLogCore

struct WorkoutActivityAttributes: ActivityAttributes {
    typealias ContentState = WorkoutLiveState
    var sessionID: UUID
}
