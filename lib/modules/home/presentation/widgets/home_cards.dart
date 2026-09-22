import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/status_chip.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/dashboard_summary.dart';
import '../../../../navigation/routes.dart';
import 'home_atoms.dart';

/// The last few payments, as a short ledger.
///
/// Three at most. This is a reassurance that money arrived, not the payment
/// history — that has its own screen, one tap away.
class RecentPaymentsCard extends StatelessWidget {
  const RecentPaymentsCard({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final payments = summary.recentPayments.take(3).toList();

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent payments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              Gap.w12,
              TextButton(
                onPressed: () => context.goNamed(
                  Routes.invoices,
                  queryParameters: {
                    Routes.invoicesTabQuery: Routes.invoicesTransactionsTab,
                  },
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          Gap.h8,
          for (final (index, payment) in payments.indexed) ...[
            if (index > 0)
              Divider(
                height: Gap.lg,
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Row(
                children: [
                  ToneIconTile(
                    icon: _iconFor(payment.status.tone),
                    color: context.statusColors.resolve(payment.status.tone),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.invoiceNumber ?? payment.paymentReference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: AppTypography.semibold,
                          ),
                        ),
                        Text(
                          payment.paidAt == null
                              ? payment.status.label
                              : AppDate.short(payment.paidAt!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.w8,
                  // Stacked rather than strung along the row: at large text
                  // sizes an amount and a chip side by side leave the invoice
                  // number nothing to live in.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AmountText(
                        payment.amount,
                        showCurrency: false,
                        align: TextAlign.end,
                      ),
                      Gap.h4,
                      StatusChip(
                        label: payment.status.label,
                        tone: payment.status.tone,
                        dense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Gap.h8,
        ],
      ),
    );
  }

  static IconData _iconFor(StatusTone tone) => switch (tone) {
    StatusTone.positive => Icons.check_circle_rounded,
    StatusTone.progress => Icons.schedule_rounded,
    StatusTone.danger => Icons.error_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

/// Shown to a tenant with no lease yet, pointing them at Browse.
class NoTenancyCard extends StatelessWidget {
  const NoTenancyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIconTile(
            icon: Icons.storefront_rounded,
            color: scheme.primary,
            size: 48,
          ),
          Gap.h16,
          Text(
            'Spaces you can take today',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTypography.bold,
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
          // Filled rather than tonal. For a tenant with no lease this is the
          // only thing on the screen worth doing, and the stone tonal fill
          // reads as a secondary action beside the balance card above it.
          FilledButton.icon(
            onPressed: () => context.pushNamed(Routes.browse),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppLayout.controlHeight),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Browse available units'),
          ),
        ],
      ),
    );
  }
}
