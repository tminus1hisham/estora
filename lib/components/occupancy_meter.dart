import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';
import '../domain/entities/owner.dart';
import 'surface_atoms.dart';

/// How much of a property or block is let: the figure, and the bar beneath.
///
/// The bar is a [LinearMeter] and passes the test its doc comment sets — let
/// over all is a genuine proportion. The count sits with the figure because
/// 72% of four units and 72% of forty are different facts, and an owner
/// deciding what to do next needs the second one.
///
/// [dense] folds it to one line for a card that is mostly photograph: the
/// bar, then `72% let`. Its fill is the same green the status strip gives to
/// "let", so the two read as one vocabulary wherever they sit together.
class OccupancyMeter extends StatelessWidget {
  const OccupancyMeter({
    required this.mix,
    this.dense = false,
    this.label = 'Occupancy',
    super.key,
  });

  final UnitMix mix;
  final bool dense;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statuses = context.statusColors;

    final semantics =
        '${mix.occupancyPercent} per cent let, ${mix.occupancyLabel}';

    if (dense) {
      return Semantics(
        label: semantics,
        child: ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: LinearMeter(
                  value: mix.occupancy,
                  color: statuses.positive,
                ),
              ),
              Gap.w12,
              Text(
                '${mix.occupancyPercent}% let',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Gap.w12,
                Text(
                  mix.occupancyLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Gap.h4,
            Text(
              '${mix.occupancyPercent}%',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: AppTypography.medium,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Gap.h8,
            LinearMeter(value: mix.occupancy, color: statuses.positive),
          ],
        ),
      ),
    );
  }
}
