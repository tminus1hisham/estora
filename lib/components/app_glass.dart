import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'surface_atoms.dart';

/// A pane of frosted glass: whatever is behind it, blurred, under a translucent
/// fill and a hairline of caught light.
///
/// Used in two places and no more. A bar that stays put while a list runs under
/// it ([GlassSurface.blur] is what makes that legible without hiding the list),
/// and the inset panel on a brand card, where the blur softens the glows
/// underneath so the panel reads as a separate pane of the same material.
///
/// Glass costs a composited layer, so it is worth spending only where something
/// genuinely passes behind it. Over a flat surface it is an expensive way to
/// draw a tinted box.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.blur = 16,
    this.tint,
    this.borderColor,
    this.borderRadius = AppRadius.medium,
    this.onDark = false,
    this.border = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Blur sigma. Low by design — enough to smear what passes behind, not so
  /// much that the pane turns into a plate.
  final double blur;

  final Color? tint;
  final Color? borderColor;
  final BorderRadius borderRadius;

  /// Set on the brand cards, which stay dark in both themes.
  final bool onDark;

  final bool border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // How much light the top edge catches. A white highlight that reads as a
    // sheen on a cream surface reads as a grey band on a black one, so an
    // ordinary pane takes its strength from the theme; a pane on a brand card
    // is dark whatever the theme says.
    final highlight = onDark
        ? 0.07
        : (theme.brightness == Brightness.dark ? 0.05 : 0.45);

    final fill =
        tint ??
        (onDark
            ? kOnDark.withValues(alpha: 0.09)
            : scheme.surfaceContainerLowest.withValues(alpha: 0.72));
    final line =
        borderColor ??
        (onDark
            ? kOnDark.withValues(alpha: 0.16)
            : scheme.outlineVariant.withValues(alpha: 0.6));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        // Two boxes rather than one: a [BoxDecoration] given both a colour and
        // a gradient paints only the gradient, and the fill is what carries the
        // tint. The inner box holds the light and the border, so the hairline
        // draws over both.
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: borderRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: border ? Border.all(color: line) : null,
              // The light that makes glass read as glass: a highlight along the
              // top edge only, fading out well before the middle.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kOnDark.withValues(alpha: highlight),
                  kOnDark.withValues(alpha: 0),
                ],
                stops: const [0, 0.55],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
