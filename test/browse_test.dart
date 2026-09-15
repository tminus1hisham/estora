import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/property.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/modules/properties/application/property_controller.dart';
import 'package:mall/modules/properties/presentation/properties_screen.dart';
import 'package:mall/services/models/api_mappers.dart';
import 'package:mall/services/providers.dart';

class _Properties extends Mock implements PropertyRepository {
  List<Property> records = [];
  int calls = 0;

  @override
  Future<Result<Page<Property>>> listProperties({
    String? query,
    PropertyType? type,
    int page = 1,
  }) async {
    calls++;
    return Ok(
      Page.single(
        records
            .where(
              (property) =>
                  query == null ||
                  property.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList(),
      ),
    );
  }
}

void main() {
  final property = propertyFromJson({
    'id': 7,
    'propertyName': 'Riverside Court',
    'city': 'Nairobi',
    'country': 'Kenya',
  });

  testWidgets('Browse search does not empty the shared list or a fresh visit', (
    tester,
  ) async {
    final repository = _Properties()..records = [property];
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(repository)],
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
    expect(container.read(propertyListProvider).requireValue, [property]);
    expect(repository.calls, 1);
    visible.value = false;
    await tester.pumpAndSettle();
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Riverside Court'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty API result explains the state and refresh loads new data',
    (tester) async {
      final repository = _Properties();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [propertyRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: PropertiesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No properties available'), findsOneWidget);
      expect(find.text('Try a different search term.'), findsNothing);
      repository.records = [property];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('Riverside Court'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
