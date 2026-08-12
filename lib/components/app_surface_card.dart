import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A premium tonal surface used for cards, grouped controls and summaries.
///
/// Unlike [Card], this exposes the few presentation choices feature screens
/// commonly need while retaining one radius, border and interaction language.
///
/// [gradient] and [shadows] are what a hero surface reaches for. They are
/// layered outside the [Material] rather than folded into it so that the
/// shape's border still draws over clipped content — a card whose first child
/// is a photograph needs the border on top of the image, not under it.
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.gradient,
    this.shadows,
    this.borderColor,
    this.borderRadius = AppRadius.large,
    this.elevation = AppElevation.none,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;

  /// Fills the card instead of [color]. Reserved for the one surface on a
  /// screen that carries the money or the moment.
  final Gradient? gradient;

  /// Replaces Material's elevation shadow. Use [AppElevation.lifted].
  final List<BoxShadow>? shadows;

  final Color? borderColor;
  final BorderRadius borderRadius;
  final double elevation;
  final Clip clipBehavior;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(
        color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.78),
      ),
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }

    // A custom shadow replaces Material's own, rather than stacking with it.
    final usesCustomShadow = shadows != null;

    Widget surface = Material(
      color: gradient != null
          ? Colors.transparent
          : (color ?? scheme.surfaceContainerLowest),
      elevation: usesCustomShadow ? AppElevation.none : elevation,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      shape: shape,
      clipBehavior: clipBehavior,
      child: content,
    );

    if (gradient != null) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
        ),
        child: surface,
      );
    }

    if (usesCustomShadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: surface,
      );
    }

    final result = Padding(padding: margin, child: surface);

    if (semanticLabel == null) return result;
    return Semantics(container: true, label: semanticLabel, child: result);
  }
}
