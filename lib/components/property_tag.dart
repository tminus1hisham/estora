import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Where something belongs: a small storefront glyph and the property's name,
/// with the unit after it — "Sarit Mall · SHOP-101".
///
/// A tenant can lease in more than one estora, and an invoice, a payment or a
/// lease read out of context says nothing about which shop it is for. The tag
/// answers that at a glance, down a list, without taking a line of prose.
///
/// It is a label, not a control. The tint is the neutral of the glass it sits
/// on — no azure, no brass, no border strong enough to read as a button — so a
/// statement of six tagged invoices reads as six invoices, not six chips. The
/// name leads in the secondary text colour and the unit trails a step fainter,
/// because the property is the fact that differs between a tenant's cards and
/// the unit is the detail.
///
/// It sits inside a pane already, so it is a plain translucent fill rather
/// than a second pane of glass.
class PropertyTag extends StatelessWidget {
  const PropertyTag({
    this.name,
    this.unit,
    this.maxLines = 1,
    this.color,
    super.key,
  });

  /// The property, e.g. "Sarit Mall".
  final String? name;

  /// The unit within it, e.g. "SHOP-101".
  final String? unit;

  /// One line down a list, where a long name is ellipsised rather than
  /// wrapped; more at a large text size, where the whole name is worth a
  /// second line.
  final int maxLines;

  /// A hue to tint the tag with — its words, glyph, fill and hairline —
  /// where a screen wants its tags to stand apart. Null keeps the neutral.
  final Color? color;

  /// Whether there is anything to say. A tag with neither a name nor a unit
  /// would be an empty capsule, so callers leave it out instead.
  static bool canShow({String? name, String? unit}) =>
      _clean(name) != null || _clean(unit) != null;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final name = _clean(this.name);
    final unit = _clean(this.unit);
    if (name == null && unit == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tint = color;
    final ink = tint ?? scheme.onSurfaceVariant;
    final base = theme.textTheme.labelSmall?.copyWith(
      color: ink,
      fontWeight: AppTypography.medium,
      letterSpacing: 0.1,
    );

    // A unit on its own still needs a noun, or "B-12" reads as a code.
    final spans = <InlineSpan>[
      if (name != null) TextSpan(text: name),
      if (name != null && unit != null)
        TextSpan(
          text: ' · ',
          style: TextStyle(color: ink.withValues(alpha: 0.5)),
        ),
      if (unit != null)
        TextSpan(
          text: name == null ? 'Unit $unit' : unit,
          style: TextStyle(
            color: ink.withValues(alpha: name == null ? 1 : 0.78),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
    ];

    final semantics = [?name, if (unit != null) 'unit $unit'].join(', ');

    return Semantics(
      label: 'Property: $semantics',
      container: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: tint != null
                  ? tint.withValues(alpha: dark ? 0.28 : 0.22)
                  : dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppPalette.navy900.withValues(alpha: 0.06),
            ),
          ),
          color: tint != null
              ? tint.withValues(alpha: dark ? 0.16 : 0.10)
              : dark
              ? Colors.white.withValues(alpha: 0.06)
              : AppPalette.navy900.withValues(alpha: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_rounded,
                // Grows with the words, so at a large text size the glyph is
                // not left a speck beside them.
                size: MediaQuery.textScalerOf(context).scale(12).clamp(12, 18),
                color: ink.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text.rich(
                  TextSpan(children: spans),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: base,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
