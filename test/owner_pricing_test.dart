import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'support/mock/mock_server.dart';

/// Section 88's pricing rules.
///
/// The whole point of pricing by the square metre is that one number moves a
/// building's asking rents at once. The danger in that is obvious: it must not
/// also move what someone has already signed. Section 21 has a booking capture
/// its terms at booking time, section 55 has a lease carry its own rent, and
/// `Unit.baseRent` calls itself a listing price — these tests are what hold the
/// implementation to all three.
void main() {
  late MockServer server;

  setUp(() => server = MockServer());

  const kes = 'KES';
  const ownerId = 'own_demo';
  const saritId = 'prp_sarit';

  Money kesOf(num major) => Money.fromMajor(major, kes);

  group('creating a property', () {
    PropertyDraft draftOf({Money? rate}) => PropertyDraft(
      name: 'Riverside Court',
      propertyType: PropertyType.retailCenter,
      city: 'Nairobi',
      country: 'Kenya',
      rentRatePerSqm: rate ?? kesOf(40),
    );

    test('a property is created against its owner with a config', () {
      final property = server.createProperty(
        ownerId: ownerId,
        draft: draftOf(),
        idempotencyKey: 'create-1',
      );

      expect(property.ownerId, ownerId);
      expect(property.rentRatePerSqm, kesOf(40));
      expect(property.status, PropertyStatus.active);
      // Section 12: without a config the property could not raise an invoice.
      expect(server.configs[property.id], isNotNull);
      expect(server.propertiesOwnedBy(ownerId), contains(property));
    });

    test('replaying the same key creates nothing new', () {
      final before = server.properties.length;

      final first = server.createProperty(
        ownerId: ownerId,
        draft: draftOf(),
        idempotencyKey: 'create-1',
      );
      final second = server.createProperty(
        ownerId: ownerId,
        draft: draftOf(),
        idempotencyKey: 'create-1',
      );

      expect(identical(first, second), isTrue);
      expect(server.properties.length, before + 1);
    });
  });

  group('generating units', () {
    late String propertyId;

    setUp(() {
      propertyId = server
          .createProperty(
            ownerId: ownerId,
            draft: PropertyDraft(
              name: 'Riverside Court',
              propertyType: PropertyType.retailCenter,
              city: 'Nairobi',
              country: 'Kenya',
              rentRatePerSqm: kesOf(40),
            ),
            idempotencyKey: 'create-1',
          )
          .id;
    });

    test('every unit asks area times the property rate', () {
      final made = server.createUnits(
        propertyId: propertyId,
        draft: const UnitBatchDraft(
          typeName: 'Retail Bay',
          area: 2000,
          quantity: 4,
          numberPrefix: 'BAY',
          startNumber: 1,
        ),
        idempotencyKey: 'units-1',
      );

      expect(made, 4);

      final built = server.units.values
          .where((unit) => unit.propertyId == propertyId)
          .toList();
      expect(built, hasLength(4));
      for (final unit in built) {
        // 2,000 m² at KES 40.
        expect(unit.baseRent, kesOf(80000));
        expect(unit.ratePerSqm, kesOf(40));
        expect(unit.rentOverridden, isFalse);
        expect(unit.status, UnitStatus.available);
      }
      expect(
        built.map((unit) => unit.unitNumber),
        containsAll(<String>['BAY-1', 'BAY-2', 'BAY-3', 'BAY-4']),
      );
    });

    test('a batch rate overrides the property rate', () {
      server.createUnits(
        propertyId: propertyId,
        draft: UnitBatchDraft(
          typeName: 'Kiosk',
          area: 500,
          quantity: 2,
          numberPrefix: 'KSK',
          ratePerSqm: kesOf(70),
        ),
        idempotencyKey: 'units-2',
      );

      final kiosks = server.units.values.where(
        (unit) => unit.propertyId == propertyId,
      );
      for (final kiosk in kiosks) {
        // 500 m² at KES 70, not the property's 40.
        expect(kiosk.baseRent, kesOf(35000));
      }
    });

    test('replaying the same key generates nothing further', () {
      const draft = UnitBatchDraft(
        typeName: 'Retail Bay',
        area: 2000,
        quantity: 4,
        numberPrefix: 'BAY',
      );

      server.createUnits(
        propertyId: propertyId,
        draft: draft,
        idempotencyKey: 'units-1',
      );
      server.createUnits(
        propertyId: propertyId,
        draft: draft,
        idempotencyKey: 'units-1',
      );

      expect(
        server.units.values.where((u) => u.propertyId == propertyId),
        hasLength(4),
      );
    });

    test('a property with no rate refuses to generate units', () {
      // Sarit has a rate; a property without one cannot derive anything, and
      // guessing a rent would be worse than refusing.
      server.properties[propertyId]!.rentRatePerSqm = null;

      expect(
        () => server.createUnits(
          propertyId: propertyId,
          draft: const UnitBatchDraft(
            typeName: 'Retail Bay',
            area: 2000,
            quantity: 1,
            numberPrefix: 'BAY',
          ),
          idempotencyKey: 'units-3',
        ),
        throwsA(isA<MockConflict>()),
      );
    });
  });

  group('repricing a property', () {
    test('unlet units take the new rate', () {
      // SHOP-102 is available and priced straight off the rate.
      expect(server.units['unt_shop_102']!.baseRent, kesOf(150000));

      server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(45),
        repriceExistingUnits: true,
      );

      // 5,000 m² at the new KES 45.
      expect(server.units['unt_shop_102']!.baseRent, kesOf(225000));
      expect(server.units['unt_shop_102']!.ratePerSqm, kesOf(45));
    });

    test('an overridden rent is left alone', () {
      // SHOP-103 was deliberately priced below the rate.
      expect(server.units['unt_shop_103']!.rentOverridden, isTrue);

      server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(45),
        repriceExistingUnits: true,
      );

      expect(server.units['unt_shop_103']!.baseRent, kesOf(135000));
    });

    test('a unit on its own type rate is left alone', () {
      // The kiosk asks KES 45/m² through its type, not the property's rate.
      server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(60),
        repriceExistingUnits: true,
      );

      expect(server.units['unt_kiosk_k01']!.baseRent, kesOf(45000));
    });

    test('a repricing never moves rent on a signed lease', () {
      // The rule this whole milestone turns on. SHOP-201 is let to Bahari
      // Coffee at KES 150,000 under lse_shop_201.
      final lease = server.leases['lse_shop_201']!;
      expect(lease.monthlyRent, kesOf(150000));
      expect(lease.status.isCurrent, isTrue);

      server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(90),
        repriceExistingUnits: true,
      );

      // The agreement is untouched...
      expect(lease.monthlyRent, kesOf(150000));
      // ...and so is the let unit's listing price, which takes the new rate
      // when it next comes free rather than retroactively.
      expect(server.units['unt_shop_201']!.baseRent, kesOf(150000));
    });

    test('without repricing, only the asking rate moves', () {
      final before = server.units['unt_shop_102']!.baseRent;

      final result = server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(45),
        repriceExistingUnits: false,
      );

      expect(result.property.rentRatePerSqm, kesOf(45));
      expect(result.repriced, 0);
      expect(server.units['unt_shop_102']!.baseRent, before);
    });

    test('the count returned matches what was actually moved', () {
      final impact = server.repricingImpact(saritId);
      final result = server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(45),
        repriceExistingUnits: true,
      );

      // The preview the confirmation shows must equal what happens, or the
      // owner is agreeing to one thing and getting another.
      expect(result.repriced, impact.repriceable);
      expect(impact.overridden, greaterThan(0));
      expect(impact.let, greaterThan(0));
    });
  });

  group('pricing one unit by hand', () {
    test('an override sticks and is flagged', () {
      server.setUnitRent(unitId: 'unt_shop_102', override: kesOf(175000));

      final unit = server.units['unt_shop_102']!;
      expect(unit.baseRent, kesOf(175000));
      expect(unit.rentOverridden, isTrue);

      // And it now survives a repricing.
      server.setRatePerSqm(
        propertyId: saritId,
        rate: kesOf(45),
        repriceExistingUnits: true,
      );
      expect(unit.baseRent, kesOf(175000));
    });

    test('clearing an override puts the unit back on the rate', () {
      // SHOP-103 sits at KES 135,000 against a derived KES 150,000.
      server.setUnitRent(unitId: 'unt_shop_103');

      final unit = server.units['unt_shop_103']!;
      expect(unit.rentOverridden, isFalse);
      expect(unit.baseRent, kesOf(150000));
    });

    test('an unknown unit is not found rather than silently ignored', () {
      expect(
        () => server.setUnitRent(unitId: 'unt_nope', override: kesOf(1)),
        throwsA(isA<MockNotFound>()),
      );
    });
  });
}
