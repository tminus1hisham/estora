import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/owner.dart';
import '../application/owner_controller.dart';

/// Section 41. What is due out to the owner, month by month.
///
/// Gross, fee, net — three lines, and the fee is one of them rather than being
/// quietly deducted. `MockServer` records the platform's cut as its own ledger
/// entry on every settlement for exactly this reason: both figures stay
/// auditable, and an owner can see what they were charged rather than
/// inferring it from a smaller number than they expected.
class OwnerPayoutsScreen extends ConsumerWidget {
  const OwnerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ownerLedgerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Payouts'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (ledger) {
        AsyncLoading() when !ledger.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(ownerLedgerProvider),
        ),
        _ => _Payouts(
          ledger: ledger.requireValue,
          onRefresh: () async => ref.invalidate(ownerLedgerProvider),
        ),
      },
    );
  }
}

class _Payouts extends StatelessWidget {
  const _Payouts({required this.ledger, required this.onRefresh});

  final OwnerLedger ledger;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Newest first: the month an owner is asking about is almost always the
    // last one, and scrolling to the bottom to find it would be perverse.
    final months = ledger.payouts.reversed
        .where((payout) => !payout.isEmpty)
        .toList(growable: false);

    if (months.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Nothing paid out yet',
                message:
                    'Once rent is collected, what is due to you appears here '
                    'month by month.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: months.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) => AppReveal(
              index: index,
              child: _PayoutCard(payout: months[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final OwnerPayout payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = context.statusColors;

    return SectionCard(
      title: AppDate.monthYear(payout.month),
      children: [
        DetailRow(
          label: 'Collected',
          valueWidget: AmountText(payout.grossCollected, align: TextAlign.end),
        ),
        DetailRow(
          label: 'Platform fee',
          valueWidget: AmountText(
            -payout.platformFee,
            align: TextAlign.end,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Gap.h12,
        const Hairline(),
        Gap.h12,
        DetailRow(
          label: 'Due to you',
          valueWidget: AmountText(
            payout.net,
            scale: AmountScale.title,
            align: TextAlign.end,
            color: statuses.positive,
          ),
          emphasise: true,
        ),
      ],
    );
  }
}
