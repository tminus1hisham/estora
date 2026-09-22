import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/glass_material.dart';
import '../../../components/glass_tinted_capsule.dart';
import '../../../components/state_views.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/billing.dart';
import '../../../navigation/routes.dart';
import '../application/invoice_controller.dart';
import 'widgets/invoice_document.dart';
import 'widgets/pay_invoice.dart';

/// Section 77's Invoice Details screen.
///
/// Read as a document: the head of the invoice on the brand surface, then what
/// it is made of, then — only if it applies — the warning. Nothing between
/// those three is a card for its own sake.
///
/// It sits on the same lit ground as the statement it was opened from, with
/// the bar at the top and the pay bar at the foot both frosted, so the
/// document scrolls under them rather than being cut off against them.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  /// Whether the document has scrolled up under the top bar, which is when
  /// the bar frosts over.
  bool _raised = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final raised = notification.metrics.extentBefore > 0;
    if (raised != _raised) setState(() => _raised = raised);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final invoiceId = widget.invoiceId;
    final invoice = ref.watch(invoiceDetailProvider(invoiceId));
    final still = MediaQuery.disableAnimationsOf(context);

    // The two ways of dealing with an invoice that are not "pay it now": tell
    // us about a payment made at a bank, and ask for more time. Both are real
    // and neither belongs on the primary action, so they sit in the overflow
    // rather than competing with it.
    final payable = invoice.value?.isPayable ?? false;

    return GlassScene(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          title: Text(invoice.value?.invoiceNumber ?? 'Invoice'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          // iOS's scroll-edge appearance: bare over the ground at rest,
          // frosted once the document passes beneath. Set just past the
          // sides and top so only the bottom hairline of the pane shows.
          flexibleSpace: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -2,
                  right: -2,
                  top: -2,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _raised ? 1 : 0,
                    duration: still ? Duration.zero : AppMotion.standard,
                    curve: AppMotion.enter,
                    child: const FrostedPane(
                      depth: GlassDepth.chrome,
                      radius: 0,
                      padding: EdgeInsets.zero,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (payable)
              PopupMenuButton<String>(
                onSelected: (action) => context.pushNamed(
                  action == 'bank' ? Routes.bankTransfer : Routes.deferInvoice,
                  pathParameters: {'invoiceId': invoiceId},
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'bank',
                    child: Text('I paid by bank transfer'),
                  ),
                  if (invoice.requireValue.canRequestDeferral)
                    const PopupMenuItem(
                      value: 'defer',
                      child: Text('Request more time'),
                    ),
                ],
              ),
          ],
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: switch (invoice) {
            AsyncLoading() when !invoice.hasValue => const SafeArea(
              child: AppSkeletonDetail(heroHeight: 260),
            ),
            AsyncError(:final error) => SafeArea(
              child: ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () async {
                  await ref
                      .refresh(invoiceDetailProvider(invoiceId).future)
                      .then<void>((_) {});
                },
              ),
            ),
            _ => _Body(invoice: invoice.requireValue),
          },
        ),
        bottomNavigationBar: payable
            ? _PayBar(invoice: invoice.requireValue)
            : null,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = <Widget>[
      InvoiceDocumentHero(invoice: invoice),
      InvoiceLedger(invoice: invoice),
      if (invoice.isOverdue) const InvoiceOverdueNotice(),
    ];
    // The bars above and below are laid over the document, and the scaffold
    // reports how much of it they cover.
    final insets = MediaQuery.paddingOf(context);

    return AppRefreshIndicator(
      onRefresh: () async {
        await ref
            .refresh(invoiceDetailProvider(invoice.id).future)
            .then<void>((_) {});
      },
      edgeOffset: insets.top,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Gap.lg,
              insets.top + Gap.xs,
              Gap.lg,
              insets.bottom + Gap.xl,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h16,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}

/// The amount owed, and the way to settle it, held at the foot of the screen
/// on a bar of frosted chrome the document scrolls under.
class _PayBar extends ConsumerWidget {
  const _PayBar({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stacked = prefersStacked(context);

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AMOUNT DUE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        Gap.h4,
        // Plain ink: the document above already says, in red, that it is
        // late. The bar is where it is settled, not where it is scolded.
        AmountText(invoice.amountDue, scale: AmountScale.title),
      ],
    );

    // The same quiet capsule as the statement's cards. The bar being pinned
    // is what makes it findable; a lit button on top of that shouted.
    final pay = GlassTintedCapsule(
      label: 'Pay now',
      expand: true,
      onPressed: () => payInvoice(context, ref, invoice),
    );

    return Stack(
      children: [
        // Past the sides and the bottom, so the rim shows only as the one
        // hairline along the top of the bar.
        Positioned(
          left: -2,
          right: -2,
          top: 0,
          bottom: -2,
          child: const FrostedPane(
            depth: GlassDepth.chrome,
            radius: 0,
            padding: EdgeInsets.zero,
            child: SizedBox.expand(),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxReadingWidth,
              ),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [amount, Gap.h12, pay],
                    )
                  : Row(
                      children: [
                        Expanded(child: amount),
                        Gap.w16,
                        Expanded(child: pay),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
