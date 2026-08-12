import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../navigation/routes.dart';
import '../application/invoice_controller.dart';

/// Section 77's Invoices screen.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(invoiceTabProvider);
    final invoices = ref.watch(filteredInvoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            tooltip: 'Payment history',
            onPressed: () => context.pushNamed(Routes.paymentHistory),
            icon: const Icon(Icons.history_rounded),
          ),
          Gap.w8,
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: SegmentedButton<InvoiceTab>(
              segments: const [
                ButtonSegment(value: InvoiceTab.all, label: Text('All')),
                ButtonSegment(
                  value: InvoiceTab.outstanding,
                  label: Text('Outstanding'),
                ),
                ButtonSegment(value: InvoiceTab.paid, label: Text('Paid')),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(invoiceTabProvider.notifier).select(selection.first),
            ),
          ),
          Expanded(
            child: switch (invoices) {
              AsyncLoading() when !invoices.hasValue => const LoadingView(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () =>
                    ref.read(invoiceListProvider.notifier).refresh(),
              ),
              _ => _InvoiceList(invoices: invoices.requireValue, tab: tab),
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceList extends ConsumerWidget {
  const _InvoiceList({required this.invoices, required this.tab});

  final List<Invoice> invoices;
  final InvoiceTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: switch (tab) {
          InvoiceTab.outstanding => 'Nothing outstanding',
          InvoiceTab.paid => 'No paid invoices yet',
          InvoiceTab.all => 'No invoices yet',
        },
        message: switch (tab) {
          InvoiceTab.outstanding => 'You are all paid up.',
          InvoiceTab.paid => 'Paid invoices will be listed here.',
          InvoiceTab.all =>
            'Invoices appear here once you have an active booking or lease.',
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(invoiceListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        itemCount: invoices.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) =>
            InvoiceCard(invoice: invoices[index]),
      ),
    );
  }
}

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.invoiceDetail,
          pathParameters: {'invoiceId': invoice.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (invoice.hasBillingPeriod)
                          Text(
                            // Section 35: every invoice states the period it
                            // bills for.
                            AppDate.period(
                              invoice.billingPeriodStart!,
                              invoice.billingPeriodEnd!,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          )
                        else if (invoice.unitNumber != null)
                          Text(
                            'Unit ${invoice.unitNumber}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: invoice.status.label,
                    tone: invoice.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.isPayable ? 'Amount due' : 'Total',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        MoneyText(
                          invoice.isPayable
                              ? invoice.amountDue
                              : invoice.total,
                          color: invoice.isOverdue ? scheme.error : null,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.isPayable ? 'Due' : 'Issued',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        AppDate.short(
                          invoice.isPayable
                              ? invoice.dueDate
                              : invoice.invoiceDate,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: invoice.isOverdue ? scheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (invoice.isPayable) ...[
                Gap.h12,
                Row(
                  children: [
                    if (invoice.isDueSoon || invoice.isOverdue)
                      Expanded(
                        child: Text(
                          invoice.isOverdue
                              ? 'Overdue'
                              : 'Due ${AppDate.relativeDays(invoice.dueDate)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: invoice.isOverdue
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      )
                    else
                      const Spacer(),
                    FilledButton(
                      onPressed: () => context.pushNamed(
                        Routes.payment,
                        pathParameters: {'invoiceId': invoice.id},
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.xl,
                        ),
                      ),
                      child: const Text('Pay'),
                    ),
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
