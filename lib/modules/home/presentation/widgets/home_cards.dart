import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/glass_well.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import 'home_atoms.dart';

/// The last few payments, as a short ledger.
///
/// Three at most. This is a reassurance that money arrived, not the payment
/// history — that has its own screen, one tap away.
///
/// Set as an iOS inset-grouped list: a small-caps label over one pane, the
/// rows inside it split by hairlines that start where the text does. One pane
/// holding three lines reads as one statement; three cards read as three
/// things to look at, which a reassurance should never be.
class RecentPaymentsCard extends StatelessWidget {
  const RecentPaymentsCard({required this.summary, super.key});

  final DashboardSummary summary;

  /// The status well's size, and so where the separators start.
  static const double _well = 34;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payments = summary.recentPayments.take(3).toList();

    void seeAll() => context.goNamed(
      Routes.invoices,
      queryParameters: {
        Routes.invoicesTabQuery: Routes.invoicesTransactionsTab,
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionLabel(
          'Recent payments',
          // A tinted word rather than a button: in a grouped list's header
          // the link is part of the heading, and a button's plate beside a
          // small-caps label is the loudest thing in the group.
          trailing: GlassTap(
            onTap: seeAll,
            semanticLabel: 'See all payments',
            child: ExcludeSemantics(
              child: Padding(
                // Taller than it looks, so the word is a fair target; the
                // extra reaches up into the space between groups.
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.xs, 0),
                child: Text(
                  'See all',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ),
            ),
          ),
        ),
        FrostedPane(
          radius: GlassRadius.card,
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            children: [
              for (final (index, payment) in payments.indexed) ...[
                if (index > 0)
                  const Padding(
                    // Inset to the text, as iOS does: the wells stay one
                    // unbroken column down the leading edge.
                    padding: EdgeInsetsDirectional.only(
                      start: Gap.lg + _well + Gap.md,
                    ),
                    child: _GlassSeparator(),
                  ),
                _PaymentRow(
                  payment: payment,
                  well: _well,
                  onTap: _destination(context, payment) ?? seeAll,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Where a row leads: its receipt once there is one, its live status while
  /// the money is still moving, and otherwise the payment history it came
  /// from. `go` rather than `push`, because both of the first two live on the
  /// Billing tab, and opening them over Home would leave the tenant in a
  /// Billing screen with the wrong tab lit beneath it.
  static VoidCallback? _destination(BuildContext context, Payment payment) {
    if (payment.hasReceipt) {
      return () => context.goNamed(
        Routes.receipt,
        pathParameters: {'receiptId': payment.receiptId!},
      );
    }
    if (payment.isInFlight) {
      return () => context.goNamed(
        Routes.paymentStatus,
        pathParameters: {'paymentId': payment.id},
      );
    }
    return null;
  }
}

/// The rule between rows of a grouped pane.
///
/// Not the theme's outline, which is a cream-on-cream grey that disappears
/// into milk glass: a half-point line of ink in light mode and of light in
/// dark mode, which is how iOS separates the cells of an inset group.
class _GlassSeparator extends StatelessWidget {
  const _GlassSeparator();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 0.5,
      child: ColoredBox(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : AppPalette.navy900.withValues(alpha: 0.13),
      ),
    );
  }
}

/// One line of the recent-payments ledger.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.well,
    required this.onTap,
  });

  final Payment payment;
  final double well;
  final VoidCallback onTap;

  static IconData _iconFor(StatusTone tone) => switch (tone) {
    StatusTone.positive => Icons.check_rounded,
    StatusTone.progress => Icons.schedule_rounded,
    StatusTone.danger => Icons.priority_high_rounded,
    _ => Icons.receipt_long_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = payment.status.tone;
    final color = context.statusColors.resolve(tone);
    final stacked = homePrefersStacked(context);

    final title = Text(
      payment.invoiceNumber ?? payment.paymentReference,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: AppTypography.semibold,
        letterSpacing: -0.2,
      ),
    );
    // Always a date — when it settled, or when it was attempted. The status
    // is said once, in its colour beside the amount; saying it here too, as
    // the old ledger did for anything unsettled, read "Failed … Failed".
    final date = Text(
      AppDate.short(payment.paidAt ?? payment.createdAt),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
    final amount = AmountText(
      payment.amount,
      showCurrency: false,
      weight: AppTypography.medium,
      align: stacked ? TextAlign.start : TextAlign.end,
    );
    // The status as a word in its own colour rather than a chip: the well
    // already carries the colour, and a tinted plate on glass is one surface
    // too many for a line of a ledger.
    final status = Text(
      payment.status.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: AppTypography.semibold,
      ),
    );

    return GlassTap(
      onTap: onTap,
      scale: 0.985,
      semanticLabel:
          '${payment.invoiceNumber ?? payment.paymentReference}, '
          '${payment.amount.format()}, ${payment.status.label}, '
          '${AppDate.short(payment.paidAt ?? payment.createdAt)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Gap.lg,
            Gap.md,
            Gap.md,
            Gap.md,
          ),
          child: Row(
            children: [
              GlassWell(icon: _iconFor(tone), color: color, size: well),
              Gap.w12,
              Expanded(
                // At large text sizes an amount and its status beside the
                // invoice number leave the number nothing to live in, so the
                // figures drop under it instead.
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, date, Gap.h4, amount, status],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [title, date],
                            ),
                          ),
                          Gap.w8,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              amount,
                              const SizedBox(height: 2),
                              status,
                            ],
                          ),
                        ],
                      ),
              ),
              Gap.w4,
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown to a tenant with no lease yet, pointing them at Browse.
class NoTenancyCard extends StatelessWidget {
  const NoTenancyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FrostedPane(
      // Lit azure from the corner, the colour of the one thing to do here.
      tone: scheme.primary,
      padding: const EdgeInsets.all(Gap.lg + Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassWell(
            icon: Icons.storefront_rounded,
            color: scheme.primary,
            size: 52,
          ),
          Gap.h16,
          Text(
            'Spaces you can take today',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTypography.semibold,
              letterSpacing: -0.3,
            ),
          ),
          Gap.h8,
          Text(
            'Retail units, kiosks and office suites across the portfolio, with '
            'the rent and deposit stated up front.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Gap.h16,
          // Lit rather than clear. For a tenant with no lease this is the only
          // thing on the screen worth doing, and a clear capsule would read
          // as a secondary action beside the balance card above it.
          GlassCapsuleButton(
            label: 'Browse available units',
            icon: Icons.search_rounded,
            expand: true,
            onPressed: () => context.pushNamed(Routes.browse),
          ),
        ],
      ),
    );
  }
}
