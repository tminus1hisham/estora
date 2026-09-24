import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:estora/core/error/failure.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/domain/entities/property.dart';
import 'package:estora/domain/entities/unit.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/domain/repositories/repositories.dart';
import 'package:estora/modules/home/presentation/available_home.dart';
import 'package:estora/modules/owner/presentation/owner_live_dashboard.dart';
import 'package:estora/services/providers.dart';

class _Units extends Mock implements UnitRepository {}

Property property(String id) => Property(
  id: id,
  name: id,
  code: '',
  propertyType: PropertyType.estora,
  status: PropertyStatus.active,
  city: 'Nairobi',
  country: 'Kenya',
);

UnitAvailability block(String propertyId, String blockId, int count) =>
    UnitAvailability(
      propertyId: propertyId,
      propertyName: propertyId,
      blockId: blockId,
      blockName: blockId,
      bySize: [UnitAvailabilitySize(size: 100, count: count)],
    );

void main() {
  late _Units repository;
  ProviderContainer container(List<Property> properties) {
    final result = ProviderContainer(
      overrides: [
        homePropertiesProvider.overrideWith((ref) async => properties),
        unitRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() => repository = _Units());

  test('counts each owned block and excludes other owners', () async {
    when(() => repository.listAvailability()).thenAnswer(
      (_) async => Ok([
        block('1', 'a', 3),
        block('1', 'b', 2),
        block('2', 'c', 4),
        block('other', 'd', 100),
      ]),
    );
    final scope = container([property('1'), property('2'), property('3')]);
    expect(await scope.read(ownerDashboardAvailabilityProvider.future), {
      '1': 5,
      '2': 4,
      '3': 0,
    });
  });

  test(
    'an empty portfolio has zero spaces without a platform request',
    () async {
      expect(
        await container([]).read(ownerDashboardAvailabilityProvider.future),
        isEmpty,
      );
      verifyNever(() => repository.listAvailability());
    },
  );

  test(
    'failed availability is not presented as zero and can be retried',
    () async {
      when(
        () => repository.listAvailability(),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final scope = container([property('1')]);
      await expectLater(
        scope.read(ownerDashboardAvailabilityProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      when(
        () => repository.listAvailability(),
      ).thenAnswer((_) async => Ok([block('1', 'a', 6)]));
      expect(await scope.refresh(ownerDashboardAvailabilityProvider.future), {
        '1': 6,
      });
    },
  );
}
