import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A keyboard- and safe-area-aware home for persistent screen actions.
class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.lg,
      AppSpace.md,
      AppSpace.lg,
      AppSpace.md,
    ),
    this.maxWidth = AppLayout.maxReadingWidth,
    this.showTopBorder = true,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: AppElevation.medium,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.72),
                  ),
                )
              : null,
        ),
        child: SafeArea(
          top: false,
          minimum: padding,
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
