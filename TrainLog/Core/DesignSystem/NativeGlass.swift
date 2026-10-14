import SwiftUI

/// Keep the system in charge of refraction, contrast, motion and glass appearance.
/// Compiler guards also allow the iOS 18 compatibility job to use Xcode 16.4.
struct NativePrimaryActionStyle: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
        #else
        content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        #endif
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
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular, in: .rect(cornerRadius: 24))
            } else {
                content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
            #else
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            #endif
        }
    }
}

extension View {
    @ViewBuilder func nativeBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0, content: content)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0, content: content)
        }
        #else
        safeAreaInset(edge: .bottom, spacing: 0, content: content)
        #endif
    }
}
