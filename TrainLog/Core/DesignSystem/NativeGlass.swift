import SwiftUI

/// Keep the system in charge of refraction, contrast, motion and glass appearance.
struct NativePrimaryActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
    }
}

/// Only for floating controls, never for workout cards, charts or the muscle map.
struct NativeFloatingSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.2)) }
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }
}

extension View {
    @ViewBuilder func nativeBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        safeAreaBar(edge: .bottom, spacing: 0, content: content)
    }
}
