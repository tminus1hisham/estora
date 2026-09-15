import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/treasury.dart';
import '../../../navigation/routes.dart';
import '../application/treasury_controller.dart';

/// Payments recorded by hand rather than taken through a gateway.
///
/// Split by whether anybody has checked them yet. A payment sitting here
/// unreconciled is somebody's rent that the system does not know arrived, and
/// that is a different thing from one that has been matched and filed.
class BankPaymentsScreen extends ConsumerWidget {
  const BankPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(bankPaymentsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Bank payments'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (payments) {
        AsyncLoading() when !payments.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(bankPaymentsProvider.future).then<void>((_) {});
          },
        ),
        _ => _PaymentList(
          payments: payments.requireValue,
          onRefresh: () async {
            await ref.refresh(bankPaymentsProvider.future).then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.payments, required this.onRefresh});

  final List<BankPayment> payments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'No bank payments recorded',
                message:
                    'Transfers, cheques and cash taken over the counter appear '
                    'here once they are recorded.',
              ),
            ),
          ],
        ),
      );
    }

    final pending = payments.where((row) => !row.isProcessed).toList();
    final reconciled = payments.where((row) => row.isProcessed).toList();

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              if (pending.isNotEmpty) ...[
                RecordGroup(
                  heading: 'Awaiting review',
                  children: [for (final row in pending) _PaymentRow(row)],
                ),
                Gap.h16,
              ],
              if (reconciled.isNotEmpty)
                RecordGroup(
                  heading: 'Reconciled',
                  children: [for (final row in reconciled) _PaymentRow(row)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow(this.payment);

  final BankPayment payment;

  @override
  Widget build(BuildContext context) {
    final bank = payment.bankLabel;

    return RecordRow(
      icon: Icons.account_balance_outlined,
      iconColor: context.statusColors.resolve(
        payment.isProcessed ? StatusTone.positive : StatusTone.progress,
      ),
      title: payment.paymentReference,
      subtitle: [
        payment.paymentMethod,
        if (payment.paidByName != null) payment.paidByName!,
        if (bank.isNotEmpty) bank,
      ].join(' · '),
      amount: AmountText(payment.amount, align: TextAlign.end),
      caption: AppDate.short(payment.paidAt),
      footnote: payment.isProcessed
          ? null
          : StatusChip(
              label: payment.status ?? 'Pending review',
              tone: StatusTone.progress,
              dense: true,
            ),
      // A reconciled payment is a closed record. Tapping it would open a form
      // whose every control is refused, which is a worse answer than no form.
      onTap: payment.isProcessed
          ? null
          : () => context.pushNamed(
              Routes.bankPaymentEdit,
              pathParameters: {'paymentId': payment.id},
            ),
    );
  }
}
