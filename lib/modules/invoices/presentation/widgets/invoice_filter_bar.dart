import 'package:flutter/material.dart';

import '../../../../components/glass_material.dart';
import '../../../../components/glass_segmented_control.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/invoice_controller.dart';

/// The statement's filter: all, outstanding, settled — each with how many it
/// holds — as one segmented control.
///
/// A control rather than a row of pills, because the three are one question
/// with three answers, not three things; a thumb sliding between them says so
/// in a way separate pills never did.
class InvoiceFilterBar extends StatelessWidget {
  const InvoiceFilterBar({
    required this.tab,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  final InvoiceTab tab;

  /// How many invoices each tab holds. Shown beside the label, because
  /// "Settled" with nothing next to it makes a tenant tap it to find out.
  final Map<InvoiceTab, int> counts;

  final ValueChanged<InvoiceTab> onSelected;

  /// Room above and below the control inside the bar.
  static const double _padTop = Gap.sm;
  static const double _padBottom = Gap.md;

  /// The bar's height, which a pinned sliver has to know before it builds.
  ///
  /// Measured from the control's own type at the platform's text size, so it
  /// grows exactly as the labels do and they are never clipped.
  static double heightOf(BuildContext context) =>
      GlassSegmentedControl.heightOf(context) + _padTop + _padBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, _padTop, Gap.lg, _padBottom),
      child: Center(
        child: ConstrainedBox(
          // A segmented control across a tablet's full reading width is a
          // bar, not a control; this is about where iPadOS stops them.
          constraints: const BoxConstraints(maxWidth: AppLayout.maxFormWidth),
          child: GlassSegmentedControl<InvoiceTab>(
            selected: tab,
            onChanged: onSelected,
            segments: [
              for (final value in InvoiceTab.values)
                GlassSegment(
                  value: value,
                  label: _labelFor(value),
                  count: counts[value] ?? 0,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelFor(InvoiceTab tab) => switch (tab) {
    InvoiceTab.all => 'All',
    InvoiceTab.outstanding => 'Outstanding',
    InvoiceTab.paid => 'Settled',
  };
}

/// Pins [InvoiceFilterBar] to the top of the statement.
///
/// At rest the control sits on the page's own ground, like the title above
/// it. Once the statement scrolls under it, a bar of frosted chrome fades in
/// behind it — iOS's scroll-edge appearance — so the cards passing beneath
/// are blurred rather than cut off against the control.
class InvoiceFilterHeader extends SliverPersistentHeaderDelegate {
  const InvoiceFilterHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final raised = overlaps || shrinkOffset > 0;
    final still = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Set just past the sides and the top, so the pane's rim survives
          // only along the bottom: one hairline where the bar ends, rather
          // than a box drawn round the width of the screen. The title above
          // frosts over at the same moment, so the two read as one bar.
          Positioned(
            left: -2,
            right: -2,
            top: -2,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: raised ? 1 : 0,
              duration: still ? Duration.zero : AppMotion.standard,
              curve: AppMotion.enter,
              // Chrome, not card: a card pane shares the scene's one backdrop
              // read, which is taken before the list paints, so a pinned bar
              // made of one would blur a picture without the cards in it.
              child: const FrostedPane(
                depth: GlassDepth.chrome,
                radius: 0,
                padding: EdgeInsets.zero,
                child: SizedBox.expand(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant InvoiceFilterHeader oldDelegate) => true;
}
