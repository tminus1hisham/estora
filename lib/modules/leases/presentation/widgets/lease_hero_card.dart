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
///
/// The card is drawn to a tight rhythm on purpose. A tenant can hold more than
/// one lease — section 54 makes a renewal a new record rather than an edit of
/// the old one — so this surface has to state the tenancy without taking the
/// whole viewport and pushing the rest of the record below the fold.
class LeaseHeroCard extends StatelessWidget {
  const LeaseHeroCard({
    required this.lease,
    this.actions = const <Widget>[],
    this.actionMinWidth = 140,
    this.showLeaseNumber = false,
    super.key,
  });

  final Lease lease;

  /// Side by side under the facts they act on, while each still has room to
  /// say what it is.
  final List<Widget> actions;

  /// The narrowest an action may get before the pair stacks instead.
  ///
  /// The default lets two short labels sit across a phone, which is what keeps
  /// the card short. Raise it for a longer label — a glyph and "Review and
  /// sign" need more than half a phone, and half a sentence on a button the
  /// tenant is being asked to press is worse than two rows.
  final double actionMinWidth;

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
            top: -70,
            right: -60,
            child: SoftGlow(
              color: toneColor.withValues(alpha: 0.26),
              size: 190,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: SoftGlow(
              color: AppPalette.brass500.withValues(alpha: 0.12),
              size: 215,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: kOnDark,
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                      if ((lease.propertyName ?? '').isNotEmpty) ...[
                        Gap.h4,
                        Text(
                          lease.propertyName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kOnDark.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Gap.h16,
                GlassSurface(
                  onDark: true,
                  padding: const EdgeInsets.all(Gap.md),
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
                      Gap.h12,
                      const Hairline(onDark: true, alpha: 0.12),
                      Gap.h12,
                      _Term(lease: lease, color: toneColor),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  Gap.h16,
                  // One row. Two short labels fit across a phone, and a row
                  // costs the card one control height where a stack costs it
                  // two — which is the difference between a tenant seeing the
                  // rest of their record and scrolling for it.
                  ActionRow(actions: actions, minWidth: actionMinWidth),
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
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: AppTypography.semibold,
      ),
    );

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
        Gap.h8,
        LinearMeter(
          value: leaseTermProgress(lease),
          color: color,
          trackColor: kOnDark.withValues(alpha: 0.16),
        ),
        Gap.h8,
        // The two dates used to label the ends of the bar from opposite sides
        // of the card. On a card this tight that row was mostly gap, so the
        // term is written out once instead — one line, at any text size.
        Text(
          '${AppDate.short(lease.startDate)} – '
          '${AppDate.short(lease.endDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
