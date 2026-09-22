import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'glass_material.dart';
import 'glass_well.dart';

/// "Nothing here yet", said on a pane of glass rather than on the bare page.
///
/// An empty list on a lit ground is otherwise a large quiet space with a grey
/// icon floating in it, which reads as something that failed to load. A pane
/// gives the message an edge and a place, the same object the records will
/// arrive in.
class GlassEmptyPane extends StatelessWidget {
  const GlassEmptyPane({
    required this.icon,
    required this.title,
    this.message,
    this.caption,
    this.action,
    this.color,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// A small-capitals line above the title, naming what the screen is for.
  final String? caption;

  final Widget? action;

  /// The glyph's hue. Defaults to the brand azure.
  final Color? color;

  /// Tighter, for an empty section inside a screen rather than a whole one.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final hue = color ?? (dark ? AppPalette.azure300 : AppPalette.azure600);
    final caption = this.caption;
    final message = this.message;

    return FrostedPane(
      radius: compact ? GlassRadius.card : GlassRadius.platter,
      padding: compact
          ? const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg)
          : const EdgeInsets.fromLTRB(Gap.xl, Gap.xl + 4, Gap.xl, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassWell(icon: icon, color: hue, size: compact ? 44 : 56),
          SizedBox(height: compact ? Gap.md : Gap.lg),
          if (caption != null) ...[
            Text(
              caption.toUpperCase(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            Gap.h8,
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: AppTypography.semibold,
                      letterSpacing: -0.2,
                    ),
          ),
          if (message != null) ...[
            Gap.h4,
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: compact ? Gap.md : Gap.lg + 4),
            action!,
          ],
        ],
      ),
    );
  }
}
