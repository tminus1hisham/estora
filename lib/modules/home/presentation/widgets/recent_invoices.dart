import 'package:flutter/material.dart';

import '../../../../components/app_surface_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/billing.dart';
import '../../../invoices/presentation/widgets/invoice_card.dart';

/// A short preview of the latest invoices, with the full statement one tap
/// away.
///
/// The same card the statement uses, so an invoice a tenant half-remembers
/// from home is recognisably the same object on the invoices tab — including
/// where its "Pay now" sits.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, invoice) in recent.take(5).indexed) ...[
          if (index > 0) Gap.h12,
          InvoiceCard(invoice: invoice),
        ],
      ],
    );
  }
}
