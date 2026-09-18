import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/record_group.dart';
import '../../../../components/section_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/entities/treasury.dart';

/// Opens one invoice's payments in a sheet.
///
/// The sheet, not a screen: the owner is reading a list and wants to know
/// what has landed against one line of it, then go back to the list. What is
/// shown is the record as the server embeds it — the invoice's own figures at
/// the top, and under them each M-Pesa transaction placed against it. Nothing
/// here is added up; the figures are the server's.
Future<void> showInvoicePaymentsSheet(BuildContext context, Invoice invoice) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InvoicePaymentsSheet(invoice: invoice),
    );

class InvoicePaymentsSheet extends StatelessWidget {
  const InvoicePaymentsSheet({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = context.statusColors;
    // Newest first, the way every other list of arrivals reads.
    final payments = [...invoice.payments]
      ..sort((a, b) => _when(b).compareTo(_when(a)));
    final count = payments.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: invoice.invoiceNumber,
                children: [
                  if (invoice.tenantName != null)
                    DetailRow(label: 'Billed to', value: invoice.tenantName!),
                  if (_where(invoice) != null)
                    DetailRow(label: 'For', value: _where(invoice)!),
                  DetailRow(
                    label: 'Total',
                    valueWidget: AmountText(
                      invoice.total,
                      align: TextAlign.end,
                    ),
                  ),
                  DetailRow(
                    label: 'Paid',
                    valueWidget: AmountText(
                      invoice.amountPaid,
                      align: TextAlign.end,
                    ),
                  ),
                  DetailRow(
                    label: 'Balance due',
                    valueWidget: AmountText(
                      invoice.amountDue,
                      align: TextAlign.end,
                    ),
                    emphasise: true,
                  ),
                  DetailRow(
                    label: 'Due',
                    value: AppDate.short(invoice.dueDate),
                  ),
                  DetailRow(label: 'Status', value: invoice.status.label),
                ],
              ),
              Gap.h16,
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  child: Text(
                    'No payments have been received against this invoice.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                RecordGroup(
                  heading: '$count payment${count == 1 ? '' : 's'}',
                  children: [
                    for (final payment in payments)
                      RecordRow(
                        icon: Icons.south_west_rounded,
                        iconColor: payment.processed
                            ? statuses.positive
                            : statuses.resolve(StatusTone.warning),
                        title: payment.transactionId,
                        subtitle: _who(payment),
                        amount: AmountText(payment.amount),
                        caption: switch (payment.transactedAt ??
                            payment.createdAt) {
                          final at? => AppDate.dateTime(at),
                          null =>
                            payment.processed
                                ? 'Reconciled'
                                : 'Not yet allocated',
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _where(Invoice invoice) {
    final parts = [
      if (invoice.unitNumber != null) invoice.unitNumber!,
      if (invoice.propertyName != null) invoice.propertyName!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? _who(MpesaTransaction payment) {
    final parts = [
      if (payment.payerName != null) payment.payerName!,
      if (payment.maskedPayerPhone != null) payment.maskedPayerPhone!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static DateTime _when(MpesaTransaction payment) =>
      payment.transactedAt ??
      payment.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
