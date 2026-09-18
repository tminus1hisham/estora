import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../components/app_glass.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/collection_columns.dart';
import '../../../components/money_count_up.dart';
import '../../../components/record_group.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/treasury.dart';
import '../../../navigation/routes.dart';
import '../../properties/application/property_controller.dart';
import '../application/owner_controller.dart';
import 'widgets/invoice_payments_sheet.dart';

/// Section 88. Money in.
///
/// What arrived over a window, what is still owed and for how long, and the
/// record of arrivals — drawn from the [OwnerReport] the contract serves:
/// every M-Pesa arrival and every invoice across the owner's properties. The
/// ageing bands are the point of the screen: an owner with KES 400,000
/// outstanding cares a great deal whether it is three days late or three
/// months.
///
/// An owner with more than one property is offered a strip under the title
/// to cut the report to one of them. An owner with one property is not: the
/// only answer it could give is the one already on screen.
class OwnerMoneyScreen extends ConsumerWidget {
  const OwnerMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(ownerReportProvider);
    final selected = ref.watch(reportPropertyProvider);
    final properties = ref.watch(propertyListProvider).value ?? const [];
    // Names for the arrivals list, which the till keys by property id only.
    final names = {for (final property in properties) property.id: property};

    Future<void> refresh() async {
      await ref.refresh(ownerReportProvider.future).then<void>((_) {});
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Revenue'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Payouts',
            onPressed: () => context.pushNamed(Routes.ownerPayouts),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          // What actually arrived, as opposed to what the ledger says is owed.
          // Two different questions, so two entries rather than one.
          PopupMenuButton<String>(
            tooltip: 'Received',
            icon: const Icon(Icons.inbox_outlined),
            onSelected: (action) => context.pushNamed(
              action == 'mpesa'
                  ? Routes.mpesaTransactions
                  : Routes.bankPayments,
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'mpesa', child: Text('M-Pesa payments')),
              PopupMenuItem(value: 'bank', child: Text('Bank payments')),
            ],
          ),
          Gap.w8,
        ],
        bottom: properties.length > 1
            ? PreferredSize(
                // Sized here, where there is a context to read the text scale
                // from; a strip that cannot grow with the type clips it.
                preferredSize: Size.fromHeight(
                  PropertyFilterBar.heightOf(context),
                ),
                child: PropertyFilterBar(
                  properties: properties,
                  selected: selected,
                  onSelected: (id) =>
                      ref.read(reportPropertyProvider.notifier).select(id),
                ),
              )
            : null,
      ),
      body: switch (report) {
        AsyncLoading() when !report.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(:final error) when !report.hasValue => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: refresh,
        ),
        _ => _Money(
          report: report.requireValue,
          // Dimmed, not replaced, while the next property's answer is on its
          // way — the figures change rather than blank.
          stale: report.isLoading,
          properties: names,
          onRefresh: refresh,
        ),
      },
    );
  }
}

/// The strip under the title that cuts the report to one property.
///
/// A tab row rather than a menu, so the property in view is always legible
/// without opening anything. It scrolls sideways — a portfolio of six is a
/// row wider than any phone — and the first tab is the whole portfolio,
/// which is where the screen opens.
class PropertyFilterBar extends StatelessWidget {
  const PropertyFilterBar({
    required this.properties,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<Property> properties;

  /// The property in view, or null for all of them.
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// One row of pills, grown with the type up to the point past which a
  /// taller strip would be eating the report it filters.
  static double heightOf(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 36 * scale.clamp(1.0, 1.7) + Gap.md + 1;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightOf(context),
      child: GlassSurface(
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
                        _PeriodPill(
                          label: 'All properties',
                          selected: selected == null,
                          onTap: () => onSelected(null),
                        ),
                        for (final property in properties) ...[
                          Gap.w8,
                          _PeriodPill(
                            label: property.name,
                            selected: selected == property.id,
                            onTap: () => onSelected(property.id),
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
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({
    required this.report,
    required this.stale,
    required this.properties,
    required this.onRefresh,
  });

  final OwnerReport report;
  final bool stale;
  final Map<String, Property> properties;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return PageEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Your money overview',
        title: 'No money activity yet',
        message: report.propertyId == null
            ? 'Once payments arrive, you can follow collections and outstanding balances here.'
            : 'Nothing has been invoiced or received for this property yet.',
        onRefresh: onRefresh,
      );
    }
    final ageing = report.ageingAt(DateTime.now());
    final owed = report.outstandingInvoices;
    final sections = <Widget>[
      _RevenueHeading(propertyName: properties[report.propertyId]?.name),
      _CollectedCard(report: report),
      if (report.hasArrears)
        _Ageing(buckets: ageing, outstanding: report.outstanding),
      if (owed.isNotEmpty) _Outstanding(invoices: owed),
      if (report.received.isNotEmpty)
        _Received(rows: report.received, properties: properties),
    ];

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedOpacity(
        opacity: stale ? 0.55 : 1,
        duration: AppMotion.standard,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxReadingWidth,
            ),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.xxl,
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => Gap.h24,
              itemBuilder: (context, index) =>
                  AppReveal(index: index, child: sections[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevenueHeading extends StatelessWidget {
  const _RevenueHeading({this.propertyName});

  final String? propertyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINANCIAL OVERVIEW',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 2,
          ),
        ),
        Gap.h8,
        Text(
          'Your portfolio. In perspective.',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
          ),
        ),
        Gap.h8,
        Text(
          propertyName ?? 'Collections and balances across your properties.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// What came in, over the window the owner picks.
///
/// The month is the default and the figure the screen is named for. The
/// narrower windows and the custom span are a question the owner asks — "what
/// landed today?" — and each answer is cut from the same arrivals the report
/// holds, by the calendar arithmetic in [CollectionWindow.resolve]. Switching
/// tabs changes a figure rather than fetching one.
class _CollectedCard extends ConsumerWidget {
  const _CollectedCard({required this.report});

  final OwnerReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final window = ref.watch(collectionWindowProvider);
    final figures = _Figures.of(report.sliceOver(window));

    return AppSurfaceCard(
      gradient: AppGradients.brandHero,
      borderRadius: AppRadius.extraLarge,
      borderColor: AppPalette.brass300.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.brass300.withValues(alpha: 0.12),
                  borderRadius: AppRadius.small,
                  border: Border.all(
                    color: AppPalette.brass300.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  size: 22,
                  color: AppPalette.brass300,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Text(
                  'Collection overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Gap.h24,
          _PeriodStrip(
            window: window,
            onSelected: (next) =>
                ref.read(collectionWindowProvider.notifier).select(next),
            onCustom: () => _pickRange(context, ref, window),
          ),
          Gap.h32,
          Text(
            figures.caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.brass300,
              letterSpacing: 1.6,
            ),
          ),
          Gap.h12,
          MoneyCountUp(
            figures.collected,
            scale: AmountScale.hero,
            color: Colors.white,
          ),
          Gap.h8,
          Text(
            figures.detail,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (figures.points.isNotEmpty) ...[
            Gap.h24,
            Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
            Gap.h16,
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: Gap.md,
              runSpacing: Gap.sm,
              children: [
                Text(
                  'Collection history',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  'Tap a column to explore',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            Gap.h12,
            CollectionColumns(
              key: ValueKey(figures.window),
              points: figures.points,
              height: 140,
              ink: Colors.white,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    CollectionWindow current,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      initialDateRange: current.period == CollectionPeriod.custom
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
      helpText: 'Collected between',
      saveText: 'Show',
    );
    if (picked == null) return;
    ref
        .read(collectionWindowProvider.notifier)
        .select(CollectionWindow.custom(from: picked.start, to: picked.end));
  }
}

/// What the card shows for one window.
class _Figures {
  const _Figures({
    required this.window,
    required this.caption,
    required this.collected,
    required this.detail,
    required this.points,
  });

  factory _Figures.of(ReportSlice slice) {
    final window = slice.window;
    final span = switch (window.period) {
      CollectionPeriod.today => 'today',
      CollectionPeriod.yesterday => 'yesterday',
      CollectionPeriod.month => 'this month',
      CollectionPeriod.custom => 'between these dates',
    };
    final caption = switch (window.period) {
      CollectionPeriod.custom =>
        'COLLECTED ${_rangeLabel(window, year: true).toUpperCase()}',
      _ => 'COLLECTED ${span.toUpperCase()}',
    };
    final count = slice.paymentCount;
    final detail = slice.isEmpty
        ? 'Nothing came in $span.'
        : '$count M-Pesa payment${count == 1 ? '' : 's'} $span.';
    return _Figures(
      window: window,
      caption: caption,
      collected: slice.collected,
      detail: detail,
      // An empty window keeps its sentence and loses its chart: a row of
      // nothing is not a picture of anything.
      points: slice.isEmpty ? const [] : slice.points,
    );
  }

  final CollectionWindow window;
  final String caption;
  final Money collected;
  final String detail;
  final List<CollectionPoint> points;
}

/// `3 – 14 Sep`, or `14 Sep` when the span is one day.
String _rangeLabel(CollectionWindow window, {bool year = false}) {
  final from = window.from!;
  final to = window.to!;
  final format = year ? AppDate.short : DateFormat('d MMM').format;
  if (from == to) return format(from);
  // Both ends in the same month say the month once.
  if (from.year == to.year && from.month == to.month) {
    return '${from.day} – ${format(to)}';
  }
  return '${format(from)} – ${format(to)}';
}

/// Today, yesterday, the month, or two dates of the owner's choosing.
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({
    required this.window,
    required this.onSelected,
    required this.onCustom,
  });

  final CollectionWindow window;
  final ValueChanged<CollectionWindow> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final custom = window.period == CollectionPeriod.custom;

    // Wrapped rather than scrolled: a chosen range has to stay in view, and
    // a pill half-hidden past the card's edge reads as a mistake.
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final (label, choice) in const [
          ('Today', CollectionWindow.today()),
          ('Yesterday', CollectionWindow.yesterday()),
          ('This month', CollectionWindow.month()),
        ])
          _PeriodPill(
            label: label,
            onDark: true,
            selected: window == choice,
            onTap: () => onSelected(choice),
          ),
        _PeriodPill(
          label: custom ? _rangeLabel(window) : 'Custom',
          onDark: true,
          selected: custom,
          icon: Icons.date_range_rounded,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onDark = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = onDark
        ? (selected ? AppPalette.navy900 : Colors.white)
        : selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: onDark
            ? (selected
                  ? AppPalette.brass300
                  : Colors.white.withValues(alpha: 0.08))
            : selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: onDark
                ? Colors.white.withValues(alpha: selected ? 0 : 0.16)
                : selected
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  Gap.w4,
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected
                          ? AppTypography.bold
                          : AppTypography.semibold,
                    ),
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

/// Outstanding money, banded by how long it has been owed.
class _Ageing extends StatelessWidget {
  const _Ageing({required this.buckets, required this.outstanding});

  final List<ArrearsBucket> buckets;
  final Money outstanding;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final showing = buckets.where((bucket) => !bucket.isEmpty).toList();

    return RecordGroup(
      heading: 'Owed to you',
      children: [
        Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total outstanding',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Gap.h8,
              AmountText(outstanding, scale: AmountScale.title),
              Gap.h16,
              ClipRRect(
                borderRadius: AppRadius.small,
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (final bucket in showing)
                        if (bucket.amount.minorUnits > 0)
                          Expanded(
                            flex: bucket.amount.minorUnits,
                            child: ColoredBox(
                              color: statuses.resolve(_tone(bucket)),
                              child: const SizedBox.expand(),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              Gap.h12,
              Text(
                'Balances by age · All invoice dates',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final (index, bucket) in showing.indexed)
          RecordRow(
            icon: index == 0
                ? Icons.schedule_rounded
                : Icons.warning_amber_rounded,
            // The bands darken as they age, which is the only thing the icons
            // and colours here are being asked to say.
            iconColor: statuses.resolve(_tone(bucket)),
            title: bucket.label,
            subtitle:
                '${bucket.invoiceCount} invoice'
                '${bucket.invoiceCount == 1 ? '' : 's'}',
            amount: AmountText(bucket.amount),
          ),
      ],
    );
  }

  static StatusTone _tone(ArrearsBucket bucket) => switch (bucket.label) {
    'Not yet due' => StatusTone.neutral,
    '1–30 days' => StatusTone.warning,
    _ => StatusTone.danger,
  };
}

/// The invoices behind the bands, soonest due first, each with who owes it.
/// Tapping one opens what has been paid against it.
class _Outstanding extends StatelessWidget {
  const _Outstanding({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final now = DateTime.now();

    return RecordGroup(
      heading: 'Outstanding invoices',
      children: [
        for (final invoice in invoices)
          RecordRow(
            icon: Icons.receipt_long_outlined,
            iconColor: statuses.resolve(
              invoice.dueDate.isBefore(now)
                  ? StatusTone.danger
                  : StatusTone.neutral,
            ),
            title: invoice.tenantName ?? invoice.invoiceNumber,
            subtitle: _where(invoice) ?? invoice.invoiceNumber,
            amount: AmountText(invoice.amountDue),
            caption: 'Due ${AppDate.short(invoice.dueDate)}',
            onTap: () => showInvoicePaymentsSheet(context, invoice),
          ),
      ],
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

/// What the till received, by month, newest first.
class _Received extends StatelessWidget {
  const _Received({required this.rows, required this.properties});

  final List<MpesaTransaction> rows;
  final Map<String, Property> properties;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final months = <DateTime?, List<MpesaTransaction>>{};

    for (final row in rows) {
      final at = row.transactedAt ?? row.createdAt;
      final key = at == null ? null : DateTime(at.year, at.month);
      months.putIfAbsent(key, () => []).add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in months.entries.indexed) ...[
          if (index > 0) Gap.h24,
          RecordGroup(
            heading: entry.key == null
                ? 'Received'
                : 'Received · ${AppDate.monthYear(entry.key!)}',
            children: [
              for (final row in entry.value)
                RecordRow(
                  icon: Icons.south_west_rounded,
                  iconColor: statuses.positive,
                  title:
                      row.payerName ??
                      row.maskedPayerPhone ??
                      row.transactionId,
                  subtitle: _where(row),
                  amount: AmountText(row.amount),
                  caption: switch (row.transactedAt ?? row.createdAt) {
                    final at? => AppDate.short(at),
                    null => row.transactionId,
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  String? _where(MpesaTransaction row) {
    final property = row.propertyId == null
        ? null
        : properties[row.propertyId!];
    final parts = [
      if (row.hasAccountNumber) row.accountNumber!.trim(),
      if (property != null) property.name,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
