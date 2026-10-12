import XCTest
@testable import TrainLogCore

final class WorkoutCalendarTests: XCTestCase {
    private func calendar(_ zone: String = "Asia/Shanghai") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func completed(_ date: Date) -> Session {
        var session = Session(mode: .quick, date: date)
        session.quickEntries = [QuickEntry(muscle: .chest)]
        session.finish(at: date)
        return session
    }
    func testNoRollingWindowAndDraftsExcluded() {
        let old = completed(date("1995-01-01T04:00:00Z"))
        let recent = completed(date("2026-10-12T04:00:00Z"))
        let draft = Session(mode: .quick, date: recent.date)
        let index = WorkoutCalendarIndex(sessions: [old, recent, draft], calendar: calendar())
        XCTAssertEqual(index.records(on: old.date).map(\.id), [old.id])
        XCTAssertEqual(index.count(on: recent.date), 1)
        XCTAssertEqual(index.count(on: date("2040-01-01T04:00:00Z")), 0)
        XCTAssertEqual(index.recordedDays.count, 2)
    }
    func testLocalMidnightUsesHalfOpenDaysAndStableOrdering() {
        let before = completed(date("2026-10-11T15:59:59Z"))
        let midnight = completed(date("2026-10-11T16:00:00Z"))
        let later = completed(date("2026-10-11T17:00:00Z"))
        let index = WorkoutCalendarIndex(sessions: [midnight, before, later], calendar: calendar())
        XCTAssertEqual(index.records(on: before.date).map(\.id), [before.id])
        XCTAssertEqual(index.records(on: midnight.date).map(\.id), [later.id, midnight.id])
    }
    func testTimeZoneChangeRegroupsWithoutChangingRecords() {
        let session = completed(date("2026-10-11T23:30:00Z"))
        let shanghai = WorkoutCalendarIndex(sessions: [session], calendar: calendar())
        let la = WorkoutCalendarIndex(sessions: [session], calendar: calendar("America/Los_Angeles"))
        XCTAssertNotEqual(shanghai.recordedDays, la.recordedDays)
        XCTAssertEqual(shanghai.calendar.component(.day, from: shanghai.recordedDays.first!), 12)
        XCTAssertEqual(la.calendar.component(.day, from: la.recordedDays.first!), 11)
        XCTAssertEqual(la.records(on: session.date).first?.id, session.id)
    }
    func testDayNavigationAcrossBothDSTTransitions() {
        let calendar = calendar("America/Los_Angeles")
        let index = WorkoutCalendarIndex(sessions: [], calendar: calendar)
        for (day, hours) in [("2026-03-08T12:00:00Z", 23.0), ("2026-11-01T12:00:00Z", 25.0)] {
            let start = calendar.startOfDay(for: date(day))
            let next = index.adjacentDay(to: start, offset: 1)
            XCTAssertEqual(next.timeIntervalSince(start), hours * 3600)
            XCTAssertEqual(index.adjacentDay(to: next, offset: -1), start)
        }
    }
    func testLeapDayAndYearBoundaryNavigation() {
        let cal = calendar()
        let index = WorkoutCalendarIndex(sessions: [], calendar: cal)
        let leap = index.adjacentDay(to: date("2024-02-28T04:00:00Z"), offset: 1)
        XCTAssertEqual(cal.component(.day, from: leap), 29)
        let march = index.adjacentDay(to: leap, offset: 1)
        XCTAssertEqual(cal.component(.month, from: march), 3)
        let january = index.adjacentDay(to: date("2025-12-31T04:00:00Z"), offset: 1)
        XCTAssertEqual(cal.component(.year, from: january), 2026)
        XCTAssertEqual(cal.component(.day, from: january), 1)
    }
    func testEditAndDeletionRefreshDayMarkersAndRecords() {
        let original = completed(date("2026-10-10T04:00:00Z"))
        var edited = original
        edited.date = date("2026-10-11T04:00:00Z")
        let moved = WorkoutCalendarIndex(sessions: [edited], calendar: calendar())
        XCTAssertEqual(moved.count(on: original.date), 0)
        XCTAssertEqual(moved.count(on: edited.date), 1)
        XCTAssertEqual(moved.recordedDays.count, 1)
        let deleted = WorkoutCalendarIndex(sessions: [], calendar: calendar())
        XCTAssertTrue(deleted.recordedDays.isEmpty)
        XCTAssertTrue(deleted.records(on: edited.date).isEmpty)
    }
}
