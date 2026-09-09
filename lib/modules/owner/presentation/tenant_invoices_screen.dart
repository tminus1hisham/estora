import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../invoices/application/invoice_controller.dart';

/// What one tenant has been billed, read from the landlord's side.
///
/// The contract keys its only invoice route on the tenant, which is what makes
/// this possible at all — the same route the tenant's own list uses, asked
/// about somebody else. Who may ask is the server's decision.
///
/// The action here is settlement: closing an invoice against something that
/// did not come through this app. It is deliberately not called "mark as
/// paid", because that is not what it means and a landlord reaching for it
/// should know they are writing something off.
class TenantInvoicesScreen extends ConsumerWidget {
  const TenantInvoicesScreen({
    required this.tenantId,
    required this.tenantName,
    super.key,
  });

  final String tenantId;
  final String tenantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(tenantInvoicesProvider(tenantId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (invoices) {
        AsyncLoading() when !invoices.hasValue => const AppSkeletonList(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(tenantInvoicesProvider(tenantId)),
        ),
        _ => _InvoiceList(
          invoices: invoices.requireValue,
          tenantName: tenantName,
          tenantId: tenantId,
        ),
      },
    );
  }
}

class _InvoiceList extends ConsumerWidget {
  const _InvoiceList({
    required this.invoices,
    required this.tenantName,
    required this.tenantId,
  });

  final List<Invoice> invoices;
  final String tenantName;
  final String tenantId;

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Settle ${invoice.invoiceNumber}?'),
        content: Text(
          'This closes ${invoice.amountDue.format()} against something other '
          'than a payment through the app — a settlement, an offset or a '
          'write-off. It does not record money arriving. If a payment did '
          'arrive, record it under bank payments instead so it can be '
          'reconciled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(invoiceActionsProvider)
        .settleInvoice(invoice.id);
    if (!context.mounted) return;

    ref.invalidate(tenantInvoicesProvider(tenantId));

    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nothing billed yet',
        message: '$tenantName has no invoices.',
      );
    }

    final outstanding = invoices.where((i) => i.status.isOutstanding).toList();
    final settled = invoices.where((i) => !i.status.isOutstanding).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tenantInvoicesProvider(tenantId)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              if (outstanding.isNotEmpty)
                RecordGroup(
                  heading: 'Owed',
                  children: [
                    for (final invoice in outstanding)
                      _InvoiceRow(
                        invoice: invoice,
                        onSettle: () => _settle(context, ref, invoice),
                      ),
                  ],
                ),
              if (settled.isNotEmpty) ...[
                if (outstanding.isNotEmpty) Gap.h16,
                RecordGroup(
                  heading: 'Closed',
                  children: [
                    for (final invoice in settled)
                      _InvoiceRow(invoice: invoice, onSettle: null),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onSettle});

  final Invoice invoice;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    return RecordRow(
      icon: Icons.receipt_long_outlined,
      iconColor: context.statusColors.resolve(invoice.status.tone),
      title: invoice.invoiceNumber,
      subtitle: 'Due ${AppDate.short(invoice.dueDate)}',
      amount: AmountText(invoice.amountDue, align: TextAlign.end),
      caption: invoice.status.label,
      footnote: invoice.isDeferred
          ? StatusChip(
              // The tenant asked for more time, and the reason travels with
              // the request rather than being lost on the way over.
              label: invoice.deferReason == null
                  ? 'Deferral requested'
                  : 'Deferral: ${invoice.deferReason}',
              tone: StatusTone.warning,
              dense: true,
            )
          : null,
      onTap: onSettle,
    );
  }
}
