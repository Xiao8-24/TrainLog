import XCTest
@testable import TrainLog

/// Retain an unfinished service callback without blocking a dispatch worker.
private final class PendingNotification: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: RestNotificationScheduler.Completion?
    private var released = false

    func hold(_ completion: @escaping RestNotificationScheduler.Completion) {
        lock.lock()
        self.completion = completion
        lock.unlock()
    }
    func finish() {
        lock.lock()
        released = true
        let callback = completion
        completion = nil
        lock.unlock()
        callback?("Old scheduling failure")
    }
    var hasFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return released
    }
}

@MainActor final class RestTimerTests: XCTestCase {
    func testSlowNotificationServiceDoesNotBlockTimerAndCancelFollowsStart() async {
        let entered = expectation(description: "Notification operation entered")
        let cancelled = expectation(description: "Cancellation follows scheduling")
        let service = PendingNotification()
        let scheduler = RestNotificationScheduler { _, deadline, completion in
            XCTAssertFalse(Thread.isMainThread)
            if deadline != nil {
                service.hold(completion)
                entered.fulfill()
            } else {
                XCTAssertTrue(service.hasFinished, "Cancellation must wait for the earlier add callback")
                completion(nil)
                cancelled.fulfill()
            }
        }
        let timer = RestTimer(sessionID: UUID(), notifications: scheduler)
        let start = Date()
        timer.start(seconds: 180, notify: true)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertNotNil(timer.deadline)
        // Queue startup allowance is separate from the one-second UI budget.
        await fulfillment(of: [entered], timeout: 30)
        let cancel = Date()
        timer.cancel()
        XCTAssertLessThan(Date().timeIntervalSince(cancel), 1)
        XCTAssertNil(timer.deadline)
        service.finish()
        await fulfillment(of: [cancelled], timeout: 30)
        await Task.yield()
        XCTAssertNil(timer.notificationError, "A stale scheduling error must not overwrite cancellation")
    }
}
