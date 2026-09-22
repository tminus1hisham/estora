import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/page_header.dart';
import '../../../components/section_card.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/money.dart';
import '../../../navigation/routes.dart';
import '../application/utility_controller.dart';
import '../application/utility_models.dart';
import 'widgets/utility_widgets.dart';

/// Water and electricity for the tenant's space.
///
/// The module has no API behind it, so everything here comes from
/// [utilityAccountsProvider]. The screen says so once, plainly, near the top:
/// a preview that looks like live data and never admits it is the one thing
/// that would cost a tenant's trust when the real meters arrive.
class UtilitiesScreen extends ConsumerWidget {
  const UtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(utilityAccountsProvider);
    final bills = ref.watch(utilityBillsProvider);

    final sections = <Widget>[
      const PageHeader(
        eyebrow: 'Your space',
        title: 'Water and electricity',
        subtitle: 'Both meters, what they have used, and what is owed.',
      ),
      const UtilityPreviewNote(),
      const _DueSummary(),
      for (final account in accounts)
        UtilityAccountCard(
          account: account,
          // Through the router, so the meter it opens is in the address and
          // the page arrives with the app's own transition.
          onTap: () => context.pushNamed(
            Routes.utilityDetail,
            pathParameters: {'kind': account.kind.slug},
          ),
        ),
      _RecentBills(bills: bills),
      SurfaceAction(
        label: 'Submit a meter reading',
        icon: Icons.speed_rounded,
        primary: true,
        onPressed: () => showSubmitReadingSheet(context),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Utilities')),
      body: AppRefreshIndicator(
        onRefresh: () => ref.read(utilityAccountsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, section) in sections.indexed) ...[
                      if (index > 0) Gap.h16,
                      AppReveal(index: index, child: section),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one figure the screen exists to answer: what the meters have cost.
///
/// Anything already late is named separately rather than folded into the
/// total. A tenant who owes last month's electricity as well as this month's
/// should be told which part is which, not handed one larger number.
class _DueSummary extends ConsumerWidget {
  const _DueSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = ref.watch(utilityTotalDueProvider);
    final overdue = ref.watch(utilityOverdueTotalProvider);
    final settled = total.isZero;

    return AppSurfaceCard(
      borderColor: overdue.isPositive
          ? context.statusColors.danger.withValues(alpha: 0.34)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgedHeader(
            badge: StatusChip(
              label: settled
                  ? 'Settled'
                  : overdue.isPositive
                  ? 'Overdue'
                  : 'Due',
              tone: settled
                  ? StatusTone.positive
                  : overdue.isPositive
                  ? StatusTone.danger
                  : StatusTone.warning,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Due this month',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Gap.h8,
                AmountText(
                  total,
                  scale: AmountScale.hero,
                  color: overdue.isPositive ? scheme.error : scheme.onSurface,
                ),
              ],
            ),
          ),
          Gap.h12,
          Text(
            _caption(total, overdue),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _caption(Money total, Money overdue) {
    if (total.isZero) return 'Both meters are paid up. Nothing outstanding.';
    if (overdue.isPositive) {
      return 'Water and electricity together, including '
          '${overdue.format()} already past its due date.';
    }
    return 'Water and electricity together.';
  }
}

/// The last few bills from both meters, interleaved.
///
/// A ledger rather than a to-do list: bills are settled from the meter's own
/// screen, where the tenant can see what the month actually used.
class _RecentBills extends StatelessWidget {
  const _RecentBills({required this.bills});

  final List<UtilityBill> bills;

  @override
  Widget build(BuildContext context) {
    final recent = bills.take(6).toList();

    return SectionCard(
      title: 'Recent bills',
      children: [
        if (recent.isEmpty)
          Text(
            'No bills yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final (index, bill) in recent.indexed) ...[
          if (index > 0) const Hairline(),
          UtilityBillTile(bill: bill),
        ],
      ],
    );
  }
}
