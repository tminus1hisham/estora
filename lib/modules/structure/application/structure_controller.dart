import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../services/providers.dart';
import '../../owner/application/owner_controller.dart';
import '../../properties/application/property_controller.dart';
import '../../units/application/unit_controller.dart';

/// The blocks a property is divided into.
final propertyBlocksProvider = FutureProvider.autoDispose
    .family<List<Building>, String>((ref, propertyId) async {
      final result = await ref
          .read(propertyStructureRepositoryProvider)
          .listBlocks(propertyId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

final blockProvider = FutureProvider.autoDispose.family<Building, String>((
  ref,
  blockId,
) async {
  final result = await ref
      .read(propertyStructureRepositoryProvider)
      .getBlock(blockId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final blockUnitsProvider = FutureProvider.autoDispose
    .family<List<Unit>, String>((ref, blockId) async {
      final result = await ref
          .read(propertyStructureRepositoryProvider)
          .listBlockUnits(blockId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

/// Every unit in a property, let or not — one call, read by the property
/// screen's unit list and counted by [propertyOccupancyProvider]. Invalidate
/// this, not the occupancy, to refetch both.
final propertyUnitsProvider = FutureProvider.autoDispose
    .family<List<Unit>, String>((ref, propertyId) async {
      final result = await ref
          .read(unitRepositoryProvider)
          .listUnits(
            filter: UnitFilter(propertyId: propertyId, availableOnly: false),
          );
      return switch (result) {
        Ok(:final value) => value.items,
        Err(:final failure) => throw failure,
      };
    });

/// How a property's units are let, whole and by block.
///
/// Counted from the unit records rather than read off the property, because
/// the contract publishes no occupancy figure and the block list needs the
/// split anyway. The block screen counts from the units it has already
/// fetched.
final propertyOccupancyProvider = FutureProvider.autoDispose
    .family<PropertyOccupancy, String>(
      (ref, propertyId) async => PropertyOccupancy.of(
        await ref.watch(propertyUnitsProvider(propertyId).future),
      ),
    );

/// Writes against the shape of a property.
final structureActionsProvider = Provider<StructureActions>(
  (ref) => StructureActions(ref),
);

/// Creating, amending and removing the blocks and units of a property.
///
/// Every method here refreshes what a change actually touched, and does so
/// only on success. A block rename changes the block list, the units that name
/// it, and the property that counts them — leaving any of those stale would
/// show the owner two different answers on two adjacent screens.
class StructureActions {
  StructureActions(this._ref);

  final Ref _ref;

  Future<Result<void>> createBlock(BuildingDraft draft) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .createBlock(draft);
    if (result.isOk) _invalidateProperty(draft.propertyId);
    return result;
  }

  Future<Result<void>> updateBlock({
    required String blockId,
    required BuildingDraft draft,
  }) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .updateBlock(blockId: blockId, draft: draft);
    if (result.isOk) {
      _ref.invalidate(blockProvider(blockId));
      _ref.invalidate(blockUnitsProvider(blockId));
      _invalidateProperty(draft.propertyId);
    }
    return result;
  }

  Future<Result<void>> deleteBlock({
    required String blockId,
    required String propertyId,
  }) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .deleteBlock(blockId);
    if (result.isOk) {
      _ref.invalidate(blockProvider(blockId));
      _invalidateProperty(propertyId);
    }
    return result;
  }

  Future<Result<void>> createUnit(UnitDraft draft) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .createUnit(draft);
    if (result.isOk) _invalidateUnits(draft.propertyId, draft.blockId);
    return result;
  }

  Future<Result<void>> updateUnit({
    required String unitId,
    required UnitDraft draft,
  }) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .updateUnit(unitId: unitId, draft: draft);
    if (result.isOk) {
      _ref.invalidate(unitDetailProvider(unitId));
      _invalidateUnits(draft.propertyId, draft.blockId);
    }
    return result;
  }

  Future<Result<void>> deleteUnit({
    required String unitId,
    required String propertyId,
    String? blockId,
  }) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .deleteUnit(unitId);
    if (result.isOk) {
      _ref.invalidate(unitDetailProvider(unitId));
      _invalidateUnits(propertyId, blockId);
    }
    return result;
  }

  Future<Result<void>> updateProperty({
    required String propertyId,
    required PropertyDraft draft,
  }) async {
    final result = await _ref
        .read(propertyStructureRepositoryProvider)
        .updateProperty(propertyId: propertyId, draft: draft);
    if (result.isOk) _invalidateProperty(propertyId);
    return result;
  }

  Future<Result<void>> setArchived({
    required String propertyId,
    required bool archived,
  }) async {
    final repository = _ref.read(propertyStructureRepositoryProvider);
    final result = archived
        ? await repository.archiveProperty(propertyId)
        : await repository.restoreProperty(propertyId);
    if (result.isOk) _invalidateProperty(propertyId);
    return result;
  }

  void _invalidateProperty(String propertyId) {
    _ref.invalidate(ownerReportProvider);
    _ref.invalidate(propertyBlocksProvider(propertyId));
    _ref.invalidate(propertyDetailProvider(propertyId));
    _ref.invalidate(propertyUnitsProvider(propertyId));
    _ref.invalidate(propertyListProvider);
    _ref.invalidate(propertyPerformanceProvider(propertyId));
    _ref.invalidate(ownerPortfolioProvider);
  }

  void _invalidateUnits(String propertyId, String? blockId) {
    if (blockId != null) _ref.invalidate(blockUnitsProvider(blockId));
    _ref.invalidate(availabilityProvider);
    _ref.invalidate(unitListProvider);
    _ref.invalidate(rentRollProvider(propertyId));
    _invalidateProperty(propertyId);
  }
}
