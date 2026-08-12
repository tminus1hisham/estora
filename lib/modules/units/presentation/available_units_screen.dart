import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_media.dart';
import '../../../components/app_surface_card.dart';
import '../../../components/money_text.dart';
import '../../../components/page_header.dart';
import '../../../components/app_reveal.dart';
import '../../../components/app_skeleton.dart';
import '../../../components/state_views.dart';
import '../../../components/status_chip.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../navigation/routes.dart';
import '../../properties/application/property_controller.dart';
import '../application/unit_controller.dart';

/// Section 77's Available Units screen.
class AvailableUnitsScreen extends ConsumerWidget {
  const AvailableUnitsScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitListProvider(propertyId));
    final filter = ref.watch(unitFilterProvider(propertyId));
    final property = ref
        .watch(propertyDetailProvider(propertyId))
        .value
        ?.property;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available units'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _openFilters(context, ref),
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          Gap.w8,
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: PageHeader(
              eyebrow: property?.name,
              title: 'Spaces ready for you',
              subtitle: units.hasValue
                  ? '${units.requireValue.length} spaces match your preferences.'
                  : 'Compare rent, location and lease requirements.',
              compact: true,
            ),
          ),
          if (filter.hasActiveFilters || !filter.availableOnly)
            _ActiveFilterBar(filter: filter, propertyId: propertyId),
          Expanded(
            child: switch (units) {
              AsyncLoading() when !units.hasValue =>
                const AppSkeletonMediaList(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => ref.invalidate(unitListProvider(propertyId)),
              ),
              _ => _UnitList(units: units.requireValue, propertyId: propertyId),
            },
          ),
        ],
      ),
    );
  }

  void _openFilters(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(propertyId: propertyId),
    );
  }
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.filter, required this.propertyId});

  final UnitFilter filter;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              filter.availableOnly
                  ? 'Showing available units only'
                  : 'Showing all units, including let and blocked',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(unitFilterProvider(propertyId).notifier).clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _UnitList extends ConsumerWidget {
  const _UnitList({required this.units, required this.propertyId});

  final List<Unit> units;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (units.isEmpty) {
      return EmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'No units match',
        message:
            'Nothing is available with these filters right now. Try widening '
            'them, or check back — units are released as bookings expire.',
        action: OutlinedButton(
          onPressed: () =>
              ref.read(unitFilterProvider(propertyId).notifier).clear(),
          child: const Text('Clear filters'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(unitListProvider(propertyId)),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        itemCount: units.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) => AppReveal(
          index: index,
          child: UnitCard(unit: units[index]),
        ),
      ),
    );
  }
}

/// A unit in a list. Also used on the home screen's suggestions.
class UnitCard extends StatelessWidget {
  const UnitCard({required this.unit, super.key});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final media = unit.imageUrls.isEmpty ? null : unit.imageUrls.first;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      elevation: AppElevation.low,
      semanticLabel: '${unit.unitNumber}, ${unit.status.label}',
      onTap: () => context.pushNamed(
        Routes.unitDetail,
        pathParameters: {'unitId': unit.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMedia(
            source: media,
            aspectRatio: 16 / 7.5,
            heroTag: 'unit-${unit.id}',
            semanticLabel: '${unit.unitNumber} interior',
            fallbackIcon: Icons.storefront_outlined,
            overlay: Stack(
              children: [
                Positioned(
                  top: Gap.md,
                  right: Gap.md,
                  child: StatusChip(
                    label: unit.status.label,
                    tone: unit.status.tone,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.unitNumber,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Gap.h4,
                          Text(
                            unit.locationLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Gap.w12,
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ],
                ),
                Gap.h16,
                Wrap(
                  spacing: Gap.lg,
                  runSpacing: Gap.sm,
                  children: [
                    if (unit.dimensionsLabel != null)
                      _Fact(
                        icon: Icons.straighten_rounded,
                        label: unit.dimensionsLabel!,
                      ),
                    if (unit.areaLabel != null)
                      _Fact(
                        icon: Icons.square_foot_rounded,
                        label: unit.areaLabel!,
                      ),
                    if (unit.depositMonths != null)
                      _Fact(
                        icon: Icons.savings_outlined,
                        label: '${unit.depositMonths} month deposit',
                      ),
                  ],
                ),
                Gap.h12,
                const Divider(height: 1),
                Gap.h12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rent',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          // Flexible on both: a Row hands its non-flex children
                          // unbounded width, so an amount long enough to exceed
                          // the card would overflow rather than ellipsize.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(child: MoneyText(unit.baseRent)),
                              Gap.w4,
                              Flexible(
                                child: Text(
                                  unit.billingFrequency.perPeriod,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: AppRadius.small,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        Gap.w4,
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Filter sheet: building, floor, unit type and rent range.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(unitFilterProvider(propertyId));
    final detail = ref.watch(propertyDetailProvider(propertyId)).value;
    final unitTypes =
        ref.watch(unitTypesProvider(propertyId)).value ?? const [];
    final notifier = ref.read(unitFilterProvider(propertyId).notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter units',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Gap.h16,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: filter.availableOnly,
                onChanged: notifier.setAvailableOnly,
                title: const Text('Available units only'),
                subtitle: const Text(
                  'Turn off to see units that are currently let, reserved or '
                  'under maintenance',
                ),
              ),
              if (detail != null && detail.buildings.isNotEmpty) ...[
                Gap.h8,
                const _FilterLabel('Building'),
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: filter.buildingId == null,
                      onSelected: (_) => notifier.setBuilding(null),
                    ),
                    for (final building in detail.buildings)
                      ChoiceChip(
                        label: Text(building.name),
                        selected: filter.buildingId == building.id,
                        onSelected: (_) => notifier.setBuilding(building.id),
                      ),
                  ],
                ),
              ],
              if (detail != null && filter.buildingId != null) ...[
                Gap.h12,
                const _FilterLabel('Floor'),
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: filter.floorId == null,
                      onSelected: (_) => notifier.setFloor(null),
                    ),
                    for (final floor
                        in detail.floorsByBuilding[filter.buildingId] ??
                            const [])
                      ChoiceChip(
                        label: Text(floor.name),
                        selected: filter.floorId == floor.id,
                        onSelected: (_) => notifier.setFloor(floor.id),
                      ),
                  ],
                ),
              ],
              if (unitTypes.isNotEmpty) ...[
                Gap.h12,
                const _FilterLabel('Unit type'),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: filter.unitTypeId == null,
                      onSelected: (_) => notifier.setUnitType(null),
                    ),
                    for (final type in unitTypes)
                      ChoiceChip(
                        label: Text(type.name),
                        selected: filter.unitTypeId == type.id,
                        onSelected: (_) => notifier.setUnitType(type.id),
                      ),
                  ],
                ),
              ],
              Gap.h12,
              const _FilterLabel('Maximum rent'),
              Wrap(
                spacing: Gap.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: filter.maxRentMinorUnits == null,
                    onSelected: (_) => notifier.setRent(),
                  ),
                  for (final cap in const [50000, 100000, 150000, 200000])
                    ChoiceChip(
                      label: Text(Money.fromMajor(cap, 'KES').formatCompact()),
                      selected:
                          filter.maxRentMinorUnits ==
                          Money.fromMajor(cap, 'KES').minorUnits,
                      onSelected: (_) => notifier.setRent(
                        maxMinorUnits: Money.fromMajor(cap, 'KES').minorUnits,
                      ),
                    ),
                ],
              ),
              Gap.h24,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.clear,
                      child: const Text('Clear all'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Show results'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: AppTypography.bold),
      ),
    );
  }
}
