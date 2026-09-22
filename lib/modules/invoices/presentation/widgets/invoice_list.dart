import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import 'invoice_card.dart';

/// A month of invoices, and the invoices in it, newest month first.
typedef InvoiceMonth = ({DateTime month, List<Invoice> invoices});

/// Groups invoices into months by their issue date.
///
/// A statement is read by month — "what did September cost me" — and an
/// undivided list of twenty invoices is not a statement. The order is newest
/// first in both dimensions, which is the order the question is usually asked
/// in.
List<InvoiceMonth> groupInvoicesByMonth(List<Invoice> invoices) {
  final sorted = [...invoices]
    ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

  final months = <InvoiceMonth>[];
  for (final invoice in sorted) {
    final local = invoice.invoiceDate.toLocal();
    final key = DateTime(local.year, local.month);
    if (months.isNotEmpty && months.last.month == key) {
      months.last.invoices.add(invoice);
    } else {
      months.add((month: key, invoices: [invoice]));
    }
  }
  return months;
}

/// One month's heading and the invoices issued in it.
///
/// The month is the grouping; the invoices inside it are separate cards rather
/// than rows of one surface, because each carries an amount and, while it is
/// owed, an action of its own.
class InvoiceMonthSection extends StatelessWidget {
  const InvoiceMonthSection({required this.group, super.key});

  final InvoiceMonth group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = group.invoices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppDate.monthYear(group.month).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Gap.w8,
              Text(
                count == 1 ? '1 invoice' : '$count invoices',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final (index, invoice) in group.invoices.indexed) ...[
          if (index > 0) Gap.h12,
          InvoiceCard(invoice: invoice),
        ],
      ],
    );
  }
}
