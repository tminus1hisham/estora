import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/glass_empty_pane.dart';
import '../../../components/glass_material.dart';
import '../../../components/glass_tinted_capsule.dart';
import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../../payments/presentation/transactions_view.dart';
import '../application/billing_property_filter.dart';
import '../application/invoice_controller.dart';
import 'widgets/billing_property_picker.dart';
import 'widgets/invoice_filter_bar.dart';
import 'widgets/invoice_list.dart';

/// The two panes of the invoices tab: what was billed, and what was paid.
enum InvoicesPane {
  invoices,
  transactions;

  /// The pane a `?tab=` value names; anything unrecognised is the invoices.
  static InvoicesPane fromSlug(String? slug) =>
      slug == Routes.invoicesTransactionsTab ? transactions : invoices;
}

/// Section 77's Invoices screen, in two panes.
///
/// The invoices are read as a statement; the transactions are the payments
/// made against them, which section 77 lists as a screen of their own. They
/// sit as two panes of one tab rather than one linking to the other because a
/// tenant reading a bill and a tenant checking that it went through are the
/// same tenant, a moment apart.
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({this.pane = InvoicesPane.invoices, super.key});

  /// The pane the screen opens on.
  final InvoicesPane pane;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _panes = TabController(
    length: InvoicesPane.values.length,
    initialIndex: widget.pane.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A link to the other pane, arriving while the tab is already up — the
    // route is rebuilt in place, so the controller has to follow it.
    if (widget.pane != oldWidget.pane) _panes.animateTo(widget.pane.index);
  }

  @override
  void dispose() {
    _panes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A tenant billed at more than one property gets a scope over both panes,
    // above the tabs because it governs both of them. Everyone else keeps the
    // bar exactly as it was.
    final picker = BillingPropertyPicker.shows(ref);
    final scaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      appBar: AppBar(
        // No title, so no toolbar: the theme's 64-unit bar was left standing
        // empty above the tabs. The tab strip is the screen's header.
        toolbarHeight: picker
            ? BillingPropertyPicker.heightOf(context) + _pickerTop
            : 5,
        automaticallyImplyLeading: false,
        // The picker is a control, not the screen's name; it is announced as
        // a button, not as a heading.
        excludeHeaderSemantics: true,
        title: picker
            ? MediaQuery(
                // An app bar caps its title's text size so a heading keeps
                // its place in the hierarchy. This is a control whose label
                // has to be read, so it follows the platform's size, and the
                // bar's height above is measured at that same size.
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: const Padding(
                  padding: EdgeInsets.only(top: _pickerTop),
                  child: BillingPropertyPicker(),
                ),
              )
            : null,
        bottom: _TabStrip(
          child: TabBar(
            controller: _panes,
            tabs: const [
              Tab(text: 'Invoices'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
      ),
      // The panes run over one lit ground that stays put while they slide,
      // so swiping from invoices to transactions moves the records, not the
      // room.
      body: GlassScene(
        child: TabBarView(
          controller: _panes,
          children: [
            _InvoicesPane(
              onSeeTransactions: () =>
                  _panes.animateTo(InvoicesPane.transactions.index),
            ),
            const TransactionsView(),
          ],
        ),
      ),
    );
  }

  /// Room between the top of the bar and the picker.
  static const double _pickerTop = Gap.sm;
}

/// The tab strip, with its labels held to a size two fixed tabs can carry.
///
/// A tab is a fixed share of the width with a fixed height; past about one
/// and a half times the base size "Transactions" no longer fits its half of a
/// phone and is cut at the edge. The labels stop growing there, as iOS stops
/// a segmented control's, and the strip itself is untouched.
class _TabStrip extends StatelessWidget implements PreferredSizeWidget {
  const _TabStrip({required this.child});

  final TabBar child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: child);
  }
}

/// The statement: a segmented filter pinned at the top, and under it the
/// record grouped by month, which is how a statement is read.
///
/// There is no hero above the filter. It restated the invoice that falls due
/// next — figure, due date, "Pay now" — and that invoice is already the first
/// card in the list carrying the same figure and the same button, so the hero
/// cost a screenful to say a thing the list was saying anyway.
class _InvoicesPane extends ConsumerWidget {
  const _InvoicesPane({required this.onSeeTransactions});

  /// Turns to the transactions pane, offered where there is nothing billed.
  final VoidCallback onSeeTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(invoiceTabProvider);
    final visible = ref.watch(filteredInvoicesProvider);
    // "All" is all at the chosen property: the counts on the filter and the
    // empty states answer for the mall the tenant is looking at.
    final all = ref.watch(scopedInvoicesProvider);
    final property = ref.watch(selectedBillingPropertyProvider);

    return switch (all) {
      AsyncLoading() when !all.hasValue => const AppSkeletonList(header: true),
      AsyncError(:final error) => ErrorView(
        failure: error is Failure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.read(invoiceListProvider.notifier).refresh(),
      ),
      _ => _Statement(
        all: all.requireValue,
        visible: visible.value ?? const <Invoice>[],
        tab: tab,
        propertyName: property?.name,
        onTab: (value) => ref.read(invoiceTabProvider.notifier).select(value),
        onRefresh: () => ref.read(invoiceListProvider.notifier).refresh(),
        onSeeTransactions: onSeeTransactions,
      ),
    };
  }
}

class _Statement extends StatelessWidget {
  const _Statement({
    required this.all,
    required this.visible,
    required this.tab,
    required this.onTab,
    required this.onRefresh,
    required this.onSeeTransactions,
    this.propertyName,
  });

  final List<Invoice> all;
  final List<Invoice> visible;
  final InvoiceTab tab;

  /// The property the statement is narrowed to; null for all of them.
  final String? propertyName;
  final ValueChanged<InvoiceTab> onTab;
  final Future<void> Function() onRefresh;
  final VoidCallback onSeeTransactions;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return _EmptyStatement(
        onRefresh: onRefresh,
        onSeeTransactions: onSeeTransactions,
      );
    }

    final months = groupInvoicesByMonth(visible);
    final barHeight = InvoiceFilterBar.heightOf(context);

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        // A tenant with two invoices still needs to be able to pull the screen
        // down to refresh it.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: InvoiceFilterHeader(
              height: barHeight,
              child: InvoiceFilterBar(
                tab: tab,
                counts: _counts,
                onSelected: onTab,
              ),
            ),
          ),
          if (months.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTab(tab: tab, propertyName: propertyName),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: months.length,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) => _Constrained(
                  child: AppReveal(
                    index: index,
                    child: InvoiceMonthSection(group: months[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<InvoiceTab, int> get _counts => {
    InvoiceTab.all: all.length,
    InvoiceTab.outstanding: all.where((i) => i.status.isOutstanding).length,
    InvoiceTab.paid: all.where((i) => i.status == InvoiceStatus.paid).length,
  };
}

/// Holds the statement to a reading width on a tablet.
class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: child,
      ),
    );
  }
}

/// A tenant with no invoices at all: what the screen is for, on a pane of
/// its own, and still pull-to-refresh.
///
/// Centred when it fits and scrolled when it does not, so at an accessibility
/// text size it runs on down the page rather than overflowing it.
class _EmptyStatement extends StatelessWidget {
  const _EmptyStatement({
    required this.onRefresh,
    required this.onSeeTransactions,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onSeeTransactions;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Gap.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - Gap.lg * 2,
            ),
            // Above the middle, where the eye settles on an empty screen;
            // dead centre under a title reads as sitting low.
            child: Align(
              alignment: const Alignment(0, -0.3),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassEmptyPane(
                  icon: Icons.receipt_long_rounded,
                  caption: 'Billing, in one place',
                  title: 'No invoices yet',
                  message:
                      'Your rent and service invoices will appear here when issued. Track what is due and keep a record of every payment.',
                  action: GlassTintedCapsule(
                    label: 'See transactions',
                    icon: Icons.history_rounded,
                    onPressed: onSeeTransactions,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The empty state for a tab that has filtered everything out.
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, this.propertyName});

  final InvoiceTab tab;

  /// Named in the message when the statement is narrowed to one property, so
  /// "all paid up" is not read as all paid up everywhere.
  final String? propertyName;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return Align(
      alignment: const Alignment(0, -0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          // As wide as the cards it stands in for, not as wide as its words.
          child: SizedBox(
            width: double.infinity,
            child: GlassEmptyPane(
              // Nothing outstanding is good news, and is lit as such.
              color: tab == InvoiceTab.outstanding ? statuses.positive : null,
              icon: switch (tab) {
                InvoiceTab.outstanding => Icons.task_alt_rounded,
                InvoiceTab.paid => Icons.receipt_long_rounded,
                InvoiceTab.all => Icons.receipt_long_rounded,
              },
              title: switch (tab) {
                InvoiceTab.outstanding => 'Nothing outstanding',
                InvoiceTab.paid => 'Nothing settled yet',
                InvoiceTab.all => 'No invoices yet',
              },
              message: switch (tab) {
                InvoiceTab.outstanding when propertyName != null =>
                  'You are all paid up at $propertyName.',
                InvoiceTab.outstanding => 'You are all paid up.',
                InvoiceTab.paid when propertyName != null =>
                  'Invoices you have paid at $propertyName will be kept here.',
                InvoiceTab.paid => 'Invoices you have paid will be kept here.',
                InvoiceTab.all =>
                  'Invoices appear here once you have an active booking or lease.',
              },
            ),
          ),
        ),
      ),
    );
  }
}
