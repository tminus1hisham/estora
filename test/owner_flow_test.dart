import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/services/mock/mock_repositories.dart';
import 'package:mall/services/mock/mock_server.dart';

/// Section 88, end to end: an owner registers a property and a tenant can book
/// a unit in it.
///
/// Driven through the repositories rather than the server directly, because the
/// thing worth proving is that the two audiences meet in the middle — the rent
/// a tenant is quoted has to be the one the owner's rate produced, with nobody
/// having typed it.
void main() {
  late MockServer server;
  late OwnerRepository owners;
  late PropertyRepository properties;
  late UnitRepository units;
  late BookingRepository bookings;

  setUp(() {
    server = MockServer();
    owners = MockOwnerRepository(server);
    properties = MockPropertyRepository(server);
    units = MockUnitRepository(server);
    bookings = MockBookingRepository(server);
  });

  const kes = 'KES';
  Money kesOf(num major) => Money.fromMajor(major, kes);

  void signInAsOwner() =>
      server.loginWithPassword('owner@karunaholdings.co.ke', 'a-password');
  void signInAsTenant() =>
      server.loginWithPassword('amina@example.co.ke', 'a-password');

  T unwrap<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('expected Ok, got $failure'),
  };

  test('an owner registers a property and a tenant can book in it', () async {
    signInAsOwner();

    // -- The owner creates a property priced at KES 40/m² ---------------------
    final property = unwrap(
      await owners.createProperty(
        draft: PropertyDraft(
          name: 'Riverside Court',
          propertyType: PropertyType.retailCenter,
          city: 'Nairobi',
          country: 'Kenya',
          totalArea: 12000,
          rentRatePerSqm: kesOf(40),
        ),
        idempotencyKey: 'flow-property',
      ),
    );

    expect(property.rentRatePerSqm, kesOf(40));
    expect(property.rateLabel, 'KES 40 / m²');

    // -- And generates four 2,000 m² units under it ---------------------------
    final made = unwrap(
      await owners.createUnits(
        propertyId: property.id,
        draft: const UnitBatchDraft(
          typeName: 'Retail Bay',
          area: 2000,
          quantity: 4,
          numberPrefix: 'BAY',
          startNumber: 1,
          depositMonths: 3,
          buildingName: 'Riverside',
          floorName: 'Ground Floor',
        ),
        idempotencyKey: 'flow-units',
      ),
    );
    expect(made, 4);

    // -- The tenant browses and finds it --------------------------------------
    signInAsTenant();

    final listed = unwrap(await properties.listProperties());
    final found = listed.items.firstWhere((p) => p.id == property.id);
    expect(found.name, 'Riverside Court');
    // Counts are derived at read time, not stored.
    expect(found.totalUnits, 4);
    expect(found.availableUnits, 4);

    final available = unwrap(
      await units.listUnits(filter: UnitFilter(propertyId: property.id)),
    );
    expect(available.items, hasLength(4));

    for (final unit in available.items) {
      // 2,000 m² × KES 40, and nobody typed 80,000 anywhere.
      expect(unit.baseRent, kesOf(80000));
      expect(unit.ratePerSqm, kesOf(40));
      expect(unit.rateLabel, 'KES 40 / m²');
      expect(unit.locationLabel, contains('Riverside'));
    }

    // -- And the quote agrees with the listing --------------------------------
    final first = available.items.first;
    final quote = unwrap(await bookings.getQuote(first.id));
    expect(quote.monthlyRent, kesOf(80000));
    // Three months' deposit, per the batch.
    expect(quote.depositAmount, kesOf(240000));
  });

  test('a repricing reaches the tenant, an override does not', () async {
    signInAsOwner();

    final property = unwrap(
      await owners.createProperty(
        draft: PropertyDraft(
          name: 'Riverside Court',
          propertyType: PropertyType.retailCenter,
          city: 'Nairobi',
          country: 'Kenya',
          rentRatePerSqm: kesOf(40),
        ),
        idempotencyKey: 'flow-property',
      ),
    );
    await owners.createUnits(
      propertyId: property.id,
      draft: const UnitBatchDraft(
        typeName: 'Retail Bay',
        area: 2000,
        quantity: 2,
        numberPrefix: 'BAY',
      ),
      idempotencyKey: 'flow-units',
    );

    final built = server.units.values
        .where((unit) => unit.propertyId == property.id)
        .toList();
    final pinned = built.first.id;
    final floating = built.last.id;

    // One unit is priced by hand, the other left on the rate.
    await owners.setUnitRent(unitId: pinned, override: kesOf(95000));
    await owners.setRatePerSqm(
      propertyId: property.id,
      rate: kesOf(50),
      repriceExistingUnits: true,
    );

    signInAsTenant();

    expect(unwrap(await units.getUnit(floating)).baseRent, kesOf(100000));
    expect(unwrap(await units.getUnit(pinned)).baseRent, kesOf(95000));
    expect(unwrap(await units.getUnit(pinned)).rentOverridden, isTrue);
  });

  test('an owner cannot touch a property they do not own', () async {
    signInAsOwner();

    // Hand Sarit to somebody else.
    server.properties['prp_sarit']!.ownerId = 'own_someone_else';

    final result = await owners.setRatePerSqm(
      propertyId: 'prp_sarit',
      rate: kesOf(99),
      repriceExistingUnits: true,
    );

    expect(result, isA<Err<dynamic>>());
    // And nothing moved.
    expect(server.units['unt_shop_102']!.baseRent, kesOf(150000));
  });

  test('a tenant is refused the owner endpoints entirely', () async {
    signInAsTenant();

    expect(await owners.getPortfolio(), isA<Err<dynamic>>());
    expect(
      await owners.createProperty(
        draft: PropertyDraft(
          name: 'Not Mine',
          propertyType: PropertyType.mall,
          city: 'Nairobi',
          country: 'Kenya',
          rentRatePerSqm: kesOf(10),
        ),
        idempotencyKey: 'nope',
      ),
      isA<Err<dynamic>>(),
    );
  });
}
