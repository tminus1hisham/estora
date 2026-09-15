import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/collection_columns.dart';
import '../../../components/money_count_up.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/owner.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';

/// Section 88. Money in.
///
/// What arrived this month, what is still owed and for how long, and the
/// record of arrivals. The ageing bands are the point of the screen: an owner
/// with KES 400,000 outstanding cares a great deal whether it is three days
/// late or three months.
class OwnerMoneyScreen extends ConsumerWidget {
  const OwnerMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ownerLedgerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Money'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Payouts',
            onPressed: () => context.pushNamed(Routes.ownerPayouts),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          // What actually arrived, as opposed to what the ledger says is owed.
          // Two different questions, so two entries rather than one.
          PopupMenuButton<String>(
            tooltip: 'Received',
            icon: const Icon(Icons.inbox_outlined),
            onSelected: (action) => context.pushNamed(
              action == 'mpesa'
                  ? Routes.mpesaTransactions
                  : Routes.bankPayments,
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'mpesa', child: Text('M-Pesa payments')),
              PopupMenuItem(value: 'bank', child: Text('Bank payments')),
            ],
          ),
          Gap.w8,
        ],
      ),
      body: switch (ledger) {
        AsyncLoading() when !ledger.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(error: UnsupportedFeatureFailure()) => PageEmptyState(
          onRefresh: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
          icon: Icons.account_balance_wallet_outlined,
          caption: 'Your money overview',
          title: 'Money overview is on its way',
          message:
              'Collections, outstanding balances and payouts will appear here when money tracking is available.',
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
        ),
        _ => _Money(
          ledger: ledger.requireValue,
          onRefresh: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.ledger, required this.onRefresh});

  final OwnerLedger ledger;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (ledger.collectedThisMonth.isZero &&
        ledger.platformFeeThisMonth.isZero &&
        ledger.netThisMonth.isZero &&
        ledger.totalOutstanding.isZero &&
        !ledger.hasArrears &&
        ledger.collections.isEmpty &&
        ledger.history.isEmpty &&
        ledger.payouts.isEmpty) {
      return PageEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Your money overview',
        title: 'No money activity yet',
        message:
            'Once payments arrive, you can follow collections, outstanding balances and payouts here.',
        onRefresh: onRefresh,
      );
    }
    final sections = <Widget>[
      _CollectedCard(ledger: ledger),
      if (ledger.hasArrears) _Ageing(buckets: ledger.ageing),
      if (ledger.collections.isNotEmpty)
        _Collections(collections: ledger.collections),
    ];

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}

class _CollectedCard extends StatelessWidget {
  const _CollectedCard({required this.ledger});

  final OwnerLedger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      children: [
        Text(
          'COLLECTED THIS MONTH',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        Gap.h12,
        MoneyCountUp(ledger.collectedThisMonth, scale: AmountScale.hero),
        Gap.h8,
        Text(
          '${ledger.netThisMonth.format()} due to you after '
          '${ledger.platformFeeThisMonth.format()} in platform fees.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (ledger.history.isNotEmpty) ...[
          Gap.h24,
          CollectionColumns(months: ledger.history, height: 110),
        ],
      ],
    );
  }
}

/// Outstanding money, banded by how long it has been owed.
class _Ageing extends StatelessWidget {
  const _Ageing({required this.buckets});

  final List<ArrearsBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final showing = buckets.where((bucket) => !bucket.isEmpty).toList();

    return RecordGroup(
      heading: 'Owed to you',
      children: [
        for (final (index, bucket) in showing.indexed)
          RecordRow(
            icon: index == 0
                ? Icons.schedule_rounded
                : Icons.warning_amber_rounded,
            // The bands darken as they age, which is the only thing the icons
            // and colours here are being asked to say.
            iconColor: statuses.resolve(switch (bucket.label) {
              'Not yet due' => StatusTone.neutral,
              '1–30 days' => StatusTone.warning,
              _ => StatusTone.danger,
            }),
            title: bucket.label,
            subtitle:
                '${bucket.invoiceCount} invoice'
                '${bucket.invoiceCount == 1 ? '' : 's'}',
            amount: AmountText(bucket.amount),
          ),
      ],
    );
  }
}

class _Collections extends StatelessWidget {
  const _Collections({required this.collections});

  final List<OwnerCollection> collections;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final months = <DateTime, List<OwnerCollection>>{};

    for (final collection in collections) {
      final key = DateTime(collection.paidAt.year, collection.paidAt.month);
      months.putIfAbsent(key, () => []).add(collection);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in months.entries.indexed) ...[
          if (index > 0) Gap.h24,
          RecordGroup(
            heading: AppDate.monthYear(entry.key),
            children: [
              for (final collection in entry.value)
                RecordRow(
                  icon: Icons.south_west_rounded,
                  iconColor: statuses.positive,
                  title: collection.tenantName,
                  subtitle: collection.unitNumber == null
                      ? collection.propertyName
                      : '${collection.unitNumber} · '
                            '${collection.propertyName}',
                  amount: AmountText(collection.amount),
                  caption: AppDate.short(collection.paidAt),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
