import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../navigation/routes.dart';
import '../application/payment_controller.dart';

/// Section 77's Payment History screen.
///
/// Failed and cancelled payments are listed alongside successful ones. Section
/// 84 rule 2 forbids deleting a successful payment, and section 85 expects the
/// system to answer who paid and when — a history that quietly hid attempts
/// would be a worse record than one that shows them.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: switch (payments) {
        AsyncLoading() when !payments.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(paymentHistoryProvider.notifier).refresh(),
        ),
        _ => _PaymentList(payments: payments.requireValue),
      },
    );
  }
}

class _PaymentList extends ConsumerWidget {
  const _PaymentList({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payments.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_outlined,
        title: 'No payments yet',
        message: 'Payments you make will be listed here with their receipts.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentHistoryProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        itemCount: payments.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) =>
            _PaymentCard(payment: payments[index]),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () {
          if (payment.hasReceipt) {
            context.pushNamed(
              Routes.receipt,
              pathParameters: {'receiptId': payment.receiptId!},
            );
          } else if (payment.isInFlight) {
            context.pushNamed(
              Routes.paymentStatus,
              pathParameters: {'paymentId': payment.id},
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.invoiceNumber ?? payment.paymentReference,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          AppDate.dateTime(
                            payment.paidAt ?? payment.createdAt,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: payment.status.label,
                    tone: payment.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  Gap.w8,
                  Text(
                    payment.paymentMethod.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  MoneyText(payment.amount),
                ],
              ),
              if (payment.failureReason != null) ...[
                Gap.h8,
                Text(
                  payment.failureReason!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              if (payment.hasReceipt) ...[
                Gap.h8,
                Row(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 14,
                      color: scheme.primary,
                    ),
                    Gap.w4,
                    Text(
                      'Receipt available',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
