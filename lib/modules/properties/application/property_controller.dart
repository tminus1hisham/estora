import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/property.dart';
import '../../../services/providers.dart';

/// Section 77's Properties list.
final propertyListProvider =
    AsyncNotifierProvider<PropertyListController, List<Property>>(
      PropertyListController.new,
      retry: (_, _) => null,
    );

class PropertyListController extends AsyncNotifier<List<Property>> {
  @override
  Future<List<Property>> build() async {
    final result = await ref.read(propertyRepositoryProvider).listProperties();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }
}

/// A single property, with its buildings and floors for the unit filter.
final propertyDetailProvider = FutureProvider.autoDispose
    .family<PropertyDetail, String>((ref, propertyId) async {
      final repository = ref.watch(propertyRepositoryProvider);

      final (propertyResult, buildingsResult) = await (
        repository.getProperty(propertyId),
        repository.listBuildings(propertyId),
      ).wait;
      if (propertyResult case Err(:final failure)) throw failure;

      final buildings = buildingsResult.valueOrNull ?? const <Building>[];

      // Most blocks already carry their floor count. Only incomplete list
      // records need an individual block read.
      final floorLists = await Future.wait(
        buildings.map(
          (b) async => b.numberOfFloors == null
              ? (await repository.listFloors(b.id)).valueOrNull ??
                    const <Floor>[]
              : Floor.fromCount(b.id, b.numberOfFloors!),
        ),
      );

      return PropertyDetail(
        property: propertyResult.value,
        buildings: buildings,
        floorsByBuilding: {
          for (var i = 0; i < buildings.length; i++)
            buildings[i].id: floorLists[i],
        },
      );
    }, retry: (_, _) => null);

class PropertyDetail {
  const PropertyDetail({
    required this.property,
    required this.buildings,
    required this.floorsByBuilding,
  });

  final Property property;
  final List<Building> buildings;
  final Map<String, List<Floor>> floorsByBuilding;

  List<Floor> get allFloors =>
      floorsByBuilding.values.expand((floors) => floors).toList();
}
