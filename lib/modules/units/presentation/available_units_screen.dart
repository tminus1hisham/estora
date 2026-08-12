import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/money_text.dart';
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
    final units = ref.watch(unitListProvider);
    final filter = ref.watch(unitFilterProvider);

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
          if (filter.hasActiveFilters || !filter.availableOnly)
            _ActiveFilterBar(filter: filter),
          Expanded(
            child: switch (units) {
              AsyncLoading() when !units.hasValue => const LoadingView(),
              AsyncError(:final error) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => ref.invalidate(unitListProvider),
              ),
              _ => _UnitList(units: units.requireValue),
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
  const _ActiveFilterBar({required this.filter});

  final UnitFilter filter;

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
            onPressed: () => ref.read(unitFilterProvider.notifier).clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _UnitList extends ConsumerWidget {
  const _UnitList({required this.units});

  final List<Unit> units;

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
          onPressed: () => ref.read(unitFilterProvider.notifier).clear(),
          child: const Text('Clear filters'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(unitListProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        itemCount: units.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, index) => UnitCard(unit: units[index]),
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

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.unitDetail,
          pathParameters: {'unitId': unit.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.unitNumber,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          unit.locationLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: unit.status.label,
                    tone: unit.status.tone,
                    dense: true,
                  ),
                ],
              ),
              Gap.h12,
              Row(
                children: [
                  if (unit.dimensionsLabel != null) ...[
                    _Fact(
                      icon: Icons.straighten_rounded,
                      label: unit.dimensionsLabel!,
                    ),
                    Gap.w16,
                  ],
                  if (unit.areaLabel != null)
                    _Fact(
                      icon: Icons.square_foot_rounded,
                      label: unit.areaLabel!,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            MoneyText(unit.baseRent),
                            Gap.w4,
                            Text(
                              unit.billingFrequency.perPeriod,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (unit.depositMonths != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Deposit',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          '${unit.depositMonths} months',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
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
    final filter = ref.watch(unitFilterProvider);
    final detail = ref.watch(propertyDetailProvider(propertyId)).value;
    final unitTypes = ref.watch(unitTypesProvider(propertyId)).value ?? const [];
    final notifier = ref.read(unitFilterProvider.notifier);

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
