import Foundation
import Observation
import UserNotifications
import UIKit

@MainActor @Observable final class RestTimer {
    var deadline: Date?
    var notificationError: String?
    private let key: String
    private let notificationID: String
    init(sessionID: UUID) {
        key = "rest.\(sessionID.uuidString)"; notificationID = key
        if let date = UserDefaults.standard.object(forKey: key) as? Date, date > Date() { deadline = date }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
    func start(seconds: Int, notify: Bool) {
        cancel()
        guard seconds > 0 else { return }
        deadline = Date().addingTimeInterval(Double(seconds)); UserDefaults.standard.set(deadline, forKey: key)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if notify {
            let content = UNMutableNotificationContent(); content.title = "休息结束"; content.body = "准备好后，开始下一组。"; content.sound = .default
            let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false))
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if let error { Task { @MainActor in self?.notificationError = error.localizedDescription } }
            }
        }
    }
    func remaining(at date: Date) -> Int { max(0, Int(ceil(deadline?.timeIntervalSince(date) ?? 0))) }
    func tick(at date: Date) {
        if let deadline, date >= deadline {
            self.deadline = nil; UserDefaults.standard.removeObject(forKey: key)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    func cancel() {
        deadline = nil; UserDefaults.standard.removeObject(forKey: key)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
}

