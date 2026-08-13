import 'package:flutter/material.dart';

import '../../../../components/app_glass.dart';
import '../../../../components/surface_atoms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/invoice_controller.dart';

/// The tab strip that stays put while the statement runs under it.
///
/// Frosted rather than solid: the list has to keep reading as one continuous
/// document, and an opaque bar cutting across it makes the rows above look
/// like a different screen. The blur is the only thing separating them, which
/// is exactly as much separation as this needs.
class InvoiceFilterBar extends StatelessWidget {
  const InvoiceFilterBar({
    required this.tab,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  final InvoiceTab tab;

  /// How many invoices each tab holds. Shown beside the label, because "Paid"
  /// with nothing next to it makes a tenant tap it to find out.
  final Map<InvoiceTab, int> counts;

  final ValueChanged<InvoiceTab> onSelected;

  /// The bar's height, which a pinned sliver has to know before it builds.
  ///
  /// Grows with the platform's text size so the pills are never clipped.
  static double heightOf(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 38 * scale.clamp(1.0, 1.7) + Gap.xl + 1;
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      blur: 18,
      border: false,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxReadingWidth,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Row(
                    children: [
                      for (final value in InvoiceTab.values) ...[
                        if (value != InvoiceTab.values.first) Gap.w8,
                        _FilterPill(
                          label: _labelFor(value),
                          count: counts[value] ?? 0,
                          selected: value == tab,
                          onTap: () => onSelected(value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Hairline(),
        ],
      ),
    );
  }

  static String _labelFor(InvoiceTab tab) => switch (tab) {
    InvoiceTab.all => 'All',
    InvoiceTab.outstanding => 'Outstanding',
    InvoiceTab.paid => 'Settled',
  };
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: selected
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected
                        ? AppTypography.bold
                        : AppTypography.semibold,
                  ),
                ),
                Gap.w8,
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins [InvoiceFilterBar] to the top of the statement.
class InvoiceFilterHeader extends SliverPersistentHeaderDelegate {
  const InvoiceFilterHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(covariant InvoiceFilterHeader oldDelegate) => true;
}
