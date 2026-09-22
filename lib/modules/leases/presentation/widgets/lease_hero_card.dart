import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_glass.dart';
import '../../../../components/status_chip.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/lease.dart';
import 'lease_facts.dart';

/// The tenancy itself, on glass.
///
/// A lease is a period of time and a monthly figure, and the old card said both
/// in small print at the bottom of a list item. Here the term is drawn — a bar
/// filling as the year runs down — and the rent is set at reading size, so the
/// two questions a tenant actually has ("how long have I got", "what am I
/// paying") are answered before anything is tapped.
///
/// The card used to be a slab of navy. One of those is a statement; a column of
/// them is a wall, and a tenant of any standing has a column, because section
/// 54 makes every renewal a new record rather than an edit of the old one. So
/// the surface is now a pane of glass over its own light, and it is the light
/// that changes from card to card: the term's tone under the top corner, warm
/// under the bottom. The text comes from the colour scheme like everything
/// else on the screen, which is what lets the same card work in both themes.
///
/// The card is also drawn to a tight rhythm on purpose — it has to state the
/// tenancy without taking the whole viewport and pushing the next lease out of
/// sight.
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
    final scheme = theme.colorScheme;
    final toneColor = context.statusColors.resolve(leaseTermTone(lease));

    return GlassCard(
      tone: toneColor,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgedHeader(
            badge: StatusChip(label: lease.status.label, tone: lease.status.tone),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLeaseNumber) ...[
                  Text(
                    lease.leaseNumber.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Gap.h4,
                ],
                Text(
                  'Unit ${lease.unitNumber ?? '—'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                if ((lease.propertyName ?? '').isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    lease.propertyName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Gap.h16,
          // No inset panel. The pane is already a separate material from the
          // page, and a second one inside it is a second blurred layer to
          // composite for a border the hairline below draws for free.
          StatRow(
            left: Stat(
              'Monthly rent',
              builder: (context, align) => AmountText(
                lease.monthlyRent,
                scale: AmountScale.title,
                align: align,
              ),
            ),
            right: Stat(
              'Rent due',
              value: '${ordinalDay(lease.paymentDueDay)} of the month',
            ),
          ),
          Gap.h12,
          const Hairline(alpha: 0.5),
          Gap.h12,
          _Term(lease: lease, color: toneColor),
          if (actions.isNotEmpty) ...[
            Gap.h16,
            // One row. Two short labels fit across a phone, and a row costs the
            // card one control height where a stack costs it two — which is
            // the difference between a tenant seeing the next lease and
            // scrolling for it.
            ActionRow(actions: actions, minWidth: actionMinWidth),
          ],
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
    final muted = theme.colorScheme.onSurfaceVariant;
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
        LinearMeter(value: leaseTermProgress(lease), color: color),
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
