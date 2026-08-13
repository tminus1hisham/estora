import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_glass.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/lease.dart';
import 'lease_facts.dart';

/// The tenancy itself, on the brand surface.
///
/// A lease is a period of time and a monthly figure, and the old card said both
/// in small print at the bottom of a list item. Here the term is drawn — a bar
/// filling as the year runs down — and the rent is set at reading size, so the
/// two questions a tenant actually has ("how long have I got", "what am I
/// paying") are answered before anything is tapped.
class LeaseHeroCard extends StatelessWidget {
  const LeaseHeroCard({
    required this.lease,
    this.actions = const <Widget>[],
    this.showLeaseNumber = false,
    super.key,
  });

  final Lease lease;

  /// Laid out side by side, or stacked once the text is large.
  final List<Widget> actions;

  /// Set on the detail screen, where the lease number is the record's name and
  /// not just a reference.
  final bool showLeaseNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = leaseTermTone(lease);
    final toneColor = StatusColors.dark.resolve(tone);

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.navy950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: SoftGlow(
              color: toneColor.withValues(alpha: 0.26),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: SoftGlow(
              color: AppPalette.brass500.withValues(alpha: 0.12),
              size: 250,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgedHeader(
                  badge: TonePill(
                    label: lease.status.label,
                    tone: lease.status.tone,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showLeaseNumber) ...[
                        Text(
                          lease.leaseNumber.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: kOnDark.withValues(alpha: 0.62),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Gap.h4,
                      ],
                      Text(
                        'Unit ${lease.unitNumber ?? '—'}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: kOnDark,
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                      if ((lease.propertyName ?? '').isNotEmpty) ...[
                        Gap.h4,
                        Text(
                          lease.propertyName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kOnDark.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Gap.h24,
                GlassSurface(
                  onDark: true,
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatRow(
                        onDark: true,
                        left: Stat(
                          'Monthly rent',
                          builder: (context, align) => AmountText(
                            lease.monthlyRent,
                            scale: AmountScale.title,
                            color: kOnDark,
                            align: align,
                          ),
                        ),
                        right: Stat(
                          'Rent due',
                          value:
                              '${ordinalDay(lease.paymentDueDay)} of the month',
                        ),
                      ),
                      Gap.h16,
                      const Hairline(onDark: true, alpha: 0.12),
                      Gap.h16,
                      _Term(lease: lease, color: toneColor),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  Gap.h24,
                  // "Review and sign" with its glyph needs more room than a
                  // phone leaves for half a row, so this pair stacks earlier
                  // than the default.
                  ActionRow(actions: actions, minWidth: 172),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The term, drawn.
class _Term extends StatelessWidget {
  const _Term({required this.lease, required this.color});

  final Lease lease;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = kOnDark.withValues(alpha: 0.62);
    final stacked = prefersStacked(context);

    final label = Text(
      'TERM',
      style: theme.textTheme.labelSmall?.copyWith(
        color: muted,
        letterSpacing: 1.2,
      ),
    );
    final remaining = Text(
      leaseTermCaption(lease),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: AppTypography.semibold,
      ),
    );
    final dateStyle = theme.textTheme.bodySmall?.copyWith(color: muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stacked) ...[
          label,
          Gap.h4,
          remaining,
        ] else
          Row(
            children: [
              Expanded(child: label),
              Gap.w12,
              Flexible(child: remaining),
            ],
          ),
        Gap.h12,
        LinearMeter(
          value: leaseTermProgress(lease),
          color: color,
          trackColor: kOnDark.withValues(alpha: 0.16),
        ),
        Gap.h12,
        // Side by side the two dates label the ends of the bar above them.
        // Once the text is large enough that they no longer fit, they read
        // better as the term written out in one line.
        if (stacked)
          Text(
            '${AppDate.short(lease.startDate)} – '
            '${AppDate.short(lease.endDate)}',
            style: dateStyle,
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  AppDate.short(lease.startDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dateStyle,
                ),
              ),
              Gap.w12,
              Flexible(
                child: Text(
                  AppDate.short(lease.endDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dateStyle,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
