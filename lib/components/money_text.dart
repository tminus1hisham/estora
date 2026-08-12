import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/money.dart';

/// Renders a [Money] amount.
///
/// Amounts are always shown exactly as the server supplied them. Nothing here
/// recalculates a total from component parts — section 84 rule 7 puts that
/// responsibility on the server, and section 55 requires historical documents
/// to keep the figures they were issued with.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.style,
    this.bare = false,
    this.compact = false,
    this.emphasise = false,
    this.color,
    this.scaleDown = true,
    this.textAlign,
    super.key,
  });

  final Money amount;

  /// Drops the currency code, for line items under a currency header.
  final bool bare;

  /// `KES 1.2M` instead of `KES 1,200,000`, for tight dashboard tiles.
  final bool compact;

  /// Renders larger and bolder, for the headline figure on a screen.
  final bool emphasise;

  final TextStyle? style;
  final Color? color;

  /// Keeps the full amount on one line and scales it down when its parent
  /// provides a finite width. Set false to let the amount wrap naturally.
  final bool scaleDown;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text = compact
        ? amount.formatCompact()
        : bare
        ? amount.formatBare()
        : amount.format();

    final base = emphasise
        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: AppTypography.extraBold,
          )
        : Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: AppTypography.bold);

    final amountText = Text(
      text,
      style: (style ?? base)?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      textAlign: textAlign,
      softWrap: !scaleDown,
      maxLines: scaleDown ? 1 : null,
    );

    if (!scaleDown) return amountText;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: amountText,
    );
  }
}
