import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/status_palette.dart';
import '../domain/entities/owner.dart';

/// How a property's units are split, drawn as one bar.
///
/// A genuine proportion, which is the test [LinearMeter]'s doc comment sets for
/// whether something may be a bar at all: the segments are shares of a whole
/// that is meaningful, not counts standing next to each other. The numbers are
/// still given in the legend, because "how many units are empty" is a question
/// a bar cannot answer.
class UnitStatusStrip extends StatelessWidget {
  const UnitStatusStrip({
    required this.mix,
    this.height = 10,
    this.showLegend = true,
    super.key,
  });

  final UnitMix mix;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    if (mix.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final statuses = context.statusColors;

    final segments = <({String label, int count, Color colour})>[
      (label: 'Let', count: mix.leased, colour: statuses.positive),
      (label: 'Booked', count: mix.booked, colour: statuses.progress),
      (
        label: 'Available',
        count: mix.available,
        colour: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
      ),
      (label: 'Held', count: mix.unavailable, colour: statuses.warning),
    ].where((segment) => segment.count > 0).toList(growable: false);

    final settled = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: segments
              .map(
                (segment) => '${segment.count} ${segment.label.toLowerCase()}',
              )
              .join(', '),
          child: ClipRRect(
            borderRadius: AppRadius.small,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: settled ? 1 : 0, end: 1),
              duration: settled ? Duration.zero : AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, t, _) => SizedBox(
                height: height,
                child: Row(
                  children: [
                    for (final segment in segments)
                      Expanded(
                        flex: segment.count,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: FractionallySizedBox(
                            widthFactor: t,
                            alignment: AlignmentDirectional.centerStart,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: segment.colour,
                                borderRadius: AppRadius.small,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showLegend) ...[
          Gap.h12,
          Wrap(
            spacing: Gap.lg,
            runSpacing: Gap.sm,
            children: [
              for (final segment in segments)
                _LegendEntry(
                  label: segment.label,
                  count: segment.count,
                  colour: segment.colour,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.count,
    required this.colour,
  });

  final String label;
  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        Gap.w8,
        Text(
          '$count',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppTypography.semibold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Gap.w4,
        Flexible(
          child: Text(
            label.toLowerCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
