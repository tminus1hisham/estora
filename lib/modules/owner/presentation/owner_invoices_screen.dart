import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/entities/owner.dart';
import '../application/owner_controller.dart';
import 'widgets/invoice_payments_sheet.dart';

/// Which half of the ledger an [OwnerInvoicesScreen] shows.
enum OwnerInvoiceFilter {
  paid,
  unpaid;

  /// The path segment that opens this list.
  String get slug => name;

  static OwnerInvoiceFilter fromSlug(String? slug) =>
      values.firstWhere((f) => f.slug == slug, orElse: () => unpaid);

  String get title => switch (this) {
    paid => 'Paid invoices',
    unpaid => 'Unpaid invoices',
  };
}

/// Every invoice on the owner's properties that is paid, or every one that is
/// not — one list, reached from the tile on the Revenue screen that counted it.
///
/// Read from the same [OwnerReport] the Revenue screen holds, so the count on
/// the tile and the rows here can never disagree, and cut to the same property
/// when the owner has cut the report to one. Tapping a row opens what the
/// till has received against it.
class OwnerInvoicesScreen extends ConsumerWidget {
  const OwnerInvoicesScreen({required this.filter, super.key});

  final OwnerInvoiceFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportProvider = ownerReportProvider(
      ref.watch(reportPropertyProvider),
    );
    final report = ref.watch(selectedOwnerReportProvider);

    Future<void> refresh() async {
      await ref.refresh(reportProvider.future).then<void>((_) {});
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(filter.title),
        backgroundColor: Colors.transparent,
      ),
      body: switch (report) {
        AsyncLoading() when !report.hasValue => const AppSkeletonList(),
        AsyncError(:final error) when !report.hasValue => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: refresh,
        ),
        _ => _InvoiceList(
          filter: filter,
          invoices: switch (filter) {
            OwnerInvoiceFilter.paid => report.requireValue.paidInvoices,
            OwnerInvoiceFilter.unpaid =>
              report.requireValue.outstandingInvoices,
          },
          onRefresh: refresh,
        ),
      },
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({
    required this.filter,
    required this.invoices,
    required this.onRefresh,
  });

  final OwnerInvoiceFilter filter;
  final List<Invoice> invoices;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return EmptyState(
        onRefresh: onRefresh,
        icon: Icons.receipt_long_outlined,
        title: switch (filter) {
          OwnerInvoiceFilter.paid => 'Nothing paid yet',
          OwnerInvoiceFilter.unpaid => 'Nothing owed',
        },
        message: switch (filter) {
          OwnerInvoiceFilter.paid =>
            'Invoices show here once they are settled in full.',
          OwnerInvoiceFilter.unpaid =>
            'Every invoice on your properties has been paid.',
        },
      );
    }

    // Paid invoices are a record and read by when they were raised; unpaid
    // ones are a to-do and read by when they fall due, soonest first. Both
    // lists arrive already in that order from the report.
    final months = <DateTime, List<Invoice>>{};
    for (final invoice in invoices) {
      final at = switch (filter) {
        OwnerInvoiceFilter.paid => invoice.invoiceDate,
        OwnerInvoiceFilter.unpaid => invoice.dueDate,
      };
      months.putIfAbsent(DateTime(at.year, at.month), () => []).add(invoice);
    }
    final groups = months.entries.toList(growable: false);

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            itemCount: groups.length,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) {
              final group = groups[index];
              return RecordGroup(
                heading: switch (filter) {
                  OwnerInvoiceFilter.paid => AppDate.monthYear(group.key),
                  OwnerInvoiceFilter.unpaid =>
                    'Due ${AppDate.monthYear(group.key)}',
                },
                trailing: Text(
                  '${group.value.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  for (final invoice in group.value)
                    _InvoiceRow(invoice: invoice, filter: filter),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.filter});

  final Invoice invoice;
  final OwnerInvoiceFilter filter;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final now = DateTime.now();

    return RecordRow(
      icon: Icons.receipt_long_outlined,
      iconColor: switch (filter) {
        OwnerInvoiceFilter.paid => statuses.positive,
        OwnerInvoiceFilter.unpaid => statuses.resolve(
          invoice.dueDate.isBefore(now)
              ? StatusTone.danger
              : StatusTone.neutral,
        ),
      },
      title: invoice.tenantName ?? invoice.invoiceNumber,
      subtitle: _where(invoice) ?? invoice.invoiceNumber,
      // A paid invoice's figure is what it was for; an unpaid one's is what
      // is still owed on it, which after a part-payment is not the same.
      amount: AmountText(switch (filter) {
        OwnerInvoiceFilter.paid => invoice.total,
        OwnerInvoiceFilter.unpaid => invoice.amountDue,
      }),
      caption: switch (filter) {
        OwnerInvoiceFilter.paid => invoice.invoiceNumber,
        OwnerInvoiceFilter.unpaid => 'Due ${AppDate.short(invoice.dueDate)}',
      },
      onTap: () => showInvoicePaymentsSheet(context, invoice),
    );
  }

  static String? _where(Invoice invoice) {
    final parts = [
      if (invoice.unitNumber != null) invoice.unitNumber!,
      if (invoice.propertyName != null) invoice.propertyName!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
