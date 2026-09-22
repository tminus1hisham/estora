import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/section_card.dart';
import '../../../components/status_chip.dart';
import '../../../components/surface_atoms.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../application/utility_controller.dart';
import '../application/utility_models.dart';
import 'widgets/utility_widgets.dart';

/// Re-exported so the router can build this screen from a path segment with a
/// single import of the screen itself.
export '../application/utility_models.dart' show UtilityKind;

/// One meter in full: the dial, half a year of use, and its bills.
///
/// Reached by tapping a card on the overview, or by the `kind` segment of a
/// deep link — [UtilityKind.fromSlug] is tolerant, so an unrecognised segment
/// opens water rather than an error page.
class UtilityDetailScreen extends ConsumerWidget {
  const UtilityDetailScreen({required this.kind, super.key});

  final UtilityKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(utilityAccountProvider(kind));

    final sections = <Widget>[
      _MeterHero(account: account),
      const UtilityPreviewNote(),
      SectionCard(
        title: 'Meter',
        children: [
          DetailRow(label: 'Meter number', value: account.meterNumber),
          DetailRow(label: 'Supplier', value: account.supplier),
          DetailRow(
            label: 'Latest reading',
            value: kind.formatQuantity(account.latestReading),
          ),
          DetailRow(
            label: 'Read on',
            value: AppDate.short(account.readingDate),
          ),
          DetailRow(
            label: 'Opened the month at',
            value: kind.formatQuantity(account.previousReading),
          ),
          DetailRow(
            label: 'Used this month',
            value: kind.formatQuantity(account.consumption),
            emphasise: true,
          ),
        ],
      ),
      _UsageHistory(account: account),
      _Bills(account: account),
      SurfaceAction(
        label: 'Submit a meter reading',
        icon: Icons.speed_rounded,
        primary: true,
        onPressed: () => showSubmitReadingSheet(context, kind: kind),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      body: AppRefreshIndicator(
        onRefresh: () => ref.read(utilityAccountsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, section) in sections.indexed) ...[
                      if (index > 0) Gap.h16,
                      AppReveal(index: index, child: section),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What is owed on this meter, and how the month is running.
class _MeterHero extends StatelessWidget {
  const _MeterHero({required this.account});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = account.kind;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgedHeader(
            badge: StatusChip(
              label: account.status.label,
              tone: account.status.tone,
            ),
            child: Row(
              children: [
                ToneIconTile(
                  icon: kind.icon,
                  color: kind.colorIn(context),
                  size: 40,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Amount due',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Gap.h4,
                      AmountText(
                        account.amountDue,
                        scale: AmountScale.hero,
                        color: account.status == UtilityBillStatus.overdue
                            ? scheme.error
                            : scheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.h16,
          const Hairline(),
          Gap.h16,
          UtilityUsageSummary(account: account),
        ],
      ),
    );
  }
}

/// Six months of use, drawn as bars against the tallest month.
///
/// Bars built from the app's own [LinearMeter] rather than a charting package:
/// six rows of a proportion is not a chart, and a dependency that draws axes,
/// legends and tooltips would have to be themed twice over to look like it
/// belonged here.
class _UsageHistory extends StatelessWidget {
  const _UsageHistory({required this.account});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context) {
    // Newest month first, to match every other list in the app.
    final months = account.readings.reversed.toList();
    final peak = account.peakConsumption;

    return SectionCard(
      title: 'Last six months',
      children: [
        for (final (index, reading) in months.indexed) ...[
          if (index > 0) const Hairline(),
          UtilityUsageBar(kind: account.kind, reading: reading, peak: peak),
        ],
      ],
    );
  }
}

class _Bills extends ConsumerWidget {
  const _Bills({required this.account});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: '${account.kind.label} bills',
      children: [
        for (final (index, bill) in account.bills.indexed) ...[
          if (index > 0) const Hairline(),
          UtilityBillTile(
            bill: bill,
            showKind: false,
            onMarkPaid: () => _markPaid(context, ref, bill),
          ),
        ],
      ],
    );
  }

  /// Settling a bill is mock-only, and says so. Silently showing a paid chip
  /// would leave a tenant believing a payment had been taken.
  void _markPaid(BuildContext context, WidgetRef ref, UtilityBill bill) {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(utilityAccountsProvider.notifier).markPaid(bill.reference);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${bill.reference} marked paid in this preview. No payment was '
          'taken.',
        ),
      ),
    );
  }
}
