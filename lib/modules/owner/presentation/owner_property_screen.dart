import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/amount_text.dart';
import '../../../components/app_hero_media.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/collection_columns.dart';
import '../../../components/record_group.dart';
import '../../../components/section_card.dart';
import '../../../components/state_views.dart';
import '../../../components/surface_atoms.dart';
import '../../../components/unit_status_strip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../domain/entities/owner.dart';
import '../../../navigation/routes.dart';
import '../application/owner_controller.dart';

/// Section 88. How one property is doing.
class OwnerPropertyScreen extends ConsumerWidget {
  const OwnerPropertyScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = ref.watch(propertyPerformanceProvider(propertyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(performance.value?.propertyName ?? 'Property'),
        backgroundColor: Colors.transparent,
      ),
      body: switch (performance) {
        AsyncLoading() when !performance.hasValue => const AppSkeletonDetail(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(propertyPerformanceProvider(propertyId)),
        ),
        _ => _Performance(
          performance: performance.requireValue,
          onRefresh: () async =>
              ref.invalidate(propertyPerformanceProvider(propertyId)),
        ),
      },
    );
  }
}

class _Performance extends StatelessWidget {
  const _Performance({required this.performance, required this.onRefresh});

  final PropertyPerformance performance;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      AppHeroMedia(
        assetPath: performance.imageUrl,
        semanticLabel: performance.propertyName,
      ),
      _Occupancy(performance: performance),
      _Money(performance: performance),
      if (performance.history.isNotEmpty)
        SectionCard(
          title: 'Billed against collected',
          children: [CollectionColumns(months: performance.history)],
        ),
      _Actions(performance: performance),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxReadingWidth),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xxl),
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

class _Occupancy extends StatelessWidget {
  const _Occupancy({required this.performance});

  final PropertyPerformance performance;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return SectionCard(
      title: 'Occupancy',
      trailing: Text(
        '${(performance.occupancyRate * 100).round()}% let',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: statuses.resolve(
            performance.occupancyRate >= 0.8
                ? StatusTone.positive
                : StatusTone.warning,
          ),
        ),
      ),
      children: [
        UnitStatusStrip(mix: performance.mix),
        Gap.h16,
        const Hairline(),
        Gap.h16,
        if (performance.rateLabel != null)
          DetailRow(label: 'Asking rate', value: performance.rateLabel!),
        if (performance.totalArea != null)
          DetailRow(
            label: 'Total area',
            value: '${_trim(performance.totalArea!)} m²',
          ),
        if (performance.letArea != null)
          DetailRow(
            label: 'Let area',
            value: '${_trim(performance.letArea!)} m²',
          ),
      ],
    );
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _Money extends StatelessWidget {
  const _Money({required this.performance});

  final PropertyPerformance performance;

  @override
  Widget build(BuildContext context) {
    final statuses = context.statusColors;

    return SectionCard(
      title: 'This month',
      children: [
        StatRow(
          left: Stat(
            'Billed',
            builder: (context, align) =>
                AmountText(performance.billedThisMonth, align: align),
          ),
          right: Stat(
            'Collected',
            builder: (context, align) => AmountText(
              performance.collectedThisMonth,
              color: statuses.positive,
              align: align,
            ),
          ),
        ),
        Gap.h16,
        LinearMeter(
          value: performance.collectionRate,
          color: performance.collectionRate >= 0.9
              ? statuses.positive
              : statuses.warning,
        ),
        Gap.h16,
        const Hairline(),
        Gap.h16,
        DetailRow(
          label: 'Rent roll',
          valueWidget: AmountText(
            performance.monthlyContractedRent,
            align: TextAlign.end,
          ),
          emphasise: true,
        ),
        DetailRow(
          label: 'Outstanding',
          valueWidget: AmountText(
            performance.outstanding,
            align: TextAlign.end,
            color: performance.overdue.isPositive ? statuses.danger : null,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.performance});

  final PropertyPerformance performance;

  @override
  Widget build(BuildContext context) {
    return RecordGroup(
      heading: 'Manage',
      rowInset: 56,
      children: [
        ListTile(
          leading: const Icon(Icons.list_alt_outlined),
          title: const Text('Rent roll'),
          subtitle: Text(
            '${performance.mix.total} unit'
            '${performance.mix.total == 1 ? '' : 's'}, who is in them and '
            'what they pay.',
          ),
          onTap: () => context.pushNamed(
            Routes.ownerRentRoll,
            pathParameters: {'propertyId': performance.propertyId},
          ),
        ),
        ListTile(
          leading: const Icon(Icons.sell_outlined),
          title: const Text('Change the asking rate'),
          subtitle: Text(
            performance.rateLabel == null
                ? 'Price this property by the square metre.'
                : 'Currently ${performance.rateLabel}.',
          ),
          onTap: () => context.pushNamed(
            Routes.ownerPropertyRate,
            pathParameters: {'propertyId': performance.propertyId},
          ),
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: const Text('Preview as a tenant'),
          subtitle: const Text('See the listing the way it is browsed.'),
          onTap: () => context.pushNamed(
            Routes.ownerPreview,
            pathParameters: {'propertyId': performance.propertyId},
          ),
        ),
      ],
    );
  }
}
