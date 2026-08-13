import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/summary_banner.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
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
        AsyncLoading() when !payments.hasValue => const AppSkeletonList(
          header: true,
        ),
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

    final months = _groupByMonth(payments);

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentHistoryProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: months.length + 1,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) {
              if (index == 0) return _PaymentOverview(payments: payments);
              final month = months[index - 1];
              return RecordGroup(
                heading: AppDate.monthYear(month.month),
                children: [
                  for (final payment in month.payments)
                    _PaymentRow(payment: payment),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Payments grouped by the month they were made, newest first.
  ///
  /// The same reading the invoice statement gets: a tenant looking for a
  /// payment remembers roughly when they made it, not its reference.
  static List<({DateTime month, List<Payment> payments})> _groupByMonth(
    List<Payment> payments,
  ) {
    final sorted = [...payments]
      ..sort(
        (a, b) => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt),
      );

    final months = <({DateTime month, List<Payment> payments})>[];
    for (final payment in sorted) {
      final local = (payment.paidAt ?? payment.createdAt).toLocal();
      final key = DateTime(local.year, local.month);
      if (months.isNotEmpty && months.last.month == key) {
        months.last.payments.add(payment);
      } else {
        months.add((month: key, payments: [payment]));
      }
    }
    return months;
  }
}

class _PaymentOverview extends StatelessWidget {
  const _PaymentOverview({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final successful = payments
        .where((item) => item.status == PaymentStatus.success)
        .length;
    final processing = payments.where((item) => item.isInFlight).length;

    return SummaryBanner(
      icon: Icons.account_balance_wallet_outlined,
      headline: 'Payment activity',
      caption: processing > 0
          ? '$processing ${processing == 1 ? 'payment is' : 'payments are'} still processing.'
          : '$successful successful · ${payments.length} total',
      counts: [
        SummaryCount(label: 'Successful', value: successful),
        SummaryCount(
          label: 'Processing',
          value: processing,
          tone: Theme.of(context).colorScheme.tertiary,
        ),
      ],
    );
  }
}

/// One payment, as a line of the ledger.
///
/// The old card said "Amount" above the figure and carried a status chip, a
/// divider and a wallet glyph beside the method. In a list where every entry is
/// a payment, all four of those are restating the column they are in.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = context.statusColors.resolve(payment.status.tone);

    return RecordRow(
      icon: _icon,
      iconColor: tone,
      title: payment.invoiceNumber ?? payment.paymentReference,
      subtitle:
          '${payment.paymentMethod.label} · '
          '${AppDate.short(payment.paidAt ?? payment.createdAt)}',
      amount: AmountText(payment.amount, align: TextAlign.end),
      caption: payment.hasReceipt ? 'Receipt' : payment.status.label,
      captionColor: payment.hasReceipt
          ? scheme.primary
          : payment.status == PaymentStatus.success
          ? scheme.onSurfaceVariant
          : tone,
      // A failed payment is the one entry that has to explain itself, and the
      // reason is why a tenant opened the list at all.
      footnote: payment.failureReason == null
          ? null
          : Text(
              payment.failureReason!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
      onTap: _destination(context),
    );
  }

  /// Only tappable where there is somewhere to go. A row that highlights and
  /// then does nothing is worse than one that never offered.
  VoidCallback? _destination(BuildContext context) {
    if (payment.hasReceipt) {
      return () => context.pushNamed(
        Routes.receipt,
        pathParameters: {'receiptId': payment.receiptId!},
      );
    }
    if (payment.isInFlight) {
      return () => context.pushNamed(
        Routes.paymentStatus,
        pathParameters: {'paymentId': payment.id},
      );
    }
    return null;
  }

  IconData get _icon => switch (payment.status) {
    PaymentStatus.success => Icons.check_rounded,
    PaymentStatus.failed => Icons.priority_high_rounded,
    PaymentStatus.cancelled => Icons.block_rounded,
    _ => Icons.timelapse_rounded,
  };
}
