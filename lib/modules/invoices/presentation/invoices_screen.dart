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
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/invoice_controller.dart';

/// Section 77's Invoices screen.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(invoiceTabProvider);
    final invoices = ref.watch(filteredInvoicesProvider);
    final allInvoices =
        ref.watch(invoiceListProvider).value ?? const <Invoice>[];

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
          if (allInvoices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _InvoiceOverview(invoices: allInvoices),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                  onSelectionChanged: (selection) => ref
                      .read(invoiceTabProvider.notifier)
                      .select(selection.first),
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (invoices) {
              AsyncLoading() when !invoices.hasValue => const LoadingView(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => ref.read(invoiceListProvider.notifier).refresh(),
              ),
              _ => _InvoiceList(invoices: invoices.requireValue, tab: tab),
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceOverview extends StatelessWidget {
  const _InvoiceOverview({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outstanding = invoices.where((item) => item.isPayable).length;
    final overdue = invoices.where((item) => item.isOverdue).length;
    final paid = invoices
        .where((item) => item.status == InvoiceStatus.paid)
        .length;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: scheme.onPrimary,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdue > 0
                          ? '$overdue overdue ${overdue == 1 ? 'invoice' : 'invoices'}'
                          : outstanding > 0
                          ? '$outstanding outstanding'
                          : 'You are all paid up',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Your billing position at a glance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              _InvoiceCount(label: 'Outstanding', value: outstanding),
              _InvoiceCount(label: 'Overdue', value: overdue),
              _InvoiceCount(label: 'Settled', value: paid),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceCount extends StatelessWidget {
  const _InvoiceCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value  $label',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
            itemCount: invoices.length,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) =>
                InvoiceCard(invoice: invoices[index]),
          ),
        ),
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Gap.md,
                runSpacing: Gap.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: scheme.primary,
                        ),
                      ),
                      Gap.w12,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (invoice.hasBillingPeriod)
                            Text(
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
                    ],
                  ),
                  StatusChip(
                    label: invoice.status.label,
                    tone: invoice.status.tone,
                  ),
                ],
              ),
              Gap.h12,
              Divider(color: scheme.outlineVariant),
              Gap.h12,
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Gap.lg,
                runSpacing: Gap.sm,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.isPayable ? 'AMOUNT DUE' : 'TOTAL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Gap.h4,
                      MoneyText(
                        invoice.isPayable ? invoice.amountDue : invoice.total,
                        emphasise: true,
                        color: invoice.isOverdue ? scheme.error : null,
                      ),
                    ],
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
                if (invoice.isDueSoon || invoice.isOverdue) ...[
                  Text(
                    invoice.isOverdue
                        ? 'Payment is overdue'
                        : 'Due ${AppDate.relativeDays(invoice.dueDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: invoice.isOverdue
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Gap.h8,
                ],
                FilledButton.icon(
                  onPressed: () => context.pushNamed(
                    Routes.payment,
                    pathParameters: {'invoiceId': invoice.id},
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Pay'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
