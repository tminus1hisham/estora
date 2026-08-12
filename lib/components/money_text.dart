import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final text = compact
        ? amount.formatCompact()
        : bare
        ? amount.formatBare()
        : amount.format();

    final base = emphasise
        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          )
        : Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);

    return Text(
      text,
      style: (style ?? base)?.copyWith(color: color),
      // Amounts must never be silently truncated on a narrow screen.
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
