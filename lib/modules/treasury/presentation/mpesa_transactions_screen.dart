import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/treasury.dart';
import '../application/treasury_controller.dart';

/// What actually arrived through the till.
///
/// This is the reconciliation screen. Most transactions land against the right
/// invoice on their own and need nobody; the ones that matter are the payments
/// that arrived with a wrong or missing account number and are therefore
/// sitting in the account belonging to nobody. Those are shown first, and are
/// the only rows with anything to do.
class MpesaTransactionsScreen extends ConsumerStatefulWidget {
  const MpesaTransactionsScreen({super.key});

  @override
  ConsumerState<MpesaTransactionsScreen> createState() =>
      _MpesaTransactionsScreenState();
}

class _MpesaTransactionsScreenState
    extends ConsumerState<MpesaTransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = ref.watch(mpesaSearchProvider).trim().isNotEmpty;
    final all = ref.watch(mpesaTransactionsProvider);
    final found = ref.watch(mpesaSearchResultProvider);

    // One list, from whichever source is in play. The search does not open a
    // second screen: looking a reference up and then reading the row is one
    // task, not two.
    final AsyncValue<List<MpesaTransaction>> rows = searching
        ? found.whenData((value) => value ?? const <MpesaTransaction>[])
        : all;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('M-Pesa payments'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Find by transaction code',
                    hintText: 'SFH4KQ2WMR',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searching
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchController.clear();
                              ref.read(mpesaSearchProvider.notifier).clear();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (value) =>
                      ref.read(mpesaSearchProvider.notifier).search(value),
                ),
              ),
              Expanded(
                child: switch (rows) {
                  AsyncLoading() when !rows.hasValue => const AppSkeletonList(),
                  AsyncError(:final error) => ErrorView(
                    failure: error is Failure
                        ? error
                        : UnknownFailure(error.toString()),
                    onRetry: () async {
                      await ref
                          .refresh(mpesaTransactionsProvider.future)
                          .then<void>((_) {});
                    },
                  ),
                  _ => _TransactionList(
                    transactions: rows.requireValue,
                    searching: searching,
                    onRefresh: () async {
                      await ref
                          .refresh(mpesaTransactionsProvider.future)
                          .then<void>((_) {});
                      await ref
                          .refresh(mpesaSearchResultProvider.future)
                          .then<void>((_) {});
                    },
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({
    required this.transactions,
    required this.searching,
    required this.onRefresh,
  });

  final List<MpesaTransaction> transactions;
  final bool searching;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: searching
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                title: searching
                    ? 'No payment with that code'
                    : 'Nothing received yet',
                message: searching
                    ? 'Check the code against the message the payer received.'
                    : 'Payments made through the till appear here as they '
                          'arrive.',
              ),
            ),
          ],
        ),
      );
    }

    // Unreconciled money first. It is the only thing on this screen that needs
    // a person, and burying it under a hundred settled rows is how it stays
    // unreconciled.
    final unprocessed = transactions.where((row) => !row.processed).toList();
    final processed = transactions.where((row) => row.processed).toList();

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          if (unprocessed.isNotEmpty) ...[
            RecordGroup(
              heading: 'Needs an account number',
              children: [
                for (final row in unprocessed)
                  _TransactionRow(transaction: row, unmatched: true),
              ],
            ),
            Gap.h16,
          ],
          if (processed.isNotEmpty)
            RecordGroup(
              heading: unprocessed.isEmpty ? 'Received' : 'Reconciled',
              children: [
                for (final row in processed)
                  _TransactionRow(transaction: row, unmatched: false),
              ],
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.transaction, required this.unmatched});

  final MpesaTransaction transaction;
  final bool unmatched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = transaction.transactedAt;

    return RecordRow(
      icon: unmatched
          ? Icons.help_outline_rounded
          : Icons.check_circle_outline_rounded,
      iconColor: context.statusColors.resolve(
        unmatched ? StatusTone.warning : StatusTone.positive,
      ),
      title: transaction.transactionId,
      subtitle: [
        if (transaction.payerName != null) transaction.payerName!,
        if (transaction.maskedPayerPhone != null) transaction.maskedPayerPhone!,
      ].join(' · '),
      amount: AmountText(transaction.amount, align: TextAlign.end),
      caption: when == null ? null : AppDate.short(when),
      footnote: unmatched
          ? const StatusChip(
              label: 'Unallocated',
              tone: StatusTone.warning,
              dense: true,
            )
          : (transaction.hasAccountNumber
                ? Text(
                    'Account ${transaction.accountNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null),
      onTap: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TransactionSheet(transaction: transaction),
    );
  }
}

/// The whole record, plus the one correction that can be made to it.
class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({required this.transaction});

  final MpesaTransaction transaction;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  late final TextEditingController _accountController = TextEditingController(
    text: widget.transaction.accountNumber ?? '',
  );

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await ref
        .read(treasuryActionsProvider)
        .setAccountNumber(
          transactionId: widget.transaction.id,
          accountNumber: _accountController.text.trim(),
        );
    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment credited to that account.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final when = transaction.transactedAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: transaction.transactionId,
              children: [
                DetailRow(
                  label: 'Amount',
                  valueWidget: AmountText(
                    transaction.amount,
                    align: TextAlign.end,
                  ),
                  emphasise: true,
                ),
                if (when != null)
                  DetailRow(label: 'Received', value: AppDate.dateTime(when)),
                if (transaction.payerName != null)
                  DetailRow(label: 'From', value: transaction.payerName!),
                if (transaction.maskedPayerPhone != null)
                  DetailRow(
                    label: 'Number',
                    value: transaction.maskedPayerPhone!,
                  ),
                if (transaction.businessShortCode != null)
                  DetailRow(
                    label: 'Short code',
                    value: transaction.businessShortCode!,
                  ),
                if (transaction.transactionType != null)
                  DetailRow(label: 'Type', value: transaction.transactionType!),
                DetailRow(
                  label: 'Status',
                  value: transaction.processed
                      ? 'Reconciled'
                      : 'Not yet allocated',
                ),
              ],
            ),
            Gap.h12,
            SectionCard(
              title: 'Account credited',
              children: [
                Text(
                  transaction.processed
                      ? 'Changing this re-credits the payment to a different '
                            'account.'
                      : 'This payment arrived without an account number that '
                            'matches an invoice. Enter the right one to credit '
                            'it.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Gap.h16,
                TextField(
                  controller: _accountController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Account number',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                Gap.h16,
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Credit this account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
