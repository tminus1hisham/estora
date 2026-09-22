import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/property_tag.dart';
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
import '../../invoices/application/billing_property_filter.dart';
import '../application/payment_controller.dart';

/// Section 77's Payment History, as the Transactions pane of the invoices
/// tab. A body rather than a screen: the app bar and the tab strip above it
/// belong to the tab, which holds the invoices and the money paid against
/// them side by side.
///
/// Failed and cancelled payments are listed alongside successful ones. Section
/// 84 rule 2 forbids deleting a successful payment, and section 85 expects the
/// system to answer who paid and when — a history that quietly hid attempts
/// would be a worse record than one that shows them.
class TransactionsView extends ConsumerWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Narrowed to the property picked above the tabs, if one is; the list,
    // the overview's counts and the empty state all answer for it.
    final payments = ref.watch(scopedPaymentsProvider);
    final property = ref.watch(selectedBillingPropertyProvider);

    return switch (payments) {
      AsyncLoading() when !payments.hasValue => const AppSkeletonList(
        header: true,
      ),
      AsyncError(:final error) => ErrorView(
        failure: error is Failure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.read(paymentHistoryProvider.notifier).refresh(),
      ),
      _ => _PaymentList(
        payments: payments.requireValue,
        propertyName: property?.name,
      ),
    };
  }
}

class _PaymentList extends ConsumerWidget {
  const _PaymentList({required this.payments, this.propertyName});

  final List<Payment> payments;

  /// The property the history is narrowed to; null for all of them.
  final String? propertyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payments.isEmpty) {
      return EmptyState(
        onRefresh: () async {
          await ref.read(paymentHistoryProvider.notifier).refresh();
        },
        icon: Icons.payments_outlined,
        title: 'No transactions yet',
        message: propertyName == null
            ? 'Payments you make will be listed here with their receipts.'
            : 'Payments against your $propertyName invoices will be listed '
                  'here with their receipts.',
      );
    }

    final months = _groupByMonth(payments);
    // A tenant paying at more than one mall, reading them all together, needs
    // each row to say which one it paid. Narrowed to one, it would only
    // repeat the pill above.
    final tagged =
        propertyName == null && ref.watch(billingPropertiesProvider).length > 1;
    final placeOf = ref.watch(paymentPropertyProvider);

    return AppRefreshIndicator(
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
                    _PaymentRow(
                      payment: payment,
                      propertyName: tagged ? placeOf(payment)?.name : null,
                    ),
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
  const _PaymentRow({required this.payment, this.propertyName});

  final Payment payment;

  /// The mall the payment was for, shown as a tag under the title when the
  /// history spans more than one.
  final String? propertyName;

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
      footnote: _footnote(context),
      onTap: _destination(context),
    );
  }

  Widget? _footnote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = PropertyTag.canShow(name: propertyName)
        ? Padding(
            // Under the title, not under the glyph: the tag belongs to the
            // words, as it does on an invoice card.
            padding: const EdgeInsetsDirectional.only(start: 40 + Gap.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PropertyTag(name: propertyName),
            ),
          )
        : null;
    // A failed payment is the one entry that has to explain itself, and the
    // reason is why a tenant opened the list at all.
    final reason = payment.failureReason == null
        ? null
        : Text(
            payment.failureReason!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.error),
          );
    if (tag == null) return reason;
    if (reason == null) return tag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [tag, Gap.h8, reason],
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
