import Foundation

/// Completed records indexed by local civil day, without a rolling date window.
/// Rebuild when records or the user's calendar/time zone change.
public struct WorkoutCalendarIndex {
    public let calendar: Calendar
    private let days: [Date: [Session]]

    public init(sessions: [Session], calendar: Calendar = .current) {
        self.calendar = calendar
        days = Dictionary(grouping: sessions.filter { $0.status == .completed }) {
            calendar.startOfDay(for: $0.date)
        }.mapValues { records in
            records.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
        }
    }

    public var recordedDays: Set<Date> { Set(days.keys) }
    public func records(on date: Date) -> [Session] { days[calendar.startOfDay(for: date)] ?? [] }
    public func count(on date: Date) -> Int { records(on: date).count }
    public func adjacentDay(to date: Date, offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) ?? date
    }
}
