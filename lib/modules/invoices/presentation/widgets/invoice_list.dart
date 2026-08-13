import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
          child: Text(
            AppDate.monthYear(group.month).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // One surface per month with hairlines between its rows, rather than a
        // card per invoice: a stack of separate cards reads as a stack of
        // unrelated decisions, and the shadows alone made the old list heavy.
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, invoice) in group.invoices.indexed) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Hairline(),
                  ),
                InvoiceRow(invoice: invoice),
              ],
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.statusColors.resolve(invoice.status.tone);
    final (caption, captionColor) = _caption(context);
    final stacked = prefersStacked(context);

    final leading = ToneIconTile(icon: _icon, color: tone, size: 40);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invoice.invoiceNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppTypography.semibold,
          ),
        ),
        Gap.h4,
        Text(
          _subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final trailing = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        AmountText(
          invoice.isPayable ? invoice.amountDue : invoice.total,
          color: invoice.isOverdue ? scheme.error : scheme.onSurface,
          align: stacked ? TextAlign.start : TextAlign.end,
        ),
        Gap.h4,
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: captionColor),
        ),
      ],
    );

    return InkWell(
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      Gap.w12,
                      Expanded(child: title),
                    ],
                  ),
                  Gap.h12,
                  trailing,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leading,
                  Gap.w12,
                  Expanded(flex: 5, child: title),
                  Gap.w12,
                  Expanded(flex: 4, child: trailing),
                ],
              ),
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
