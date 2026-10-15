import Foundation
import TrainLogCore

enum WidgetSnapshotStorage {
    static let group = "group.com.trainlog.personal"
    static let kind = "TrainLogTrainingWidget"
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("workout-widget-v1.json")
    }
    static func read() -> WorkoutWidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data), value.version == 1 else { return nil }
        return value
    }
    static func write(_ value: WorkoutWidgetSnapshot) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
