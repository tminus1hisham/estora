import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/record_group.dart';
import '../../../../components/status_chip.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../navigation/routes.dart';
import '../../../invoices/presentation/widgets/pay_invoice.dart';

/// A short preview of the latest invoices, with the full statement one tap away.
class RecentInvoices extends StatelessWidget {
  const RecentInvoices({required this.invoices, super.key});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (invoices.isEmpty) {
      return AppSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('No invoices yet', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Your latest invoices will appear here when they are issued.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final recent = [...invoices]
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return RecordGroup(
      rowInset: 16,
      children: [
        for (final invoice in recent.take(5)) _InvoicePreview(invoice: invoice),
      ],
    );
  }
}

class _InvoicePreview extends ConsumerWidget {
  const _InvoicePreview({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final description = [
      if (invoice.lines.isNotEmpty) invoice.lines.first.lineType.label,
      if (invoice.unitNumber != null) 'Unit ${invoice.unitNumber}',
    ].join(' · ');

    return InkWell(
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                ),
                StatusChip(
                  label: invoice.isDeferred ? 'Deferred' : invoice.status.label,
                  tone: invoice.isDeferred
                      ? StatusTone.neutral
                      : invoice.status.tone,
                  dense: true,
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: muted),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  invoice.isPayable ? 'Amount due' : 'Invoice total',
                  style: muted,
                ),
                AmountText(
                  invoice.isPayable ? invoice.amountDue : invoice.total,
                  color: invoice.isOverdue && !invoice.isDeferred
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  invoice.isPayable
                      ? 'Due ${AppDate.short(invoice.dueDate)}'
                      : 'Issued ${AppDate.short(invoice.invoiceDate)}',
                  style: muted,
                ),
                if (invoice.isPayable)
                  FilledButton.tonalIcon(
                    onPressed: () => payInvoice(context, ref, invoice),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelMedium,
                    ),
                    icon: const Icon(Icons.phone_android_rounded, size: 16),
                    label: const Text('Pay now'),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
