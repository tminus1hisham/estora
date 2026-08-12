import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../navigation/routes.dart';
import '../application/invoice_controller.dart';

/// Section 77's Invoice Details screen.
///
/// Every figure on this screen is rendered exactly as the server supplied it.
/// The subtotal is not a sum of the lines, the total is not subtotal plus tax,
/// and the amount due is not total minus paid — all four are fields on the
/// invoice. Section 84 rule 7 puts totalling on the server, and rule 4 requires
/// a historical invoice to keep the figures it was issued with, so recomputing
/// any of them here would risk showing a tenant something their invoice does
/// not say.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(title: Text(invoice.value?.invoiceNumber ?? 'Invoice')),
      body: switch (invoice) {
        AsyncLoading() when !invoice.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
        _ => _Body(invoice: invoice.requireValue),
      },
      bottomNavigationBar: (invoice.value?.isPayable ?? false)
          ? SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.md,
                    Gap.lg,
                    Gap.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'AMOUNT DUE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                ),
                          ),
                          Gap.h4,
                          MoneyText(invoice.requireValue.amountDue),
                          Gap.h12,
                          FilledButton.icon(
                            onPressed: () => context.pushNamed(
                              Routes.payment,
                              pathParameters: {'invoiceId': invoiceId},
                            ),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Pay securely'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(invoiceDetailProvider(invoice.id)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              Container(
                padding: const EdgeInsets.all(Gap.xl),
                decoration: BoxDecoration(
                  color: invoice.isOverdue
                      ? scheme.errorContainer
                      : scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.isPayable ? 'AMOUNT DUE' : 'INVOICE TOTAL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: invoice.isOverdue
                            ? scheme.onErrorContainer
                            : scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Gap.h8,
                    MoneyText(
                      invoice.isPayable ? invoice.amountDue : invoice.total,
                      emphasise: true,
                      color: invoice.isOverdue ? scheme.onErrorContainer : null,
                    ),
                    Gap.h12,
                    Text(
                      invoice.isPayable
                          ? invoice.isOverdue
                                ? 'Due ${AppDate.full(invoice.dueDate)} · Payment overdue'
                                : 'Due ${AppDate.full(invoice.dueDate)}'
                          : 'Issued ${AppDate.full(invoice.invoiceDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: invoice.isOverdue
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.h12,
              SectionCard(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Gap.md,
                    runSpacing: Gap.sm,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (invoice.unitNumber != null)
                            Text(
                              '${invoice.propertyName ?? ''} · '
                              'Unit ${invoice.unitNumber}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      StatusChip(
                        label: invoice.status.label,
                        tone: invoice.status.tone,
                      ),
                    ],
                  ),
                  Gap.h12,
                  DetailRow(
                    label: 'Issued',
                    value: AppDate.full(invoice.invoiceDate),
                  ),
                  DetailRow(label: 'Due', value: AppDate.full(invoice.dueDate)),
                  // Section 35: the billing period is what makes proration,
                  // termination settlement and disputes tractable, so it is shown
                  // rather than left implicit in the description.
                  if (invoice.hasBillingPeriod)
                    DetailRow(
                      label: 'Billing period',
                      value: AppDate.period(
                        invoice.billingPeriodStart!,
                        invoice.billingPeriodEnd!,
                      ),
                    ),
                ],
              ),

              Gap.h12,
              // Section 33: never store only the total, and never show only the
              // total either.
              SectionCard(
                title: 'Breakdown',
                children: [
                  for (final line in invoice.lines) _LineRow(line: line),
                  const Divider(height: Gap.xl),
                  DetailRow(
                    label: 'Subtotal',
                    valueWidget: MoneyText(invoice.subtotal, bare: true),
                  ),
                  if (invoice.tax.isPositive)
                    DetailRow(
                      label: 'Tax',
                      valueWidget: MoneyText(invoice.tax, bare: true),
                    ),
                  if (invoice.discount.isPositive)
                    DetailRow(
                      label: 'Discount',
                      valueWidget: MoneyText(-invoice.discount, bare: true),
                    ),
                  const Divider(),
                  DetailRow(
                    label: 'Total',
                    valueWidget: MoneyText(invoice.total),
                    emphasise: true,
                  ),
                  if (invoice.amountPaid.isPositive) ...[
                    DetailRow(
                      label: 'Paid',
                      valueWidget: MoneyText(invoice.amountPaid, bare: true),
                    ),
                    DetailRow(
                      label: 'Amount due',
                      valueWidget: MoneyText(
                        invoice.amountDue,
                        color: invoice.isOverdue ? scheme.error : null,
                      ),
                      emphasise: true,
                    ),
                  ],
                ],
              ),

              if (invoice.isOverdue) ...[
                Gap.h12,
                Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: scheme.onErrorContainer,
                      ),
                      Gap.w12,
                      Expanded(
                        child: Text(
                          'This invoice is past its due date. Late payment charges '
                          'may apply under your lease terms.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.description),
        if (line.showsQuantity)
          Text(
            '${line.quantity} × ${line.unitPrice.formatBare()}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        if (line.taxAmount != null && line.taxAmount!.isPositive)
          Text(
            'incl. ${line.taxRate?.toStringAsFixed(0)}% tax of '
            '${line.taxAmount!.formatBare()}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
    final amount = MoneyText(line.amount, bare: true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                description,
                Gap.h8,
                Align(alignment: Alignment.centerRight, child: amount),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: description),
                Gap.w12,
                amount,
              ],
            ),
    );
  }
}
