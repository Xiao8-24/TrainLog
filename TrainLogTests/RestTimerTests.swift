import XCTest
@testable import TrainLog

@MainActor final class RestTimerTests: XCTestCase {
    func testSlowNotificationServiceDoesNotBlockTimerAndCancelFollowsStart() async {
        let entered = expectation(description: "Notification operation entered")
        let cancelled = expectation(description: "Cancellation follows scheduling")
        let releaseService = DispatchSemaphore(value: 0)
        let scheduler = RestNotificationScheduler { _, deadline, completion in
            XCTAssertFalse(Thread.isMainThread)
            if deadline != nil {
                entered.fulfill()
                // Reproduce a blocked notification service without blocking the UI.
                XCTAssertEqual(releaseService.wait(timeout: .now() + 5), .success)
                completion("Old scheduling failure")
            } else {
                completion(nil)
                cancelled.fulfill()
            }
        }
        let timer = RestTimer(sessionID: UUID(), notifications: scheduler)
        let start = Date()
        timer.start(seconds: 180, notify: true)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertNotNil(timer.deadline)
        await fulfillment(of: [entered], timeout: 2)
        let cancel = Date()
        timer.cancel()
        XCTAssertLessThan(Date().timeIntervalSince(cancel), 1)
        XCTAssertNil(timer.deadline)
        releaseService.signal()
        await fulfillment(of: [cancelled], timeout: 2)
        await Task.yield()
        XCTAssertNil(timer.notificationError, "A stale scheduling error must not overwrite cancellation")
    }
}
