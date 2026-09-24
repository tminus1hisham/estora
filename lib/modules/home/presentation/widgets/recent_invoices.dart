import 'package:flutter/material.dart';

import '../../../../components/glass_empty_pane.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/enums/domain_enums.dart';
import '../../../invoices/presentation/widgets/invoice_card.dart';

/// Every invoice still owed, or — when nothing is — the last two paid, with
/// the full statement one tap away.
///
/// The same card the statement uses, so an invoice a tenant half-remembers
/// from home is recognisably the same object on the invoices tab — including
/// where its "Pay now" sits.
class RecentInvoices extends StatelessWidget {
  const RecentInvoices({required this.invoices, super.key});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final newest = [...invoices]
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    final owed = newest.where((i) => i.status.isOutstanding).toList();
    final recent = owed.isNotEmpty
        ? owed
        : newest.where((i) => i.status == InvoiceStatus.paid).take(2).toList();

    if (recent.isEmpty) {
      // The same glass the cards would be, so the space they will fill is
      // already there rather than a grey icon floating on the ground.
      return const GlassEmptyPane(
        compact: true,
        icon: Icons.receipt_long_rounded,
        title: 'No invoices yet',
        message: 'Your latest invoices will appear here when they are issued.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, invoice) in recent.indexed) ...[
          // The statement's spacing, so the two lists read as one.
          if (index > 0) const SizedBox(height: 10),
          InvoiceCard(invoice: invoice),
        ],
      ],
    );
  }
}
