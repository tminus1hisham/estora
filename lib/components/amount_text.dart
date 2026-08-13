import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/money.dart';

/// How large an amount is being set.
///
/// Three steps, deliberately: the figure a screen is about, a figure that
/// closes a group, and a figure in a list. A fourth would only be a way of
/// avoiding the decision about which of the three a number is.
enum AmountScale {
  /// The one figure a screen exists to show.
  hero,

  /// A total, or the headline of a card.
  title,

  /// A figure in a row or a ledger line.
  row,
}

/// Renders a [Money] amount as a muted currency code beside a figure.
///
/// The two halves are set differently on purpose. `KES` is a constant on every
/// line of a Kenyan tenant's statement — it carries no information and so is
/// kept small and grey — while the digits carry all of it and are set in the
/// weight the app reserves for numbers.
///
/// That weight is medium. Amounts used to be drawn extra-bold at display sizes,
/// which made every screen read as an alarm: a tenant who is up to date and a
/// tenant who is three weeks overdue saw the same shouted number. Size and
/// colour now carry the emphasis, and weight is held in reserve.
///
/// As with [MoneyText], amounts are shown exactly as the server supplied them —
/// section 84 rule 7 puts totalling on the server, and nothing here recomputes
/// a figure from its parts.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    this.scale = AmountScale.row,
    this.color,
    this.showCurrency = true,
    this.weight,
    this.align = TextAlign.start,
    this.scaleDown = true,
    super.key,
  });

  final Money amount;
  final AmountScale scale;

  /// The figure's colour. The currency code takes a faded copy of it.
  final Color? color;

  /// Drops the code, for a line item under a header that already states it.
  final bool showCurrency;

  /// Overrides the weight for the scale. Reserved for the rare figure that has
  /// to hold its own against a heavier neighbour.
  final FontWeight? weight;

  final TextAlign align;

  /// Keeps the amount on one line and shrinks it to fit when its parent gives
  /// a finite width — an amount that has been ellipsised is worse than no
  /// amount at all.
  final bool scaleDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.onSurface;

    final (
      double size,
      double code,
      FontWeight bold,
      double tracking,
    ) = switch (scale) {
      AmountScale.hero => (30.0, 12.0, AppTypography.medium, -0.8),
      AmountScale.title => (22.0, 11.0, AppTypography.medium, -0.5),
      AmountScale.row => (16.0, 11.0, AppTypography.semibold, -0.2),
    };

    final text = Text.rich(
      TextSpan(
        children: [
          if (showCurrency)
            TextSpan(
              text: '${amount.currency} ',
              style: TextStyle(
                fontSize: code,
                height: 1.1,
                fontWeight: AppTypography.semibold,
                letterSpacing: 0.7,
                color: resolved.withValues(alpha: 0.55),
              ),
            ),
          TextSpan(
            text: amount.formatBare(),
            style: TextStyle(
              fontSize: size,
              height: 1.1,
              fontWeight: weight ?? bold,
              letterSpacing: tracking,
              color: resolved,
              // Tabular figures so a column of amounts lines up on the decimal
              // and a counting animation does not jitter.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      textAlign: align,
      maxLines: 1,
      softWrap: false,
      // The code and the figure are one number to a screen reader, whatever
      // they look like.
      semanticsLabel: amount.format(),
    );

    if (!scaleDown) return text;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align == TextAlign.end
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: text,
    );
  }
}
