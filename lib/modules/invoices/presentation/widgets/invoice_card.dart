import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/status_chip.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/billing.dart';
import '../../../../domain/enums/domain_enums.dart';
import '../../../../navigation/routes.dart';
import 'pay_invoice.dart';

/// One invoice, as a card of its own.
///
/// The statement and the home preview both drew invoices as rows of a single
/// shared surface, which suits a ledger but buries the only thing a tenant
/// comes to these screens to do. Each invoice is its own card now, in two
/// lines: what it is, then what is owed with the action across from it.
///
/// The card is kept short on purpose. A statement is a list, and a card that
/// spends a line on a label, a line on a date and a line on a button shows
/// three invoices to a screen. The due date rides on the "Amount due" line and
/// the button sits opposite the figure, so a card is about as tall as the two
/// lines it has to have.
///
/// Nothing here is summed: the figure is the server's `amountDue` as supplied
/// (section 84 rule 7, section 65).
class InvoiceCard extends ConsumerWidget {
  const InvoiceCard({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statuses = context.statusColors;
    final tone = invoice.isDeferred ? StatusTone.neutral : invoice.status.tone;
    final toneColor = statuses.resolve(tone);
    final (caption, captionColor) = _caption(context);
    final stacked = prefersStacked(context);

    // The label and the due date share one line above the figure. They are
    // both small print about the same number, and stacking them cost a line
    // that the button then had to clear.
    final amountBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: invoice.isPayable ? 'Amount due' : 'Invoice total',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: caption,
                style: TextStyle(
                  color: captionColor,
                  fontWeight: AppTypography.semibold,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        Gap.h4,
        AmountText(
          invoice.isPayable ? invoice.amountDue : invoice.total,
          scale: AmountScale.title,
          color: invoice.isOverdue && !invoice.isDeferred
              ? scheme.error
              : scheme.onSurface,
        ),
      ],
    );

    final payButton = FilledButton.tonalIcon(
      onPressed: () => payInvoice(context, ref, invoice),
      style: FilledButton.styleFrom(
        minimumSize: stacked
            ? const Size.fromHeight(AppLayout.controlHeight)
            : const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      ),
      icon: const Icon(Icons.phone_android_rounded, size: 18),
      label: const Text('Pay now'),
    );

    return AppSurfaceCard(
      padding: const EdgeInsets.all(Gap.lg),
      borderColor: invoice.isOverdue && !invoice.isDeferred
          ? statuses.danger.withValues(alpha: 0.34)
          : null,
      onTap: () => context.pushNamed(
        Routes.invoiceDetail,
        pathParameters: {'invoiceId': invoice.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ToneIconTile(icon: _icon, color: toneColor, size: 36),
              Gap.w12,
              Expanded(
                child: Column(
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
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.w8,
              Flexible(
                child: StatusChip(
                  label: invoice.isDeferred ? 'Deferred' : invoice.status.label,
                  tone: tone,
                  dense: true,
                ),
              ),
            ],
          ),
          Gap.h12,
          // The figure and the action across from one another, which is the
          // rest of the card in one line. Once the platform's text size is
          // large enough that the two would fight for the width, the button
          // drops below the figure at full width rather than shrinking to a
          // label nobody can read.
          if (!invoice.isPayable)
            amountBlock
          else if (stacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [amountBlock, Gap.h12, payButton],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: amountBlock),
                Gap.w12,
                payButton,
              ],
            ),
        ],
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
        ? 'Issued ${AppDate.short(invoice.invoiceDate)}'
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

  /// The line across from the amount: when it falls due, or where it ended up.
  (String, Color) _caption(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statuses = context.statusColors;

    if (invoice.isDeferred) return ('Deferred', scheme.onSurfaceVariant);
    if (invoice.isOverdue) return ('Overdue', statuses.danger);
    if (!invoice.isPayable) {
      return (
        'Issued ${AppDate.short(invoice.invoiceDate)}',
        scheme.onSurfaceVariant,
      );
    }

    final days = invoice.daysUntilDue;
    if (days == 0) return ('Due today', statuses.warning);
    if (days == 1) return ('Due tomorrow', statuses.warning);
    if (days > 1 && days <= 7) return ('Due in $days days', statuses.warning);
    return ('Due ${AppDate.short(invoice.dueDate)}', scheme.onSurfaceVariant);
  }
}
