import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/unit.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/modules/properties/presentation/properties_screen.dart';
import 'package:mall/modules/units/application/unit_controller.dart';
import 'package:mall/modules/units/presentation/property_spaces_screen.dart';
import 'package:mall/services/models/api_mappers.dart';
import 'package:mall/services/providers.dart';

/// Stands in for `GET /properties/available/units/to/book` — the one call
/// the Browse tab makes.
class _Units extends Mock implements UnitRepository {
  List<UnitAvailability> records = [];
  int calls = 0;

  @override
  Future<Result<List<UnitAvailability>>> listAvailability() async {
    calls++;
    return Ok(records);
  }
}

void main() {
  // The live route's answer, verbatim.
  final northWing = unitAvailabilityFromJson({
    'propertyId': 2,
    'propertyName': 'Grace Mall',
    'blockId': 2,
    'blockName': 'North Wing',
    'availableUnitsGroupedBySize': [
      {'size': 480, 'count': 10},
    ],
  });
  final southWing = unitAvailabilityFromJson({
    'propertyId': 2,
    'propertyName': 'Grace Mall',
    'blockId': 3,
    'blockName': 'South Wing',
    'availableUnitsGroupedBySize': [
      {'size': 300, 'count': 2},
      {'size': 620.5, 'count': 1},
    ],
  });
  final riverside = unitAvailabilityFromJson({
    'propertyId': 7,
    'propertyName': 'Riverside Court',
    'blockId': 9,
    'blockName': 'Main',
    'availableUnitsGroupedBySize': [
      {'size': 200, 'count': 4},
    ],
  });

  Widget app(_Units repository) => ProviderScope(
    overrides: [unitRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: PropertiesScreen()),
  );

  testWidgets('Browse lists the engine\'s answer, grouped by property', (
    tester,
  ) async {
    final repository = _Units()..records = [northWing, southWing, riverside];
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Grace Mall'), findsOneWidget);
    expect(find.text('13 available'), findsOneWidget);
    expect(find.text('North Wing'), findsOneWidget);
    expect(find.text('480 sq ft × 10'), findsOneWidget);
    expect(find.text('South Wing'), findsOneWidget);
    expect(find.text('300 sq ft × 2, 620.5 sq ft × 1'), findsOneWidget);
    expect(find.text('Riverside Court'), findsOneWidget);
    expect(find.text('4 available'), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Browse search does not empty the shared list or a fresh visit', (
    tester,
  ) async {
    final repository = _Units()..records = [riverside];
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: visible,
            builder: (_, show, _) =>
                show ? const PropertiesScreen() : const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PropertiesScreen)),
    );
    await tester.enterText(find.byType(TextField), 'No match');
    await tester.pumpAndSettle();
    expect(find.text('No matching properties'), findsOneWidget);
    expect(container.read(availabilityProvider).requireValue, [riverside]);
    expect(repository.calls, 1);
    visible.value = false;
    await tester.pumpAndSettle();
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Riverside Court'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "a property's spaces come off the same engine answer, block by size",
    (tester) async {
      final repository = _Units()..records = [northWing, southWing, riverside];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [unitRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: PropertySpacesScreen(propertyId: '2')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grace Mall'), findsWidgets);
      expect(find.text('NORTH WING'), findsOneWidget);
      expect(find.text('480 sq ft'), findsOneWidget);
      expect(find.text('10 units left'), findsOneWidget);
      expect(find.text('SOUTH WING'), findsOneWidget);
      expect(find.text('300 sq ft'), findsOneWidget);
      expect(find.text('620.5 sq ft'), findsOneWidget);
      expect(find.text('1 unit left'), findsOneWidget);
      // Riverside is another property.
      expect(find.text('MAIN'), findsNothing);
      // One route, once. No unit records were asked for.
      expect(repository.calls, 1);
      expect(find.widgetWithText(FilledButton, 'Book'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a property the engine no longer names has nothing to book', (
    tester,
  ) async {
    final repository = _Units()..records = [riverside];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PropertySpacesScreen(propertyId: '2')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing left to book here'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Book'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty API result explains the state and refresh loads new data',
    (tester) async {
      final repository = _Units();
      await tester.pumpWidget(app(repository));
      await tester.pumpAndSettle();
      expect(find.text('No spaces available'), findsOneWidget);
      expect(find.text('Try a different search term.'), findsNothing);
      repository.records = [riverside];
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('Riverside Court'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
