import Foundation
import Observation
import UserNotifications
import UIKit

/// Notification service IPC can stall even a removal call. Keep it off the UI
/// thread and finish each operation before applying the next start/cancel.
final class RestNotificationScheduler: @unchecked Sendable {
    private static let cancelAllIdentifier = "com.trainlog.cancel-all-rest"
    typealias Completion = @Sendable (String?) -> Void
    typealias Operation = @Sendable (String, Date?, @escaping Completion) -> Void
    static let shared = RestNotificationScheduler()
    private let queue = DispatchQueue(label: "com.trainlog.rest-notifications", qos: .utility)
    private let operation: Operation
    // Accessed exclusively on queue, including asynchronous completion handling.
    private var pending: [(String, Date?, Completion)] = []
    private var running = false

    init(operation: Operation? = nil) {
        self.operation = operation ?? { identifier, deadline, completion in
            Self.apply(identifier: identifier, deadline: deadline, completion: completion)
        }
    }

    func replace(identifier: String, deadline: Date?, completion: @escaping Completion) {
        queue.async {
            self.pending.append((identifier, deadline, completion))
            self.drain()
        }
    }
    func cancelAll() { replace(identifier: Self.cancelAllIdentifier, deadline: nil) { _ in } }
    private func drain() {
        guard !running, !pending.isEmpty else { return }
        running = true
        let (identifier, deadline, completion) = pending.removeFirst()
        operation(identifier, deadline) { error in
            self.queue.async {
                completion(error)
                self.running = false
                self.drain()
            }
        }
    }
    private static func apply(identifier: String, deadline: Date?, completion: @escaping Completion) {
        let center = UNUserNotificationCenter.current()
        if identifier == cancelAllIdentifier { center.removeAllPendingNotificationRequests(); completion(nil); return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        // Use the original deadline: delayed IPC must not extend the rest period.
        guard let deadline, deadline.timeIntervalSinceNow > 0 else { completion(nil); return }
        let content = UNMutableNotificationContent()
        content.title = "休息结束"; content.body = "准备好后，开始下一组。"; content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.01, deadline.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) {
            completion($0?.localizedDescription)
        }
    }
}

@MainActor @Observable final class RestTimer {
    static let endRequested = Notification.Name("TrainLog.endRestRequested")
    static func endCurrentRest(sessionID: UUID) {
        RestTimer(sessionID: sessionID).cancel()
        NotificationCenter.default.post(name: endRequested, object: sessionID)
    }
    var deadline: Date?
    var notificationError: String?
    private let key: String
    private let notificationID: String
    private let notifications: RestNotificationScheduler
    private var notificationRevision = UUID()
    init(sessionID: UUID, notifications: RestNotificationScheduler = .shared) {
        self.notifications = notifications
        key = "rest.\(sessionID.uuidString)"; notificationID = key
        if let date = UserDefaults.standard.object(forKey: key) as? Date, date > Date() { deadline = date }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
    func start(seconds: Int, notify: Bool) {
        guard seconds > 0 else { cancel(); return }
        deadline = Date().addingTimeInterval(Double(seconds)); UserDefaults.standard.set(deadline, forKey: key)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateNotification(deadline: notify ? deadline : nil)
    }
    func remaining(at date: Date) -> Int { max(0, Int(ceil(deadline?.timeIntervalSince(date) ?? 0))) }
    func tick(at date: Date) {
        if let deadline, date >= deadline {
            self.deadline = nil; UserDefaults.standard.removeObject(forKey: key)
            notificationRevision = UUID(); notificationError = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    func cancel() {
        deadline = nil; UserDefaults.standard.removeObject(forKey: key)
        updateNotification(deadline: nil)
    }
    private func updateNotification(deadline: Date?) {
        let revision = UUID(); notificationRevision = revision; notificationError = nil
        notifications.replace(identifier: notificationID, deadline: deadline) { [weak self] error in
            Task { @MainActor in
                guard let self, self.notificationRevision == revision else { return }
                self.notificationError = error
            }
        }
    }
}

