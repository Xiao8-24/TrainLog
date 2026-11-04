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
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.2)).allowsHitTesting(false).accessibilityHidden(true) }
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }
}

/// Content stays legible beneath the system's floating glass navigation layer.
struct PearlContentSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        let opaque = reduceTransparency || contrast == .increased
        let shape = RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
        content.background {
            shape.fill(AppTheme.card.opacity(opaque ? 1 : 0.9))
            if !opaque {
                shape.fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .overlay { shape.strokeBorder(opaque ? Color.primary.opacity(0.2) : (scheme == .dark ? TrainLogTokens.glassEdgeDark.opacity(0.5) : .white.opacity(0.85)), lineWidth: 1).allowsHitTesting(false).accessibilityHidden(true) }
        .shadow(color: .black.opacity(opaque ? 0 : (scheme == .dark ? 0.15 : 0.04)), radius: 14, y: 6)
    }
}

struct AppCanvas: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        ZStack {
            AppTheme.background
            if !reduceTransparency && contrast != .increased {
                LinearGradient(colors: [scheme == .dark ? TrainLogTokens.ambientBlueDark : TrainLogTokens.ambientBlueLight, .clear, scheme == .dark ? TrainLogTokens.ambientLilacDark : TrainLogTokens.ambientLilacLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [(scheme == .dark ? TrainLogTokens.ambientMintDark : TrainLogTokens.ambientMintLight).opacity(0.7), .clear], center: .topTrailing, startRadius: 0, endRadius: 440)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

extension View {
    func appCanvas() -> some View { background { AppCanvas() } }
    @ViewBuilder func nativeBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        safeAreaBar(edge: .bottom, spacing: 0, content: content)
    }
}
