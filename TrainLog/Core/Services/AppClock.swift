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

#if DEBUG
private struct MotionTestOverrideKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var trainLogMotionTestOverride: Bool {
        get { self[MotionTestOverrideKey.self] }
        set { self[MotionTestOverrideKey.self] = newValue }
    }
}
#endif

/// Real accessibility preferences always win. Only isolated DEBUG tests may
/// additionally request reduced application motion; no system setting is written.
@propertyWrapper struct NativeReducedMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var systemValue
    #if DEBUG
    @Environment(\.trainLogMotionTestOverride) private var testValue
    #endif
    var wrappedValue: Bool {
        #if DEBUG
        systemValue || testValue
        #else
        systemValue
        #endif
    }
}

struct NativeMotion<Value: Equatable>: ViewModifier {
    @NativeReducedMotion private var reduceMotion
    var value: Value
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .snappy(duration: 0.26, extraBounce: 0), value: value)
    }
}

struct NativeNumberTransition: ViewModifier {
    @NativeReducedMotion private var reduceMotion
    var value: String
    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.26, extraBounce: 0), value: value)
    }
}

/// Only symbol changes use replacement motion; surrounding labels and fields keep identity.
struct NativeSymbolTransition: ViewModifier {
    @NativeReducedMotion private var reduceMotion
    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
    }
}

extension View {
    func nativeSymbolTransition() -> some View { modifier(NativeSymbolTransition()) }
    func nativeMotion<Value: Equatable>(value: Value) -> some View { modifier(NativeMotion(value: value)) }
    func nativeNumberTransition(value: String) -> some View { modifier(NativeNumberTransition(value: value)) }
}
