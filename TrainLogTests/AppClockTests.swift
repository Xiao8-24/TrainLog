import XCTest
@testable import TrainLog

@MainActor final class AppClockTests: XCTestCase {
    func testRefreshCrossesMidnightAndPicksUpTimeZone() {
        let clock = AppClock()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let before = ISO8601DateFormatter().date(from: "2026-12-31T23:59:59Z")!
        clock.refresh(now: before, calendar: calendar)
        XCTAssertEqual(clock.calendar.component(.year, from: clock.now), 2026)
        clock.refresh(now: before.addingTimeInterval(2), calendar: calendar)
        XCTAssertEqual(clock.calendar.component(.year, from: clock.now), 2027)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        clock.refresh(now: clock.now, calendar: calendar)
        XCTAssertEqual(clock.calendar.component(.year, from: clock.now), 2026)
        XCTAssertEqual(clock.calendar.timeZone.identifier, "America/Los_Angeles")
    }
}
