import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/services/mock/mock_server.dart';

/// Section 88's owner reporting, asserted against the server rather than
/// through a screen.
///
/// Every figure an owner sees is computed in `MockServer`, so this is where
/// they can be checked without a widget tree in the way. Assertions avoid the
/// figures that move with the calendar — the seed is built relative to today,
/// and a test that only passes between the 6th and the 28th is worse than no
/// test at all. What is asserted instead is either fixed by the seed (unit
/// counts, contracted rent) or a relationship that must hold on any date
/// (net payout is collection less the fee).
void main() {
  late MockServer server;

  setUp(() => server = MockServer());

  const ownerId = 'own_demo';
  const kes = 'KES';

  group('rate-derived pricing (section 88)', () {
    test('a unit takes its rent from the property rate and its area', () {
      // Sarit asks KES 30/m² and a retail unit is 5,000 m².
      final unit = server.units['unt_shop_201']!;
      expect(unit.baseRent, Money.fromMajor(150000, kes));
      expect(unit.ratePerSqm, Money.fromMajor(30, kes));
      expect(unit.rentOverridden, isFalse);
    });

    test('a unit type rate overrides the property rate', () {
      // A kiosk earns more per square metre: 1,000 m² at KES 45.
      final kiosk = server.units['unt_kiosk_k01']!;
      expect(kiosk.ratePerSqm, Money.fromMajor(45, kes));
      expect(kiosk.baseRent, Money.fromMajor(45000, kes));
    });

    test('an overridden rent is flagged as one', () {
      // Priced above the rate, so a repricing must leave it alone.
      final corner = server.units['unt_shop_203']!;
      expect(corner.baseRent, Money.fromMajor(165000, kes));
      expect(corner.rentOverridden, isTrue);

      // And one priced below it.
      final upstairs = server.units['unt_shop_103']!;
      expect(upstairs.baseRent, Money.fromMajor(135000, kes));
      expect(upstairs.rentOverridden, isTrue);
    });

    test('the derivation reproduces the section 80 figure exactly', () {
      // The whole reason KES 30/m² was chosen: the spec's worked example is
      // KES 150,000 and the seeded fixtures depend on it.
      final rate = server.properties['prp_sarit']!.rentRatePerSqm!;
      expect(
        server.rentFor(area: 5000, ratePerSqm: rate),
        Money.fromMajor(150000, kes),
      );
    });
  });

  group('portfolio aggregation', () {
    test('the owner holds both seeded properties', () {
      final portfolio = server.ownerPortfolio(ownerId);
      expect(portfolio.propertyCount, 2);
      expect(
        portfolio.properties.map((p) => p.propertyId),
        containsAll(<String>['prp_sarit', 'prp_abc']),
      );
    });

    test('the unit mix counts every unit exactly once', () {
      final portfolio = server.ownerPortfolio(ownerId);
      final mix = portfolio.mix;

      // Sarit: 5 let, 4 available, 1 under maintenance.
      // ABC:   2 let, 1 available.
      expect(mix.leased, 7);
      expect(mix.available, 5);
      expect(mix.unavailable, 1);
      expect(mix.booked, 0);
      expect(mix.total, 13);

      // And it agrees with the units the server actually holds.
      final owned = server
          .propertiesOwnedBy(ownerId)
          .map((property) => property.id)
          .toSet();
      final count = server.units.values
          .where((unit) => owned.contains(unit.propertyId))
          .length;
      expect(mix.total, count);
    });

    test('occupancy is let units over lettable units', () {
      final portfolio = server.ownerPortfolio(ownerId);
      expect(portfolio.occupancyRate, closeTo(7 / 13, 0.0001));
    });

    test('the rent roll is the sum of the active leases', () {
      final portfolio = server.ownerPortfolio(ownerId);

      // Sarit: 150,000 (SHOP-101) + 150,000 + 150,000 + 165,000 + 150,000
      // ABC:    86,400 (96 m²) + 108,000 (120 m²)
      expect(
        portfolio.monthlyContractedRent,
        Money.fromMajor(959400, kes),
      );
    });

    test('the platform fee is taken per property, not portfolio-wide', () {
      // Sarit charges 2% and ABC 2.5%. A single portfolio-level rate would
      // silently average two different contracts.
      final portfolio = server.ownerPortfolio(ownerId);

      var expected = Money.zero(kes);
      for (final performance in portfolio.properties) {
        final rate = server.configs[performance.propertyId]!.platformFeePercent;
        expected += performance.collectedThisMonth.percentage(rate);
      }

      expect(portfolio.platformFee, expected);
    });

    test('net payout is what was collected less the fee', () {
      final portfolio = server.ownerPortfolio(ownerId);
      expect(
        portfolio.netPayout,
        portfolio.collectedThisMonth - portfolio.platformFee,
      );
    });

    test('portfolio money is the sum of its properties', () {
      final portfolio = server.ownerPortfolio(ownerId);

      var billed = Money.zero(kes);
      var collected = Money.zero(kes);
      var outstanding = Money.zero(kes);
      for (final performance in portfolio.properties) {
        billed += performance.billedThisMonth;
        collected += performance.collectedThisMonth;
        outstanding += performance.outstanding;
      }

      expect(portfolio.billedThisMonth, billed);
      expect(portfolio.collectedThisMonth, collected);
      expect(portfolio.outstanding, outstanding);
    });

    test('money came in this month, but not all of it', () {
      // No threshold on the rate: what this month bills depends on where the
      // calendar puts the seeded deposit and rent invoices, and a test that
      // pins a percentage would fail on some days of the month and not others.
      // The two claims that hold on any date are that collection is happening
      // and that the arrears fixture is still keeping it short of complete.
      final portfolio = server.ownerPortfolio(ownerId);
      expect(portfolio.collectedThisMonth.isPositive, isTrue);
      expect(portfolio.collectionRate, greaterThan(0));
      expect(portfolio.collectionRate, lessThan(1));
      expect(portfolio.overdue.isPositive, isTrue);
    });
  });

  group('collection history', () {
    test('runs six months, oldest first, ending on this month', () {
      final history = server.ownerPortfolio(ownerId).history;
      expect(history, hasLength(6));

      for (var i = 1; i < history.length; i++) {
        expect(
          history[i].month.isAfter(history[i - 1].month),
          isTrue,
          reason: 'history must run oldest first',
        );
      }

      final now = server.now;
      expect(history.last.month.year, now.year);
      expect(history.last.month.month, now.month);
    });

    test('every month has something billed against it', () {
      // The seed gives each tenancy at least six closed months, so a flat or
      // empty history means the history seeding has regressed.
      final history = server.ownerPortfolio(ownerId).history;
      for (final month in history) {
        expect(
          month.billed.isPositive,
          isTrue,
          reason: 'nothing billed in ${month.month}',
        );
      }
    });

    test('every closed month collected something', () {
      // Not asserted as equality with what was billed, because the two
      // legitimately straddle a month boundary: the seeded deposit is invoiced
      // in one month and paid in the next, so that month collects KES 750,000
      // more than it billed. A chart that showed those as always equal would
      // be hiding the very thing it exists to show.
      final history = server.ownerPortfolio(ownerId).history;
      for (final month in history.take(history.length - 1)) {
        expect(
          month.collected.isPositive,
          isTrue,
          reason: 'nothing collected in ${month.month}',
        );
      }
    });
  });

  group('alerts', () {
    test('a tenant behind on rent raises one alert, not one per invoice', () {
      final alerts = server
          .ownerPortfolio(ownerId)
          .alerts
          .where((alert) => alert.type == OwnerAlertType.arrears)
          .toList();

      expect(alerts, isNotEmpty);
      expect(
        alerts.map((alert) => alert.title).toSet(),
        hasLength(alerts.length),
        reason: 'one alert per tenant behind, not per invoice',
      );
      expect(
        alerts.any((alert) => alert.title == 'Tembo Electronics'),
        isTrue,
      );
    });

    test('a lease inside the notice period is surfaced', () {
      final alerts = server
          .ownerPortfolio(ownerId)
          .alerts
          .where((alert) => alert.type == OwnerAlertType.leaseExpiring);

      expect(
        alerts.any((alert) => alert.title == 'Nuru Fashions'),
        isTrue,
        reason: 'the lease ending in 44 days should be flagged',
      );
    });

    test('vacancy is summarised per property, not per empty unit', () {
      final alerts = server
          .ownerPortfolio(ownerId)
          .alerts
          .where((alert) => alert.type == OwnerAlertType.vacancy)
          .toList();

      // Both properties have something available, and neither should produce
      // more than one line however many units are empty.
      expect(alerts, hasLength(2));
      expect(
        alerts.map((alert) => alert.targetId).toSet(),
        containsAll(<String>['prp_sarit', 'prp_abc']),
      );
    });
  });

  group('per-property performance', () {
    test('a property reports its own rate and area', () {
      final sarit = server.propertyPerformance('prp_sarit');
      expect(sarit.rentRatePerSqm, Money.fromMajor(30, kes));
      expect(sarit.rateLabel, 'KES 30 / m²');
      expect(sarit.totalArea, 32000);
      // Five let units at 5,000 m² each.
      expect(sarit.letArea, 25000);
    });

    test('an unknown property is not found rather than empty', () {
      expect(
        () => server.propertyPerformance('prp_nope'),
        throwsA(isA<MockNotFound>()),
      );
    });
  });
}
