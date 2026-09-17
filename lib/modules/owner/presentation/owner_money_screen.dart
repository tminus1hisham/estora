import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../components/app_refresh_indicator.dart';
import '../../../components/amount_text.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/collection_columns.dart';
import '../../../components/money_count_up.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/page_empty_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';

/// Section 88. Money in.
///
/// What arrived this month, what is still owed and for how long, and the
/// record of arrivals. The ageing bands are the point of the screen: an owner
/// with KES 400,000 outstanding cares a great deal whether it is three days
/// late or three months.
class OwnerMoneyScreen extends ConsumerWidget {
  const OwnerMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ownerLedgerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Money'),
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
      ),
      body: switch (ledger) {
        AsyncLoading() when !ledger.hasValue => const AppSkeletonList(
          header: true,
        ),
        AsyncError(error: UnsupportedFeatureFailure()) => PageEmptyState(
          onRefresh: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
          icon: Icons.account_balance_wallet_outlined,
          caption: 'Your money overview',
          title: 'Money overview is on its way',
          message:
              'Collections, outstanding balances and payouts will appear here when money tracking is available.',
        ),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
        ),
        _ => _Money(
          ledger: ledger.requireValue,
          onRefresh: () async {
            await ref.refresh(ownerLedgerProvider.future).then<void>((_) {});
          },
        ),
      },
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.ledger, required this.onRefresh});

  final OwnerLedger ledger;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (ledger.collectedThisMonth.isZero &&
        ledger.platformFeeThisMonth.isZero &&
        ledger.netThisMonth.isZero &&
        ledger.totalOutstanding.isZero &&
        !ledger.hasArrears &&
        ledger.collections.isEmpty &&
        ledger.history.isEmpty &&
        ledger.payouts.isEmpty) {
      return PageEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Your money overview',
        title: 'No money activity yet',
        message:
            'Once payments arrive, you can follow collections, outstanding balances and payouts here.',
        onRefresh: onRefresh,
      );
    }
    final sections = <Widget>[
      _CollectedCard(ledger: ledger),
      if (ledger.hasArrears) _Ageing(buckets: ledger.ageing),
      if (ledger.collections.isNotEmpty)
        _Collections(collections: ledger.collections),
    ];

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadingWidth,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
            itemCount: sections.length,
            separatorBuilder: (_, _) => Gap.h24,
            itemBuilder: (context, index) =>
                AppReveal(index: index, child: sections[index]),
          ),
        ),
      ),
    );
  }
}

/// What came in, over the window the owner picks.
///
/// The month is the default and the figure the screen is named for. The
/// narrower windows and the custom span are a question the owner asks — "what
/// landed today?" — and each answer is a fresh server total, never the
/// ledger's recent arrivals added up here (section 84 rule 7). The last
/// answer stays on screen while the next loads, so switching tabs changes a
/// figure rather than blanking a card.
///
/// Until the first series arrives, or where the server cannot answer the
/// query at all, the card shows the month exactly as the ledger states it.
class _CollectedCard extends ConsumerWidget {
  const _CollectedCard({required this.ledger});

  final OwnerLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final window = ref.watch(collectionWindowProvider);
    final series = ref.watch(collectionSeriesProvider);
    final answered = series.hasValue ? series.requireValue : null;
    final figures = answered == null
        ? _Figures.fromLedger(ledger)
        : _Figures.fromSeries(answered);
    final stale = answered != null && answered.window != window;
    // A server that cannot answer per-window queries at all leaves the month
    // as the ledger states it, with no tabs to promise otherwise.
    final unsupported = series.error is UnsupportedFeatureFailure;

    return SectionCard(
      children: [
        if (!unsupported) ...[
          _PeriodStrip(
            window: window,
            onSelected: (next) =>
                ref.read(collectionWindowProvider.notifier).select(next),
            onCustom: () => _pickRange(context, ref, window),
          ),
          Gap.h16,
        ],
        AnimatedOpacity(
          // Dimmed, not replaced, while the next window is on its way.
          opacity: stale || (series.isLoading && answered == null) ? 0.55 : 1,
          duration: AppMotion.standard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                figures.caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              Gap.h12,
              MoneyCountUp(figures.collected, scale: AmountScale.hero),
              Gap.h8,
              Text(
                figures.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (series.hasError && !series.isLoading && !unsupported) ...[
                Gap.h8,
                _SeriesError(
                  onRetry: () => ref.invalidate(collectionSeriesProvider),
                ),
              ],
              if (figures.points.isNotEmpty) ...[
                Gap.h24,
                CollectionColumns(
                  key: ValueKey(figures.window),
                  points: figures.points,
                  height: 120,
                ),
              ],
            ],
          ),
        ),
      ],
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

/// What the card shows, whichever of its two sources it came from.
class _Figures {
  const _Figures({
    required this.window,
    required this.caption,
    required this.collected,
    required this.detail,
    required this.points,
  });

  factory _Figures.fromLedger(OwnerLedger ledger) => _Figures(
    window: const CollectionWindow.month(),
    caption: 'COLLECTED THIS MONTH',
    collected: ledger.collectedThisMonth,
    detail: _dueLine(ledger.netThisMonth, ledger.platformFeeThisMonth),
    points: [for (final month in ledger.history) CollectionPoint.month(month)],
  );

  factory _Figures.fromSeries(CollectionSeries series) {
    final window = series.window;
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
    final count = series.paymentCount;
    final detail = series.isEmpty
        ? 'Nothing came in $span.'
        : '${_dueLine(series.net, series.platformFee)} '
              '$count payment${count == 1 ? '' : 's'}.';
    return _Figures(
      window: window,
      caption: caption,
      collected: series.collected,
      detail: detail,
      // An empty window keeps its sentence and loses its chart: a row of
      // nothing is not a picture of anything.
      points: series.isEmpty ? const [] : series.points,
    );
  }

  final CollectionWindow window;
  final String caption;
  final Money collected;
  final String detail;
  final List<CollectionPoint> points;

  static String _dueLine(Money net, Money fee) =>
      '${net.format()} due to you after ${fee.format()} in platform fees.';
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
            selected: window == choice,
            onTap: () => onSelected(choice),
          ),
        _PeriodPill(
          label: custom ? _rangeLabel(window) : 'Custom',
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

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
      label: label,
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
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected
                        ? AppTypography.bold
                        : AppTypography.semibold,
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

/// One line for a window the server could not answer, and a way to ask again.
class _SeriesError extends StatelessWidget {
  const _SeriesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'That period could not be loaded.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.statusColors.resolve(StatusTone.danger),
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Outstanding money, banded by how long it has been owed.
class _Ageing extends StatelessWidget {
  const _Ageing({required this.buckets});

  final List<ArrearsBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final showing = buckets.where((bucket) => !bucket.isEmpty).toList();

    return RecordGroup(
      heading: 'Owed to you',
      children: [
        for (final (index, bucket) in showing.indexed)
          RecordRow(
            icon: index == 0
                ? Icons.schedule_rounded
                : Icons.warning_amber_rounded,
            // The bands darken as they age, which is the only thing the icons
            // and colours here are being asked to say.
            iconColor: statuses.resolve(switch (bucket.label) {
              'Not yet due' => StatusTone.neutral,
              '1–30 days' => StatusTone.warning,
              _ => StatusTone.danger,
            }),
            title: bucket.label,
            subtitle:
                '${bucket.invoiceCount} invoice'
                '${bucket.invoiceCount == 1 ? '' : 's'}',
            amount: AmountText(bucket.amount),
          ),
      ],
    );
  }
}

class _Collections extends StatelessWidget {
  const _Collections({required this.collections});

  final List<OwnerCollection> collections;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;
    final months = <DateTime, List<OwnerCollection>>{};

    for (final collection in collections) {
      final key = DateTime(collection.paidAt.year, collection.paidAt.month);
      months.putIfAbsent(key, () => []).add(collection);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in months.entries.indexed) ...[
          if (index > 0) Gap.h24,
          RecordGroup(
            heading: AppDate.monthYear(entry.key),
            children: [
              for (final collection in entry.value)
                RecordRow(
                  icon: Icons.south_west_rounded,
                  iconColor: statuses.positive,
                  title: collection.tenantName,
                  subtitle: collection.unitNumber == null
                      ? collection.propertyName
                      : '${collection.unitNumber} · '
                            '${collection.propertyName}',
                  amount: AmountText(collection.amount),
                  caption: AppDate.short(collection.paidAt),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
