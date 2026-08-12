import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';

/// Which invoices the list is showing.
enum InvoiceTab { all, outstanding, paid }

final invoiceTabProvider = NotifierProvider<InvoiceTabController, InvoiceTab>(
  InvoiceTabController.new,
);

class InvoiceTabController extends Notifier<InvoiceTab> {
  @override
  InvoiceTab build() => InvoiceTab.all;

  void select(InvoiceTab tab) => state = tab;
}

/// Section 77's Invoices screen.
///
/// The tab filter is applied client-side over one fetch rather than refetching
/// per tab: OVERDUE and PARTIALLY_PAID both count as outstanding, so a single
/// status query would not express it, and the tenant's invoice list is small
/// enough that switching tabs should be instant.
final invoiceListProvider =
    AsyncNotifierProvider<InvoiceListController, List<Invoice>>(
      InvoiceListController.new,
    );

class InvoiceListController extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final result = await ref.read(invoiceRepositoryProvider).listInvoices();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}

/// The visible list, after the tab filter.
final filteredInvoicesProvider = Provider<AsyncValue<List<Invoice>>>((ref) {
  final tab = ref.watch(invoiceTabProvider);
  return ref.watch(invoiceListProvider).whenData((invoices) {
    return switch (tab) {
      InvoiceTab.all => invoices,
      InvoiceTab.outstanding =>
        invoices.where((i) => i.status.isOutstanding).toList(),
      InvoiceTab.paid =>
        invoices.where((i) => i.status == InvoiceStatus.paid).toList(),
    };
  });
});

final invoiceDetailProvider = FutureProvider.family<Invoice, String>((
  ref,
  invoiceId,
) async {
  final result = await ref
      .watch(invoiceRepositoryProvider)
      .getInvoice(invoiceId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});
