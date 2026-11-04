import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'generated_tokens.dart';

/// Static atmosphere: no looping animation or full-screen backdrop blur.
class GlassCanvas extends StatelessWidget {
  const GlassCanvas({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = glassNeedsOpaque(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? TrainLogTokens.groupedBackgroundDark
            : TrainLogTokens.groupedBackgroundLight,
      ),
      child: Stack(
        children: [
          if (!opaque)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          dark
                              ? TrainLogTokens.ambientBlueDark
                              : TrainLogTokens.ambientBlueLight,
                          dark
                              ? TrainLogTokens.groupedBackgroundDark
                              : TrainLogTokens.groupedBackgroundLight,
                          dark
                              ? TrainLogTokens.ambientLilacDark
                              : TrainLogTokens.ambientLilacLight,
                        ],
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 0.85,
                          colors: [
                            (dark
                                    ? TrainLogTokens.ambientMintDark
                                    : TrainLogTokens.ambientMintLight)
                                .withValues(alpha: 0.7),
                            (dark
                                    ? TrainLogTokens.ambientMintDark
                                    : TrainLogTokens.ambientMintLight)
                                .withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

// Flutter doesn't expose every OS reduce-transparency preference. The platform's
// high contrast and accessible navigation flags conservatively use solid fills.
bool glassNeedsOpaque(BuildContext context) =>
    MediaQuery.highContrastOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Blur is clipped to a few navigation/control surfaces, never a scrolling list.
/// This approximates the shared appearance; Apple's refraction remains native iOS.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.floating = true,
    this.tint,
  });
  final Widget child;
  final double radius;
  final bool floating;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = glassNeedsOpaque(context);
    final base =
        tint ?? (dark ? TrainLogTokens.cardDark : TrainLogTokens.cardLight);
    final border = BorderRadius.circular(radius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(
              alpha: opaque
                  ? 1
                  : floating
                  ? (dark ? 0.8 : 0.76)
                  : 0.94,
            ),
            base.withValues(
              alpha: opaque
                  ? 1
                  : floating
                  ? (dark ? 0.7 : 0.6)
                  : 0.86,
            ),
          ],
        ),
        borderRadius: border,
        border: Border.all(
          color: opaque
              ? Theme.of(context).colorScheme.outline
              : (dark
                    ? TrainLogTokens.glassEdgeDark.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.85)),
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (floating && !opaque) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: surface,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        boxShadow: opaque
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.15 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: border, child: surface),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: TrainLogTokens.cardRadius,
    floating: false,
    tint: color,
    child: child,
  );
}
