import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/status_chip.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../application/invoice_controller.dart';
import 'invoice_card.dart';
import 'invoice_document.dart';
import 'pay_invoice.dart';

/// Opens [invoice] as a short sheet of clear glass over the statement.
///
/// The card's copy shows at once; the sheet swaps in the server's fresh read
/// when it lands. The full-page detail route stays for deep links.
Future<void> showInvoiceSheet(BuildContext context, Invoice invoice) {
  return showModalBottomSheet<void>(
    context: context,
    // Left at the default so the sheet never rises past about half the
    // screen; a long breakdown scrolls inside its own pane.
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.14),
    constraints: const BoxConstraints(
      maxWidth: AppLayout.maxReadingWidth + Gap.lg,
    ),
    builder: (_) => InvoiceSheet(invoice: invoice),
  );
}

/// Two blocks and an action: what is owed and by when, then what it is made
/// of, then Pay now. Bank transfer and deferral live on the full invoice page.
class InvoiceSheet extends ConsumerWidget {
  const InvoiceSheet({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(invoiceDetailProvider(invoice.id)).value ?? invoice;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(Gap.sm),
      child: FrostedPane(
        depth: GlassDepth.sheet,
        radius: GlassRadius.platter,
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: Gap.sm),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            _Summary(invoice: live),
            Gap.h16,
            Flexible(
              child: FrostedPane(
                depth: GlassDepth.inset,
                radius: GlassRadius.tile,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.sm,
                ),
                child: SingleChildScrollView(
                  child: InvoiceLedger(invoice: live, bare: true),
                ),
              ),
            ),
            if (live.isPayable) ...[
              Gap.h16,
              // Full width and taller than the card's key: on the sheet it is
              // the one thing to do.
              SizedBox(
                height: 52,
                child: PayNowButton(
                  expand: true,
                  onPressed: () async {
                    final paid = await payInvoice(context, ref, live);
                    if (paid == true && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Number, status, where, the figure and its dates — straight on the glass.
class _Summary extends StatelessWidget {
  const _Summary({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final danger = context.statusColors.danger;
    final payable = invoice.isPayable;
    final where = [
      if (invoice.propertyName != null) invoice.propertyName!,
      if (invoice.unitNumber != null) 'Unit ${invoice.unitNumber}',
    ].join(' · ');
    final (label, tone) = invoiceStatus(invoice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invoice.invoiceNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: muted,
                  fontWeight: AppTypography.semibold,
                ),
              ),
            ),
            Gap.w8,
            StatusChip(label: label, tone: tone, dense: true),
          ],
        ),
        Gap.h8,
        AmountText(
          payable ? invoice.amountDue : invoice.total,
          scale: AmountScale.hero,
          color: invoice.isOverdue ? danger : null,
        ),
        Gap.h4,
        Text(
          [
            if (payable) invoiceUrgency(invoice),
            if (!payable) 'Issued ${AppDate.short(invoice.invoiceDate)}',
            if (payable) AppDate.short(invoice.dueDate),
            if (invoice.hasBillingPeriod)
              AppDate.period(
                invoice.billingPeriodStart!,
                invoice.billingPeriodEnd!,
              ),
            if (where.isNotEmpty) where,
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: invoice.isOverdue ? danger : muted,
          ),
        ),
      ],
    );
  }
}
