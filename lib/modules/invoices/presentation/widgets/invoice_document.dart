import 'package:flutter/material.dart';

import '../../../../components/amount_text.dart';
import '../../../../components/app_glass.dart';
import '../../../../components/app_surface_card.dart';
import '../../../../components/glass_material.dart';
import '../../../../components/glass_well.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../domain/entities/billing.dart';
import 'invoice_list.dart';

/// The head of an invoice, as the document itself.
///
/// Dark in both themes, like the balance card on home — this is the same
/// object seen closer up. The figure is set at reading size in medium weight
/// rather than shouted: what makes an amount urgent here is the colour it is
/// drawn in and the line underneath it, not how heavy it is.
class InvoiceDocumentHero extends StatelessWidget {
  const InvoiceDocumentHero({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payable = invoice.isPayable;
    final tone = invoice.isOverdue
        ? StatusTone.danger
        : payable && invoice.daysUntilDue <= 3
        ? StatusTone.warning
        : StatusTone.progress;

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      // On the navy ground of the dark theme the navy card has no edge of its
      // own; a hairline of light gives it one. On cream it needs none.
      borderColor: theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.09)
          : Colors.transparent,
      padding: EdgeInsets.zero,
      shadows: AppElevation.lifted(
        AppPalette.navy950,
        level: 3,
        brightness: theme.brightness,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: SoftGlow(
              color:
                  (invoice.isOverdue ? AppPalette.red300 : AppPalette.azure500)
                      .withValues(alpha: 0.32),
              size: 230,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgedHeader(
                  badge: TonePill(
                    label: invoice.status.label,
                    tone: invoice.status.tone,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVOICE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: kOnDark.withValues(alpha: 0.62),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        invoice.invoiceNumber,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: kOnDark,
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                      if (invoice.unitNumber != null ||
                          invoice.propertyName != null) ...[
                        Gap.h4,
                        Text(
                          [
                            if (invoice.propertyName != null)
                              invoice.propertyName!,
                            if (invoice.unitNumber != null)
                              'Unit ${invoice.unitNumber}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kOnDark.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Gap.h24,
                const Hairline(onDark: true),
                Gap.h16,
                Text(
                  payable ? 'AMOUNT DUE' : 'INVOICE TOTAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kOnDark.withValues(alpha: 0.62),
                    letterSpacing: 1.2,
                  ),
                ),
                Gap.h8,
                AmountText(
                  payable ? invoice.amountDue : invoice.total,
                  scale: AmountScale.hero,
                  color: invoice.isOverdue ? AppPalette.red300 : kOnDark,
                ),
                if (payable) ...[
                  Gap.h8,
                  Text(
                    invoiceUrgency(invoice),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StatusColors.dark.resolve(tone),
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                ],
                Gap.h16,
                GlassSurface(
                  onDark: true,
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatRow(
                        onDark: true,
                        left: Stat(
                          'Issued',
                          value: AppDate.short(invoice.invoiceDate),
                        ),
                        right: Stat(
                          'Due',
                          value: AppDate.short(invoice.dueDate),
                        ),
                      ),
                      // Section 35: the billing period is what makes proration,
                      // termination settlement and disputes tractable, so it is
                      // stated rather than left implicit in a line description.
                      if (invoice.hasBillingPeriod) ...[
                        Gap.h16,
                        const Hairline(onDark: true, alpha: 0.12),
                        Gap.h16,
                        StatPair(
                          label: 'Billing period',
                          value: AppDate.period(
                            invoice.billingPeriodStart!,
                            invoice.billingPeriodEnd!,
                          ),
                          onDark: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

/// "Due in 3 days", "Overdue by 2 days" — how soon a payable invoice is due.
String invoiceUrgency(Invoice invoice) {
  final days = invoice.daysUntilDue;
  if (invoice.isOverdue || days < 0) {
    final late = days.abs();
    return late == 0
        ? 'Payment overdue'
        : 'Overdue by $late ${late == 1 ? 'day' : 'days'}';
  }
  return switch (days) {
    0 => 'Due today',
    1 => 'Due tomorrow',
    _ => 'Due in $days days',
  };
}

/// What the invoice is made of.
///
/// Section 33 forbids storing only a total, and this screen refuses to show
/// only one either. Every figure below is a field on the invoice — the subtotal
/// is not a sum of the lines, the total is not subtotal plus tax, and the
/// amount due is not total minus paid. Section 84 rule 7 puts totalling on the
/// server and rule 4 requires a historical invoice to keep the figures it was
/// issued with, so recomputing any of them here would risk showing a tenant
/// something their invoice does not say.
class InvoiceLedger extends StatelessWidget {
  const InvoiceLedger({required this.invoice, this.bare = false, super.key});

  final Invoice invoice;

  /// Only the lines and totals, for a caller that supplies its own pane.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    if (bare) return _ledger(context);
    // Headed the way the statement heads a month, so the two screens read as
    // one document at two distances; the currency is stated once there, so
    // no line has to repeat it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.sm, Gap.xs, Gap.md),
          child: InvoiceSectionHeader(
            title: 'BREAKDOWN',
            trailing: 'IN ${invoice.currency}',
          ),
        ),
        FrostedPane(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.lg),
          child: _ledger(context),
        ),
      ],
    );
  }

  Widget _ledger(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, line) in invoice.lines.indexed) ...[
          if (index > 0) ...[Gap.h12, const Hairline(alpha: 0.5), Gap.h12],
          _LedgerLine(line: line),
        ],
        if (invoice.lines.isNotEmpty) ...[Gap.h16, const Hairline()],
        Gap.h16,
        _LedgerTotal(label: 'Subtotal', amount: invoice.subtotal, muted: true),
        if (invoice.tax.isPositive)
          _LedgerTotal(label: 'Tax', amount: invoice.tax, muted: true),
        if (invoice.discount.isPositive)
          _LedgerTotal(
            label: 'Discount',
            amount: -invoice.discount,
            muted: true,
          ),
        Gap.h12,
        const Hairline(),
        Gap.h12,
        _LedgerTotal(label: 'Total', amount: invoice.total, strong: true),
        if (invoice.amountPaid.isPositive) ...[
          _LedgerTotal(label: 'Paid', amount: invoice.amountPaid, muted: true),
          Gap.h4,
          _LedgerTotal(
            label: 'Amount due',
            amount: invoice.amountDue,
            strong: true,
            color: invoice.isOverdue ? context.statusColors.danger : null,
          ),
        ],
      ],
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stacked = prefersStacked(context);

    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: AppTypography.medium,
          ),
        ),
        if (line.showsQuantity || (line.taxAmount?.isPositive ?? false)) ...[
          Gap.h4,
          Text(
            [
              if (line.showsQuantity)
                '${line.quantity} × ${line.unitPrice.formatBare()}',
              if (line.taxAmount != null && line.taxAmount!.isPositive)
                'incl. ${line.taxRate?.toStringAsFixed(0)}% tax of '
                    '${line.taxAmount!.formatBare()}',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final amount = AmountText(
      line.amount,
      showCurrency: false,
      align: stacked ? TextAlign.start : TextAlign.end,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [description, Gap.h8, amount],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: description),
        Gap.w16,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: amount,
        ),
      ],
    );
  }
}

/// A totals row: a quiet label on the left, a figure on the right.
class _LedgerTotal extends StatelessWidget {
  const _LedgerTotal({
    required this.label,
    required this.amount,
    this.muted = false,
    this.strong = false,
    this.color,
  });

  final String label;
  final Money amount;

  /// A component of the total rather than a conclusion.
  final bool muted;

  /// A figure the eye should land on.
  final bool strong;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                fontWeight: strong
                    ? AppTypography.semibold
                    : AppTypography.regular,
              ),
            ),
          ),
          Gap.w16,
          // Expanded rather than Flexible: a loose child shrink-wraps to the
          // figure and then sits at the left of the space it was given, which
          // left the totals floating short of the column the line items end
          // on. Tight is what puts every figure on one right edge.
          Expanded(
            child: AmountText(
              amount,
              scale: strong ? AmountScale.title : AmountScale.row,
              showCurrency: false,
              align: TextAlign.end,
              weight: muted ? AppTypography.medium : null,
              color: color ?? (muted ? scheme.onSurfaceVariant : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one thing on this screen that is allowed to be a warning — and even
/// it is a pane lit red from its corner with a red glyph, not a red box. The
/// figure above is already red; this only has to say what that means.
class InvoiceOverdueNotice extends StatelessWidget {
  const InvoiceOverdueNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = context.statusColors.danger;

    return FrostedPane(
      tone: danger,
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassWell(
            icon: Icons.schedule_rounded,
            color: danger,
            size: 40,
            iconSize: 20,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Past its due date',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: danger,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                Gap.h4,
                Text(
                  'Late payment charges may apply under your lease terms.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
