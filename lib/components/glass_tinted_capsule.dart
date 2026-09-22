import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'glass_material.dart';

/// The quiet sibling of a prominent [GlassCapsuleButton]: azure type on a
/// capsule tinted with the same azure, the way the App Store sets "Get" down
/// a list.
///
/// For an action repeated on every card of a list, where a lit capsule on
/// each would turn the list into a wall of buttons. It keeps the lit
/// capsule's size and padding exactly, so a card can promote its action to
/// lit when it becomes urgent without anything around it moving.
///
/// Also the right secondary action on a milk pane, where the clear glass
/// capsule is white on white and all but vanishes.
class GlassTintedCapsule extends StatelessWidget {
  const GlassTintedCapsule({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Fill the width it is given, for the stacked layout at large text sizes.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? AppPalette.azure200 : AppPalette.azure700;

    // Drawn small, touched large: the capsule itself is App Store "Get"
    // height, and the transparent margin around it keeps the target at the
    // 44pt a finger needs.
    return GlassTap(
      onTap: onPressed,
      scale: 0.95,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(
                    color: (dark ? AppPalette.azure300 : AppPalette.azure500)
                        .withValues(alpha: dark ? 0.14 : 0.12),
                  ),
                ),
                color: (dark ? AppPalette.azure300 : AppPalette.azure500)
                    .withValues(alpha: dark ? 0.10 : 0.07),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        // Grows with the label, so at a large text size the glyph is not
                        // left a speck beside the words.
                        size: MediaQuery.textScalerOf(
                          context,
                        ).scale(15).clamp(15.0, 22.0),
                        color: foreground,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: AppTypography.semibold,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
