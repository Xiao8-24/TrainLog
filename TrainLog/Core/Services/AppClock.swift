import SwiftUI
import Observation

/// Refreshes date-dependent views after midnight, foregrounding, and time-zone changes.
@MainActor @Observable final class AppClock {
    private(set) var now = Date()
    private(set) var calendar = Calendar.current
    func refresh(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}

struct NativeMotion<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Value
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .smooth(duration: 0.25), value: value)
    }
}

extension View {
    func nativeMotion<Value: Equatable>(value: Value) -> some View { modifier(NativeMotion(value: value)) }
}
