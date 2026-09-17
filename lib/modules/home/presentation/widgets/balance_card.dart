import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/money_count_up.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import '../../../invoices/presentation/widgets/pay_invoice.dart';
import 'home_atoms.dart';

/// Outstanding balance, next invoice and next due date.
///
/// The one surface on the screen that is allowed to be loud, and the reason
/// most tenants opened the app. It stays dark in both themes, the way a bank
/// card does, and it overlaps the foot of the header so it reads as sitting
/// *on* the screen rather than as the first row of a list.
///
/// The figure counts up once as the card arrives and a single light passes
/// over it. Both are one-shot and both are skipped under reduced motion.
class BalanceCard extends StatelessWidget {
  const BalanceCard({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusTone) = _status();
    final stacked = homePrefersStacked(context);

    final label = Text(
      'OUTSTANDING BALANCE',
      style: theme.textTheme.labelSmall?.copyWith(
        color: kHomeOnDark.withValues(alpha: 0.62),
        letterSpacing: 1.2,
      ),
    );
    final pill = TonePill(label: statusLabel, tone: statusTone);
    final amount = MoneyCountUp(
      summary.outstandingBalance,
      // The largest figure in the app, and the screen is built around it — but
      // it is set at the same weight as every other amount. Its size, its
      // colour and the dark card under it already carry the emphasis; adding
      // weight on top made a tenant who is up to date read as one in trouble.
      scale: AmountScale.hero,
      color: summary.hasOverdue ? AppPalette.red300 : kHomeOnDark,
      delay: const Duration(milliseconds: 260),
    );

    final card = AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderColor: Colors.transparent,
      // Zero here so the glows below can run off the edges; the content brings
      // its own padding.
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.navy950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          // Two soft lights, clipped by the card, so the gradient reads as a
          // lit surface rather than a printed one.
          Positioned(
            top: -70,
            right: -50,
            child: SoftGlow(
              color: AppPalette.azure500.withValues(alpha: 0.38),
              size: 210,
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: SoftGlow(
              color: AppPalette.brass500.withValues(alpha: 0.12),
              size: 240,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stacked) ...[
                  label,
                  Gap.h8,
                  amount,
                  Gap.h12,
                  pill,
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: label),
                      Gap.w12,
                      pill,
                    ],
                  ),
                  Gap.h8,
                  amount,
                ],
                // How much of the balance is late, which the total above does
                // not say on its own. It replaces the separate overdue banner
                // this screen used to carry: the card is already red, already
                // says Overdue and already offers to pay — a second panel
                // repeating all three taught tenants to scroll past it.
                if (summary.hasOverdue) ...[
                  Gap.h12,
                  Text(
                    '${summary.overdueAmount!.format()} is past its due date.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.red300,
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                ],
                if (summary.nextInvoiceAmount != null) ...[
                  Gap.h24,
                  const Hairline(onDark: true),
                  Gap.h16,
                  _NextInvoice(summary: summary, stacked: stacked),
                ],
                Gap.h24,
                _Actions(summary: summary, stacked: stacked),
              ],
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return card;

    // One light crosses the card shortly after it lands. It is the only moment
    // of shine on the screen; a second one anywhere would make both look cheap.
    return card
        .animate()
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.enter)
        .moveY(
          begin: 22,
          end: 0,
          duration: AppMotion.slow,
          curve: AppMotion.enter,
        )
        .shimmer(
          delay: const Duration(milliseconds: 520),
          duration: const Duration(milliseconds: 1100),
          color: kHomeOnDark.withValues(alpha: 0.22),
        );
  }

  /// What the figure above means, in three words or fewer.
  (String, StatusTone) _status() {
    if (summary.hasOverdue) return ('Overdue', StatusTone.danger);
    if (!summary.hasOutstandingBalance) {
      return ('Up to date', StatusTone.positive);
    }

    final due = summary.nextPaymentDueDate;
    if (due == null) return ('Awaiting payment', StatusTone.progress);

    final now = DateTime.now();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return ('Past due', StatusTone.danger);
    if (days == 0) return ('Due today', StatusTone.warning);
    if (days == 1) return ('Due tomorrow', StatusTone.warning);
    // Neutral rather than `progress`: a date three weeks out is not news, and
    // the informational steel blue muddles against the navy underneath it.
    return ('Due in $days days', StatusTone.neutral);
  }
}

/// The next invoice and the date it is due, as a pair of figures rather than
/// as label/value rows: two numbers side by side read as a statement, and a
/// list of rows reads as small print.
class _NextInvoice extends StatelessWidget {
  const _NextInvoice({required this.summary, required this.stacked});

  final DashboardSummary summary;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final invoice = StatPair(
      label: 'Next invoice',
      value: summary.nextInvoiceAmount!.format(),
      onDark: true,
    );
    final due = summary.nextPaymentDueDate;

    if (due == null) return invoice;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          invoice,
          Gap.h12,
          StatPair(
            label: 'Payment due',
            value: AppDate.short(due),
            onDark: true,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: invoice),
        Gap.w12,
        Expanded(
          child: StatPair(
            label: 'Payment due',
            value: AppDate.short(due),
            align: CrossAxisAlignment.end,
            onDark: true,
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.summary, required this.stacked});

  final DashboardSummary summary;
  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = _Secondary(
      label: 'All invoices',
      onPressed: () => context.goNamed(Routes.invoices),
    );

    if (summary.nextInvoice == null) {
      return _Secondary(
        label: 'View all invoices',
        filled: true,
        onPressed: () => context.goNamed(Routes.invoices),
      );
    }

    final pay = FilledButton.icon(
      onPressed: () => payInvoice(context, ref, summary.nextInvoice!),
      style: FilledButton.styleFrom(
        // Fixed, like the card it sits on. The scheme's primary container is
        // itself dark once the app is in dark mode, which would leave this
        // button invisible against the gradient.
        backgroundColor: AppPalette.azure100,
        foregroundColor: AppPalette.azure950,
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      ),
      icon: const Icon(Icons.payments_rounded, size: 20),
      label: const Text('Pay now'),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [pay, Gap.h8, invoices],
      );
    }

    return Row(
      children: [
        Expanded(flex: 5, child: pay),
        Gap.w12,
        Expanded(flex: 4, child: invoices),
      ],
    );
  }
}

/// The quieter of the card's two actions.
class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Set when this is the only action on the card, and so has to carry it.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: kHomeOnDark,
        backgroundColor: kHomeOnDark.withValues(alpha: filled ? 0.12 : 0.08),
        minimumSize: const Size.fromHeight(AppLayout.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
          side: BorderSide(color: kHomeOnDark.withValues(alpha: 0.2)),
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
