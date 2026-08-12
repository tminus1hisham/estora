import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A premium tonal surface used for cards, grouped controls and summaries.
///
/// Unlike [Card], this exposes the few presentation choices feature screens
/// commonly need while retaining one radius, border and interaction language.
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
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

    final result = Padding(
      padding: margin,
      child: Material(
        color: color ?? scheme.surfaceContainerLowest,
        elevation: elevation,
        shadowColor: scheme.shadow.withValues(alpha: 0.12),
        shape: shape,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );

    if (semanticLabel == null) return result;
    return Semantics(container: true, label: semanticLabel, child: result);
  }
}
