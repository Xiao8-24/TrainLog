import Foundation

/// One scan of history, rather than one scan per visible set/keystroke.
public struct RecentExerciseIndex: Sendable {
    private var entries: [String: ExerciseEntry] = [:]
    public init(sessions: [Session], excluding sessionID: UUID? = nil) {
        let history = sessions.filter { $0.status == .completed && $0.id != sessionID }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        for session in history {
            for entry in session.exercises where entries[entry.exercise.comparisonKey] == nil {
                entries[entry.exercise.comparisonKey] = entry
            }
        }
    }
    public func previous(for exercise: Exercise) -> ExerciseEntry? { entries[exercise.comparisonKey] }
}
