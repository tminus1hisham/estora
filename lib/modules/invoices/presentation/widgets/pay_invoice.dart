import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/billing.dart';
import '../../../payments/application/payment_controller.dart';
import '../../../payments/presentation/widgets/mpesa_payment_sheet.dart';
import '../../application/invoice_controller.dart';

/// Opens the M-Pesa sheet for [invoice]'s balance.
///
/// Every "Pay now" on an invoice — the focus card, a statement row, the
/// detail screen, the home balance card — comes through here, so they all
/// prompt for the same record with the same figure: the invoice's
/// `amountDue` as the server last stated it (section 65).
///
/// Resolves to `true` once the server shows the invoice paid. The invoice is
/// re-read either way, because a prompt answered after the sheet was closed
/// still moves the balance.
Future<bool?> payInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final actions = ref.read(paymentActionsProvider);
  final what = [
    if (invoice.lines.isNotEmpty) invoice.lines.first.lineType.label,
    if (invoice.unitNumber != null) 'Unit ${invoice.unitNumber}',
  ];

  final paid = await showMpesaPaymentSheet(
    context,
    MpesaPaymentRequest(
      title: invoice.invoiceNumber,
      subtitle: what.isEmpty ? null : what.join(' · '),
      amount: invoice.amountDue,
      send: (phoneNumber) =>
          actions.requestMpesaPrompt(invoice, phoneNumber: phoneNumber),
      confirmPaid: () => actions.confirmInvoicePaid(invoice.id),
      restart: () => actions.restartPrompt(invoice.id),
    ),
  );

  if (paid != true) {
    ref.invalidate(invoiceListProvider);
    ref.invalidate(invoiceDetailProvider(invoice.id));
  }
  return paid;
}
