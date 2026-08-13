import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/record_group.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/enums/domain_enums.dart';
import '../../../../navigation/routes.dart';

/// A month of invoices, and the invoices in it, newest month first.
typedef InvoiceMonth = ({DateTime month, List<Invoice> invoices});

/// Groups invoices into months by their issue date.
///
/// A statement is read by month — "what did September cost me" — and a flat
/// list of twenty cards is not a statement. The order is newest first in both
/// dimensions, which is the order the question is usually asked in.
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

/// One month's heading and its ledger.
class InvoiceMonthSection extends StatelessWidget {
  const InvoiceMonthSection({required this.group, super.key});

  final InvoiceMonth group;

  @override
  Widget build(BuildContext context) {
    // One surface per month with hairlines between its rows, rather than a card
    // per invoice. [RecordGroup] carries that shape for the whole app now.
    return RecordGroup(
      heading: AppDate.monthYear(group.month),
      children: [
        for (final invoice in group.invoices) InvoiceRow(invoice: invoice),
      ],
    );
  }
}

/// One invoice, as a line of a statement.
class InvoiceRow extends StatelessWidget {
  const InvoiceRow({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (caption, captionColor) = _caption(context);

    return RecordRow(
      icon: _icon,
      iconColor: context.statusColors.resolve(invoice.status.tone),
      title: invoice.invoiceNumber,
      subtitle: _subtitle,
      amount: AmountText(
        invoice.isPayable ? invoice.amountDue : invoice.total,
        color: invoice.isOverdue ? scheme.error : scheme.onSurface,
        align: prefersStacked(context) ? TextAlign.start : TextAlign.end,
      ),
      caption: caption,
      captionColor: captionColor,
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
    );
  }

  /// What the invoice covers, in one line.
  String get _subtitle {
    final parts = <String>[
      if (invoice.lines.isNotEmpty) invoice.lines.first.lineType.label,
      if (invoice.hasBillingPeriod)
        AppDate.monthYear(invoice.billingPeriodStart!)
      else if (invoice.unitNumber != null)
        'Unit ${invoice.unitNumber}',
    ];
    return parts.isEmpty
        ? AppDate.short(invoice.invoiceDate)
        : parts.join(' · ');
  }

  IconData get _icon => switch (invoice.status) {
    InvoiceStatus.paid => Icons.check_rounded,
    InvoiceStatus.overdue => Icons.priority_high_rounded,
    InvoiceStatus.partiallyPaid => Icons.timelapse_rounded,
    InvoiceStatus.draft => Icons.edit_outlined,
    InvoiceStatus.cancelled || InvoiceStatus.invoiceVoid => Icons.block_rounded,
    _ => Icons.receipt_long_rounded,
  };

  /// The line under the amount: when it is due, or where it ended up.
  (String, Color) _caption(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statuses = context.statusColors;

    if (invoice.isOverdue) return ('Overdue', statuses.danger);
    if (!invoice.isPayable) {
      return (invoice.status.label, scheme.onSurfaceVariant);
    }

    final days = invoice.daysUntilDue;
    if (days < 0) {
      return ('Due ${AppDate.short(invoice.dueDate)}', scheme.onSurfaceVariant);
    }
    if (days == 0) return ('Due today', statuses.warning);
    if (days == 1) return ('Due tomorrow', statuses.warning);
    if (days <= 7) return ('Due in $days days', statuses.warning);
    return ('Due ${AppDate.short(invoice.dueDate)}', scheme.onSurfaceVariant);
  }
}
