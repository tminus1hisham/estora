import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/glass_pull_down.dart';
import '../../application/billing_property_filter.dart';
import '../../application/invoice_controller.dart';

/// The invoices tab's property scope: "All properties", or one of the malls
/// the tenant is billed at, over both the statement and the transactions.
///
/// Only drawn for a tenant billed at more than one property. For everyone
/// else there is nothing to choose, and a control with one answer is noise —
/// so [shows] is false and the tab is exactly as it was.
class BillingPropertyPicker extends ConsumerWidget {
  const BillingPropertyPicker({super.key});

  /// What the pill reads before a property is chosen.
  static const String allLabel = 'All properties';

  /// Whether the picker has anything to offer.
  static bool shows(WidgetRef ref) =>
      ref.watch(billingPropertiesProvider).length > 1;

  /// The height the picker takes at the current text size.
  static double heightOf(BuildContext context) =>
      GlassPullDownPill.heightOf(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(billingPropertiesProvider);
    final selected = ref.watch(selectedBillingPropertyProvider);
    // Every invoice, including any that name no property — "All" means all.
    final total = ref.watch(invoiceListProvider).value?.length ?? 0;

    return GlassPullDownPill<String?>(
      icon: Icons.storefront_rounded,
      semanticPrefix: 'Property',
      menuLabel: 'Properties',
      selected: selected?.id,
      leadingGroup: 1,
      options: [
        GlassPullDownOption(
          value: null,
          label: allLabel,
          detail: _invoices(total),
        ),
        for (final property in properties)
          GlassPullDownOption(
            value: property.id,
            label: property.name,
            detail: _invoices(property.invoiceCount),
          ),
      ],
      onSelected: (id) =>
          ref.read(billingPropertyFilterProvider.notifier).select(id),
    );
  }

  static String _invoices(int count) =>
      '$count ${count == 1 ? 'invoice' : 'invoices'}';
}
