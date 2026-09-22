import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/even_grid.dart';
import '../../../../components/glass_material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import 'home_atoms.dart';

/// Two small figures under the balance: when the next payment falls, and where
/// the lease stands.
///
/// The balance card answers "how much". These answer "by when", which is the
/// question a tenant asks second and which the old screen only answered by
/// making them read a row of small print.
class InsightTiles extends StatelessWidget {
  const InsightTiles({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (summary.nextPaymentDueDate != null) _DueTile(summary: summary),
      if (summary.hasTenancy) _LeaseTile(summary: summary),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    // Side by side while the platform's text still allows it; two figures on
    // one line is the whole point of the pair, but not at the cost of
    // truncating either of them. The grid matches their heights, so one tile
    // carrying a meter and the other not leaves no step between them.
    return EvenGrid(
      minTileWidth: 144,
      maxColumns: homePrefersStacked(context) ? 1 : 2,
      children: tiles,
    );
  }
}

/// When the next invoice falls due, and how close that is.
class _DueTile extends StatelessWidget {
  const _DueTile({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final due = summary.nextPaymentDueDate!;
    final now = DateTime.now();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    final (value, tone) = switch (days) {
      < 0 => ('Overdue', StatusTone.danger),
      0 => ('Today', StatusTone.warning),
      1 => ('Tomorrow', StatusTone.warning),
      _ when days <= 7 => ('In $days days', StatusTone.warning),
      _ => ('In $days days', StatusTone.progress),
    };

    return _InsightTile(
      icon: Icons.event_rounded,
      tone: tone,
      label: 'NEXT PAYMENT',
      value: value,
      caption: AppDate.short(due),
      // Full a month out, empty on the day: the bar is time used up, not time
      // left, so a nearly-full bar always means "act soon".
      meter: 1 - (days.clamp(0, 30) / 30),
      onTap: () => context.goNamed(Routes.invoices),
    );
  }
}

/// Where the lease stands, and how long is left on it.
class _LeaseTile extends StatelessWidget {
  const _LeaseTile({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final status = summary.leaseStatus;
    final days = summary.daysUntilLeaseExpiry;
    final expiring = summary.isLeaseExpiringSoon;

    return _InsightTile(
      icon: expiring ? Icons.schedule_rounded : Icons.verified_rounded,
      tone: expiring
          ? (days != null && days <= 30
                ? StatusTone.danger
                : StatusTone.warning)
          : (status?.tone ?? StatusTone.neutral),
      label: 'LEASE',
      value: expiring
          ? (days == 0 ? 'Ends today' : '$days days left')
          : (status?.label ?? 'No lease'),
      caption: summary.leaseEndDate == null
          ? 'Current tenancy'
          : 'Ends ${AppDate.short(summary.leaseEndDate!)}',
      // Only meaningful once the end is in sight; the summary carries no start
      // date, so a bar for the whole term would be invented.
      meter: expiring && days != null ? 1 - (days.clamp(0, 90) / 90) : null,
      onTap: () => context.pushNamed(
        Routes.currentProperty,
        pathParameters: {'leaseId': summary.leaseId!},
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    required this.caption,
    required this.onTap,
    this.meter,
  });

  final IconData icon;
  final StatusTone tone;
  final String label;
  final String value;
  final String caption;
  final VoidCallback onTap;

  /// 0–1, how far along whatever the tile is counting. Null hides the bar.
  final double? meter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = context.statusColors.resolve(tone);

    // A small widget of glass, the way iOS sets a single figure on its home
    // screen: the kind of thing it is in small caps beside its glyph, the
    // figure under it, and the tile faintly lit by what it means — warm as
    // a date comes close, green while a lease is in good standing.
    return GlassTap(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: '${label.toLowerCase()}, $value, $caption',
      child: ExcludeSemantics(
        child: FrostedPane(
          tone: color,
          radius: GlassRadius.card,
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              Gap.h12,
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppTypography.semibold,
                  letterSpacing: -0.2,
                ),
              ),
              Gap.h4,
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (meter != null) ...[
                Gap.h12,
                LinearMeter(value: meter!, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
