import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/property.dart';
import '../../../services/providers.dart';

/// Section 77's Properties list.
final propertyListProvider =
    AsyncNotifierProvider<PropertyListController, List<Property>>(
      PropertyListController.new,
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
    state = await AsyncValue.guard(build);
  }
}

/// A single property, with its buildings and floors for the unit filter.
final propertyDetailProvider = FutureProvider.family<PropertyDetail, String>((
  ref,
  propertyId,
) async {
  final repository = ref.watch(propertyRepositoryProvider);

  final propertyResult = await repository.getProperty(propertyId);
  if (propertyResult case Err(:final failure)) throw failure;

  final buildingsResult = await repository.listBuildings(propertyId);
  final buildings = buildingsResult.valueOrNull ?? const <Building>[];

  // Floors hang off buildings, so they need one call each. Fetched in parallel
  // rather than in sequence, since a mall can have several wings.
  final floorLists = await Future.wait(
    buildings.map((b) => repository.listFloors(b.id)),
  );

  return PropertyDetail(
    property: propertyResult.value,
    buildings: buildings,
    floorsByBuilding: {
      for (var i = 0; i < buildings.length; i++)
        buildings[i].id: floorLists[i].valueOrNull ?? const <Floor>[],
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
