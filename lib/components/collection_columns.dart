import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';
import '../domain/entities/owner.dart';

/// Billed against collected, month by month.
///
/// The app's only chart, and it stays a chart rather than becoming a charting
/// library: no axes, no gridlines, no legend chrome. A column per month, the
/// faint bar being what was invoiced and the solid one what actually arrived.
/// The gap between them is the whole message.
///
/// The solid bar can be **taller** than the faint one. That is not a bug and is
/// not clamped: a deposit invoiced in one month and paid in the next collects
/// more than that month billed, and flattening it would hide exactly the kind
/// of timing an owner is looking for. Both are measured against whichever is
/// larger across the whole series.
class CollectionColumns extends StatelessWidget {
  const CollectionColumns({required this.months, this.height = 132, super.key});

  final List<MonthlyCollection> months;

  /// The plotting area, excluding the month labels beneath it.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collectedColour = context.statusColors.resolve(StatusTone.positive);

    // Scaled to the largest figure in the series, billed or collected, so no
    // bar can run past the top of its column.
    var ceiling = 0;
    for (final month in months) {
      final tallest = month.billed.minorUnits > month.collected.minorUnits
          ? month.billed.minorUnits
          : month.collected.minorUnits;
      if (tallest > ceiling) ceiling = tallest;
    }
    if (ceiling == 0) return const SizedBox.shrink();

    final settled = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: settled ? 1 : 0, end: 1),
      duration: settled ? Duration.zero : AppMotion.slow,
      curve: AppMotion.emphasized,
      builder: (context, t, _) {
        // The bars and their labels are two rows rather than one row of
        // labelled columns. A single fixed-height column has to guess how tall
        // a month initial is, and that guess is wrong the moment the platform
        // text size moves — which is exactly where it was overflowing.
        return Semantics(
          label: _semanticsLabel,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final month in months)
                      Expanded(
                        child: _Bar(
                          billed: month.billed.minorUnits / ceiling * t,
                          collected: month.collected.minorUnits / ceiling * t,
                          trackColour: scheme.onSurfaceVariant.withValues(
                            alpha: 0.22,
                          ),
                          fillColour: collectedColour,
                        ),
                      ),
                  ],
                ),
              ),
              Gap.h8,
              Row(
                children: [
                  for (final month in months)
                    Expanded(
                      child: Text(
                        _initial(month.month),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The chart as one sentence, since the bars themselves say nothing to a
  /// screen reader.
  String get _semanticsLabel {
    final parts = months.map(
      (month) =>
          '${_monthName(month.month)}: '
          '${month.collected.format()} collected of ${month.billed.format()}',
    );
    return 'Collection over ${months.length} months. ${parts.join('. ')}';
  }

  static String _initial(DateTime month) => _monthName(month).substring(0, 1);

  static String _monthName(DateTime date) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][date.month - 1];
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.billed,
    required this.collected,
    required this.trackColour,
    required this.fillColour,
  });

  /// Both are fractions of the plotting height, already animated.
  final double billed;
  final double collected;

  final Color trackColour;
  final Color fillColour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Billed: the full width of the column, faint.
          FractionallySizedBox(
            heightFactor: billed.clamp(0.0, 1.0),
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackColour,
                borderRadius: AppRadius.small,
              ),
            ),
          ),
          // Collected: narrower and solid, so both stay readable where they
          // nearly coincide.
          FractionallySizedBox(
            heightFactor: collected.clamp(0.0, 1.0),
            widthFactor: 0.56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [fillColour.withValues(alpha: 0.62), fillColour],
                ),
                borderRadius: AppRadius.small,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
