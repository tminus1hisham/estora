import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_media.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../components/unit_status_strip.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../domain/entities/owner.dart';

/// One property in the owner's list.
///
/// A card rather than a `RecordRow`, and the exception is the one `RecordGroup`
/// names explicitly: entries carrying photography are cards, because looking at
/// them is part of the point. An owner picking between two malls is looking at
/// the buildings as much as at the figures.
class OwnerPropertyCard extends StatelessWidget {
  const OwnerPropertyCard({required this.performance, this.onTap, super.key});

  final PropertyPerformance performance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statuses = context.statusColors;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel:
          '${performance.propertyName}, '
          '${(performance.occupancyRate * 100).round()} per cent let',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMedia(
            source: performance.imageUrl,
            height: 132,
            semanticLabel: performance.propertyName,
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        performance.propertyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (performance.rateLabel != null) ...[
                      Gap.w8,
                      Text(
                        performance.rateLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                Gap.h16,
                UnitStatusStrip(mix: performance.mix),
                Gap.h16,
                const Hairline(),
                Gap.h16,
                StatRow(
                  left: Stat(
                    'Rent roll',
                    builder: (context, align) => AmountText(
                      performance.monthlyContractedRent,
                      align: align,
                    ),
                  ),
                  right: Stat(
                    performance.overdue.isPositive ? 'Overdue' : 'Outstanding',
                    builder: (context, align) => AmountText(
                      performance.overdue.isPositive
                          ? performance.overdue
                          : performance.outstanding,
                      color: performance.overdue.isPositive
                          ? statuses.danger
                          : null,
                      align: align,
                    ),
                  ),
                ),
                if (performance.hasArrears ||
                    performance.expiringLeases > 0) ...[
                  Gap.h12,
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      if (performance.hasArrears)
                        _Flag(
                          label: '${performance.tenantsInArrears} in arrears',
                          tone: StatusTone.danger,
                        ),
                      if (performance.expiringLeases > 0)
                        _Flag(
                          label: '${performance.expiringLeases} expiring',
                          tone: StatusTone.warning,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colour = context.statusColors.resolve(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colour.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colour),
      ),
    );
  }
}
