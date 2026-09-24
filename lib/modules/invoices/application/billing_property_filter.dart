import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/billing.dart';
import '../../payments/application/payment_controller.dart';
import 'invoice_controller.dart';

/// Which of a tenant's properties the billing screens are showing.
///
/// A tenant can lease in more than one estora, and a statement that runs two
/// malls' rent together answers "what do I owe?" but not "what do I owe at
/// Sarit?". The invoices tab lets them narrow both of its panes — what was
/// billed and what was paid — to one property, and back to all of them.
///
/// Everything here is derived from the one statement fetch. The live API has
/// no "my properties" route a tenant can read, and the invoices already name
/// the property they bill for, so the list of properties *is* the set of
/// properties the tenant has been billed at. That is also the only list worth
/// offering: a property with nothing billed would filter both panes to empty.

/// One property the tenant has been billed at.
class BillingProperty {
  const BillingProperty({
    required this.id,
    required this.name,
    required this.invoiceCount,
  });

  /// The server's property id. Properties are told apart by this, never by
  /// name: two malls may share one, and a renamed estora is still the same one.
  final String id;

  /// The name the invoices carry, or a stand-in when none of them did.
  final String name;

  /// How many of the tenant's invoices bill for it. A count of records, shown
  /// beside the name in the picker — not a sum of anything.
  final int invoiceCount;

  @override
  bool operator ==(Object other) =>
      other is BillingProperty &&
      other.id == id &&
      other.name == name &&
      other.invoiceCount == invoiceCount;

  @override
  int get hashCode => Object.hash(id, name, invoiceCount);
}

/// The distinct properties across the tenant's invoices, by name.
///
/// Empty until the statement has loaded, and while a refresh is in flight it
/// keeps answering from the statement it already had, so the picker does not
/// blink out and back.
///
/// Invoices without a property id are left out: there is nothing to filter
/// them by, and they still show under "All properties".
final billingPropertiesProvider = Provider<List<BillingProperty>>((ref) {
  final invoices = ref.watch(invoiceListProvider).value ?? const <Invoice>[];

  final names = <String, String?>{};
  final counts = <String, int>{};
  for (final invoice in invoices) {
    final id = _clean(invoice.propertyId);
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    // The first invoice that names the property names it; one that arrived
    // without a name does not blank out one that came with it.
    names[id] ??= _clean(invoice.propertyName);
  }

  return [
    for (final id in counts.keys)
      BillingProperty(
        id: id,
        name: names[id] ?? 'Property $id',
        invoiceCount: counts[id]!,
      ),
  ]..sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
});

/// The property the tenant picked, by id; null for all of them.
///
/// Shared by both panes of the invoices tab, so turning from the statement to
/// the transactions keeps the tenant in the estora they were looking at.
final billingPropertyFilterProvider =
    NotifierProvider<BillingPropertyFilter, String?>(BillingPropertyFilter.new);

class BillingPropertyFilter extends Notifier<String?> {
  @override
  String? build() {
    // A property that is no longer billed — the last lease there has ended
    // and its invoices have gone from the statement — cannot stay picked, or
    // the tab would sit filtered to nothing behind a pill naming a estora the
    // tenant can no longer choose. Drop back to all of them.
    ref.listen(billingPropertiesProvider, (_, properties) {
      final id = state;
      if (id != null && !properties.any((p) => p.id == id)) state = null;
    });
    return null;
  }

  /// Narrows the tab to [propertyId], or widens it back out with null.
  void select(String? propertyId) => state = propertyId;
}

/// The property the billing panes are narrowed to, or null for all of them.
///
/// Read this rather than [billingPropertyFilterProvider]: it only names a
/// property that is still on the statement, and only when there is more than
/// one to choose between. With one property the picker is not shown, so no
/// filter the tenant cannot see can be left applied.
final selectedBillingPropertyProvider = Provider<BillingProperty?>((ref) {
  final properties = ref.watch(billingPropertiesProvider);
  final id = ref.watch(billingPropertyFilterProvider);
  if (id == null || properties.length < 2) return null;
  for (final property in properties) {
    if (property.id == id) return property;
  }
  return null;
});

/// The statement, narrowed to the chosen property.
///
/// What the invoices pane treats as "all": the segmented control counts
/// within it, and its empty states speak for it. The home screen's preview
/// reads [invoiceListProvider] directly and is never narrowed.
final scopedInvoicesProvider = Provider<AsyncValue<List<Invoice>>>(
  (ref) => scopeInvoices(ref),
);

/// [scopedInvoicesProvider]'s reading, for a provider that needs the same
/// list without depending on it.
///
/// A derived provider that watches another derived provider can be left
/// stale while nothing listens to it — the statement pane is torn down while
/// the transactions are showing — and catching up as the pane comes back
/// then refreshes the chain in the middle of a build, which Flutter refuses.
/// Reading the two live sources directly keeps each derived list one step
/// from them.
AsyncValue<List<Invoice>> scopeInvoices(Ref ref) {
  final property = ref.watch(selectedBillingPropertyProvider);
  final invoices = ref.watch(invoiceListProvider);
  if (property == null) return invoices;
  return invoices.whenData(
    (items) => items
        .where((invoice) => _clean(invoice.propertyId) == property.id)
        .toList(),
  );
}

/// The payment history, narrowed to the chosen property.
///
/// A payment is placed by its own property id where it carries one, and
/// otherwise by the invoice it paid — the live API embeds payments in their
/// invoices, so that invoice is always on the statement. A payment that can
/// be placed by neither is shown only under "All properties" rather than
/// guessed into one.
final scopedPaymentsProvider = Provider<AsyncValue<List<Payment>>>((ref) {
  final property = ref.watch(selectedBillingPropertyProvider);
  final payments = ref.watch(paymentHistoryProvider);
  if (property == null) return payments;

  final locate = _paymentLocator(
    ref.watch(invoiceListProvider).value ?? const <Invoice>[],
  );
  return payments.whenData(
    (items) =>
        items.where((payment) => locate(payment) == property.id).toList(),
  );
});

/// The property a payment was made for, by the same reading as
/// [scopedPaymentsProvider]; null where it cannot be placed.
///
/// For a history showing every property, where each row has to say which
/// estora it paid.
final paymentPropertyProvider = Provider<BillingProperty? Function(Payment)>((
  ref,
) {
  final locate = _paymentLocator(
    ref.watch(invoiceListProvider).value ?? const <Invoice>[],
  );
  final properties = {
    for (final property in ref.watch(billingPropertiesProvider))
      property.id: property,
  };
  return (payment) => properties[locate(payment)];
});

/// Places a payment by its own property id where it carries one, and
/// otherwise by the invoice it paid — by id, or by number for a record that
/// only names it.
String? Function(Payment) _paymentLocator(List<Invoice> invoices) {
  final byId = <String, String>{};
  final byNumber = <String, String>{};
  for (final invoice in invoices) {
    final propertyId = _clean(invoice.propertyId);
    if (propertyId == null) continue;
    byId[invoice.id] = propertyId;
    byNumber[invoice.invoiceNumber] = propertyId;
  }
  return (payment) =>
      _clean(payment.propertyId) ??
      byId[payment.invoiceId] ??
      byNumber[payment.invoiceNumber];
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
