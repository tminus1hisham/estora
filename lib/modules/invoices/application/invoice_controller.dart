import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
import 'billing_property_filter.dart';

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
      // Keep errors stable; the screen offers an explicit refresh.
      retry: (_, _) => null,
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

/// The visible list, after the property filter and then the tab filter.
///
/// Narrowed to the chosen property first (see [scopeInvoices]), so
/// "Outstanding" means outstanding at the estora the tenant is looking at.
final filteredInvoicesProvider = Provider<AsyncValue<List<Invoice>>>((ref) {
  final tab = ref.watch(invoiceTabProvider);
  return scopeInvoices(ref).whenData((invoices) {
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

/// One tenant's invoices, read by somebody who is not that tenant.
///
/// The landlord's counterpart to [invoiceListProvider]. Kept separate rather
/// than parameterising that one, because the two answer different questions
/// and are refreshed by different events.
final tenantInvoicesProvider = FutureProvider.family<List<Invoice>, String>((
  ref,
  tenantId,
) async {
  final result = await ref
      .read(invoiceRepositoryProvider)
      .listInvoicesForTenant(tenantId);
  return switch (result) {
    Ok(:final value) => value.items,
    Err(:final failure) => throw failure,
  };
});

/// Writes against an invoice.
final invoiceActionsProvider = Provider<InvoiceActions>(
  (ref) => InvoiceActions(ref),
);

class InvoiceActions {
  InvoiceActions(this._ref);

  final Ref _ref;

  /// Asks for payment to be postponed.
  ///
  /// The balance is untouched by this on purpose — deferral moves when, not
  /// what. The list is still refreshed, because the invoice now shows that a
  /// request is outstanding.
  Future<Result<void>> deferInvoice({
    required String invoiceId,
    required String reason,
  }) async {
    final result = await _ref
        .read(invoiceRepositoryProvider)
        .deferInvoice(invoiceId: invoiceId, reason: reason);
    if (result.isOk) _invalidate(invoiceId);
    return result;
  }

  /// Closes an invoice against something other than a payment through the app.
  ///
  /// Landlord-side. Nothing on the tenant's side of the app calls this.
  Future<Result<void>> settleInvoice(String invoiceId) async {
    final result = await _ref
        .read(invoiceRepositoryProvider)
        .settleInvoice(invoiceId);
    if (result.isOk) _invalidate(invoiceId);
    return result;
  }

  void _invalidate(String invoiceId) {
    _ref.invalidate(invoiceDetailProvider(invoiceId));
    _ref.invalidate(invoiceListProvider);
  }
}
