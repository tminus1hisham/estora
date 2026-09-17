import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../services/providers.dart';

/// The active browse filter.
///
/// Held separately from the results so changing a filter rebuilds the query
/// without the list controller having to own filter state.
final unitFilterProvider =
    NotifierProvider.family<UnitFilterController, UnitFilter, String>(
      UnitFilterController.new,
    );

class UnitFilterController extends Notifier<UnitFilter> {
  UnitFilterController(this.propertyId);

  final String propertyId;

  @override
  UnitFilter build() => UnitFilter(propertyId: propertyId);

  void setBuilding(String? buildingId) => state = state.copyWith(
    buildingId: buildingId,
    clearBuilding: buildingId == null,
    // A floor belongs to a building, so changing the building invalidates it.
    clearFloor: true,
  );

  void setFloor(String? floorId) =>
      state = state.copyWith(floorId: floorId, clearFloor: floorId == null);

  void setUnitType(String? unitTypeId) => state = state.copyWith(
    unitTypeId: unitTypeId,
    clearUnitType: unitTypeId == null,
  );

  void setQuery(String query) => state = state.copyWith(query: query);

  void setRent({int? minMinorUnits, int? maxMinorUnits}) => state = UnitFilter(
    propertyId: state.propertyId,
    buildingId: state.buildingId,
    floorId: state.floorId,
    unitTypeId: state.unitTypeId,
    query: state.query,
    minRentMinorUnits: minMinorUnits,
    maxRentMinorUnits: maxMinorUnits,
    availableOnly: state.availableOnly,
  );

  void setAvailableOnly(bool value) =>
      state = state.copyWith(availableOnly: value);

  void clear() => state = UnitFilter(propertyId: state.propertyId);
}

/// What the Browse tab lists: every block with bookable stock, straight from
/// the availability engine, grouped by property so the page reads as places
/// rather than as rows.
final availabilityProvider =
    AsyncNotifierProvider<AvailabilityController, List<UnitAvailability>>(
      AvailabilityController.new,
    );

class AvailabilityController extends AsyncNotifier<List<UnitAvailability>> {
  @override
  Future<List<UnitAvailability>> build() async {
    final result = await ref.read(unitRepositoryProvider).listAvailability();
    return switch (result) {
      Ok(:final value) =>
        value.where((block) => block.count > 0).toList(growable: false),
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}

/// Section 77's Available Units list.
///
/// Watches the filter, so a filter change refetches. Availability is decided
/// by the server's engine (section 48), not by filtering a status field here.
final unitListProvider = FutureProvider.family<List<Unit>, String>((
  ref,
  propertyId,
) async {
  final filter = ref.watch(unitFilterProvider(propertyId));
  final result = await ref
      .watch(unitRepositoryProvider)
      .listUnits(filter: filter);
  return switch (result) {
    Ok(:final value) => value.items,
    Err(:final failure) => throw failure,
  };
});

final unitDetailProvider = FutureProvider.family<Unit, String>((
  ref,
  unitId,
) async {
  final result = await ref.watch(unitRepositoryProvider).getUnit(unitId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// Section 19's effective-dated pricing, shown on the unit detail screen so a
/// tenant can see a scheduled increase before committing.
final unitPricingProvider = FutureProvider.family<List<UnitPricing>, String>((
  ref,
  unitId,
) async {
  final result = await ref.watch(unitRepositoryProvider).listPricing(unitId);
  return result.valueOrNull ?? const <UnitPricing>[];
});

final unitTypesProvider = FutureProvider.family<List<UnitType>, String>((
  ref,
  propertyId,
) async {
  final result = await ref
      .watch(unitRepositoryProvider)
      .listUnitTypes(propertyId);
  return result.valueOrNull ?? const <UnitType>[];
});
