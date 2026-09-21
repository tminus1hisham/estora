import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../../payments/presentation/transactions_view.dart';
import '../application/invoice_controller.dart';
import 'widgets/invoice_filter_bar.dart';
import 'widgets/invoice_focus_card.dart';
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
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Invoices'),
        bottom: TabBar(
          controller: _panes,
          tabs: const [
            Tab(text: 'Invoices'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _panes,
        children: [
          _InvoicesPane(
            onSeeTransactions: () =>
                _panes.animateTo(InvoicesPane.transactions.index),
          ),
          const TransactionsView(),
        ],
      ),
    );
  }
}

/// The statement: the invoice that falls due next is lifted out of the list
/// and given the figure at reading size, because that is the one a tenant
/// opens this screen to find. A frosted filter strip pins under it.
/// Everything below is the record — grouped by month, one surface per month,
/// hairlines between the lines — which is how a statement is read and not how
/// the old stack of shadowed cards read.
class _InvoicesPane extends ConsumerWidget {
  const _InvoicesPane({required this.onSeeTransactions});

  /// Turns to the transactions pane, offered where there is nothing billed.
  final VoidCallback onSeeTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(invoiceTabProvider);
    final visible = ref.watch(filteredInvoicesProvider);
    final all = ref.watch(invoiceListProvider);

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
  });

  final List<Invoice> all;
  final List<Invoice> visible;
  final InvoiceTab tab;
  final ValueChanged<InvoiceTab> onTab;
  final Future<void> Function() onRefresh;
  final VoidCallback onSeeTransactions;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return PageEmptyState(
        icon: Icons.receipt_long_outlined,
        caption: 'Billing, in one place',
        title: 'No invoices yet',
        message:
            'Your rent and service invoices will appear here when issued. Track what is due and keep a record of every payment.',
        onRefresh: onRefresh,
        action: FilledButton.tonalIcon(
          onPressed: onSeeTransactions,
          icon: const Icon(Icons.history_rounded),
          label: const Text('See transactions'),
        ),
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
          SliverToBoxAdapter(
            child: _Constrained(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.xs,
                Gap.lg,
                Gap.lg,
              ),
              child: AppReveal(child: InvoiceFocusCard(invoices: all)),
            ),
          ),
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
              child: _EmptyTab(tab: tab),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: months.length,
                separatorBuilder: (_, _) => Gap.h24,
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
  const _Constrained({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The empty state for a tab that has filtered everything out.
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab});

  final InvoiceTab tab;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: switch (tab) {
        InvoiceTab.outstanding => Icons.task_alt_rounded,
        InvoiceTab.paid => Icons.receipt_long_outlined,
        InvoiceTab.all => Icons.receipt_long_outlined,
      },
      title: switch (tab) {
        InvoiceTab.outstanding => 'Nothing outstanding',
        InvoiceTab.paid => 'Nothing settled yet',
        InvoiceTab.all => 'No invoices yet',
      },
      message: switch (tab) {
        InvoiceTab.outstanding => 'You are all paid up.',
        InvoiceTab.paid => 'Invoices you have paid will be kept here.',
        InvoiceTab.all =>
          'Invoices appear here once you have an active booking or lease.',
      },
    );
  }
}
