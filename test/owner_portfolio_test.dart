import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/owner.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'support/mock/mock_server.dart';

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

  Money kesOf(num major) => Money.fromMajor(major, kes);

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
      expect(portfolio.monthlyContractedRent, Money.fromMajor(959400, kes));
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
      expect(alerts.any((alert) => alert.title == 'Tembo Electronics'), isTrue);
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

  group('rent roll', () {
    test('lists every unit in the property, in number order', () {
      final roll = server.rentRoll('prp_sarit');

      expect(roll, hasLength(10));
      final numbers = roll.map((entry) => entry.unitNumber).toList();
      expect(numbers, orderedEquals(List.of(numbers)..sort()));
    });

    test('a let unit names its occupant and its lease', () {
      final entry = server
          .rentRoll('prp_sarit')
          .firstWhere((entry) => entry.unitNumber == 'SHOP-201');

      expect(entry.isLet, isTrue);
      expect(entry.tenantName, 'Bahari Coffee');
      expect(entry.leaseId, 'lse_shop_201');
      expect(entry.leaseEndDate, isNotNull);
    });

    test('an empty unit has no occupant and no outstanding', () {
      final entry = server
          .rentRoll('prp_sarit')
          .firstWhere((entry) => entry.unitNumber == 'SHOP-102');

      expect(entry.isLet, isFalse);
      expect(entry.tenantName, isNull);
      expect(entry.outstanding, isNull);
    });

    test('an overridden rent says so on the line', () {
      final entry = server
          .rentRoll('prp_sarit')
          .firstWhere((entry) => entry.unitNumber == 'SHOP-103');

      expect(entry.rentOverridden, isTrue);
      expect(entry.rateLabel, contains('overridden'));
    });

    test('a rent taken from the rate just states the rate', () {
      final entry = server
          .rentRoll('prp_sarit')
          .firstWhere((entry) => entry.unitNumber == 'SHOP-102');

      expect(entry.rateLabel, 'KES 30 / m²');
    });

    test('the demo tenant is named even though they are not in tenants', () {
      // The signed-in tenant lives on currentTenant, not in the tenants map;
      // a rent roll that showed "Tenant" for the one account the app ships
      // with would look broken.
      server.loginWithPassword('amina@example.co.ke', 'x');
      final entry = server
          .rentRoll('prp_sarit')
          .firstWhere((entry) => entry.unitNumber == 'SHOP-101');

      expect(entry.tenantName, 'Wanjiru Retail Ltd');
    });
  });

  group('tenancies', () {
    test('covers every lease across the owner\'s properties', () {
      final tenancies = server.tenanciesFor(ownerId);

      expect(
        tenancies.map((t) => t.tenantName),
        containsAll(<String>[
          'Bahari Coffee',
          'Tembo Electronics',
          'Nuru Fashions',
          'Sifa Legal',
        ]),
      );
    });

    test('scopes to one property when asked', () {
      final abc = server.tenanciesFor(ownerId, propertyId: 'prp_abc');

      expect(abc, isNotEmpty);
      for (final tenancy in abc) {
        expect(tenancy.propertyId, 'prp_abc');
      }
    });

    test('the tenant in arrears carries an overdue figure', () {
      final tembo = server
          .tenanciesFor(ownerId)
          .firstWhere((t) => t.tenantName == 'Tembo Electronics');

      expect(tembo.isInArrears, isTrue);
      expect(tembo.overdue.isPositive, isTrue);
      expect(tembo.outstanding >= tembo.overdue, isTrue);
    });

    test('the expiring lease is flagged as expiring', () {
      final nuru = server
          .tenanciesFor(ownerId)
          .firstWhere((t) => t.tenantName == 'Nuru Fashions');

      expect(nuru.isExpiringSoon, isTrue);
      expect(nuru.daysUntilExpiry, lessThanOrEqualTo(60));
    });

    test('rent is the one on the lease, not the unit\'s asking price', () {
      // Section 55. Move the rate hard and the tenancy must not follow.
      server.setRatePerSqm(
        propertyId: 'prp_sarit',
        rate: kesOf(90),
        repriceExistingUnits: true,
      );

      final bahari = server
          .tenanciesFor(ownerId)
          .firstWhere((t) => t.tenantName == 'Bahari Coffee');

      expect(bahari.monthlyRent, kesOf(150000));
    });

    test('a lease belonging to somebody else is not found', () {
      expect(
        () => server.tenancy('own_someone_else', 'lse_shop_201'),
        throwsA(isA<MockNotFound>()),
      );
    });

    test('term progress runs between zero and one', () {
      for (final tenancy in server.tenanciesFor(ownerId)) {
        expect(tenancy.termProgress, inInclusiveRange(0, 1));
      }
    });
  });

  group('collections over a window', () {
    test('the month agrees with the ledger', () {
      final ledger = server.ownerLedger(ownerId);
      final series = server.ownerCollections(
        ownerId,
        const CollectionWindow.month(),
      );

      expect(series.collected, ledger.collectedThisMonth);
      expect(series.platformFee, ledger.platformFeeThisMonth);
      expect(series.net, ledger.netThisMonth);
      expect(series.points.last.collected, ledger.history.last.collected);
      expect(series.points.last.billed, ledger.history.last.billed);
    });

    test('three months are bucketed by the month and totalled once', () {
      final series = server.ownerCollections(
        ownerId,
        const CollectionWindow.threeMonths(),
      );

      expect(series.points, hasLength(3));
      expect(series.points.every((point) => point.billed != null), isTrue);
      expect(
        series.collected,
        series.points.fold(
          Money.zero(series.collected.currency),
          (sum, point) => sum + point.collected,
        ),
      );
      expect(series.net, series.collected - series.platformFee);
    });

    test('someone else’s owner sees none of it', () {
      final theirs = server.ownerCollections(
        'own_someone_else',
        const CollectionWindow.month(),
      );
      expect(theirs.collected.isZero, isTrue);
      expect(theirs.paymentCount, 0);
    });
  });

  group('ledger and payouts', () {
    test('a payout is what came in less the platform fee', () {
      final ledger = server.ownerLedger(ownerId);

      for (final payout in ledger.payouts) {
        expect(payout.net, payout.grossCollected - payout.platformFee);
      }
    });

    test('the fee is read off the ledger, not recomputed', () {
      // MockServer writes the platform's cut as its own OUT entry on every
      // settlement. This checks the screen figure equals that record rather
      // than a second calculation that could drift from it.
      final ledger = server.ownerLedger(ownerId);
      final owned = server
          .propertiesOwnedBy(ownerId)
          .map((property) => property.id)
          .toSet();

      final recorded = server.ledger
          .where(
            (entry) =>
                entry.direction == 'OUT' &&
                owned.contains(server.payments[entry.referenceId]?.propertyId),
          )
          .fold(Money.zero(kes), (sum, entry) => sum + entry.amount);

      final fromPayouts = ledger.payouts.fold(
        Money.zero(kes),
        (sum, payout) => sum + payout.platformFee,
      );

      // The payout window is six months; anything older is outside it.
      expect(fromPayouts <= recorded, isTrue);
      expect(fromPayouts.isPositive, isTrue);
    });

    test('a seeded settlement leaves the same trail as a live one', () {
      // Without this the payout history would be empty for everything that
      // happened before the app was opened.
      expect(server.ledger, isNotEmpty);
      expect(
        server.ledger.any((entry) => entry.transactionType == 'RENT'),
        isTrue,
      );
      expect(
        server.ledger.any((entry) => entry.transactionType == 'SERVICE_FEE'),
        isTrue,
      );
    });

    test('ledger entries are dated when the money moved', () {
      // Not when the seed ran, or six months of payouts would pile into this
      // month.
      final months = server.ledger
          .map((entry) => DateTime(entry.createdAt.year, entry.createdAt.month))
          .toSet();
      expect(months.length, greaterThan(1));
    });

    test('the ageing bands account for everything outstanding', () {
      final ledger = server.ownerLedger(ownerId);

      final banded = ledger.ageing.fold(
        Money.zero(kes),
        (sum, bucket) => sum + bucket.amount,
      );
      expect(banded, ledger.totalOutstanding);
    });

    test('the arrears tenant lands in an overdue band, not "not yet due"', () {
      final ledger = server.ownerLedger(ownerId);
      final overdueBands = ledger.ageing.where(
        (bucket) => bucket.label != 'Not yet due',
      );

      expect(overdueBands.any((bucket) => !bucket.isEmpty), isTrue);
    });

    test('collections are newest first and name their payer', () {
      final ledger = server.ownerLedger(ownerId);

      expect(ledger.collections, isNotEmpty);
      for (var i = 1; i < ledger.collections.length; i++) {
        expect(
          ledger.collections[i].paidAt.isAfter(
            ledger.collections[i - 1].paidAt,
          ),
          isFalse,
        );
      }
      for (final collection in ledger.collections) {
        expect(collection.tenantName, isNot('Tenant'));
        expect(collection.amount.isPositive, isTrue);
      }
    });

    test('this month agrees with the last payout row', () {
      final ledger = server.ownerLedger(ownerId);
      final latest = ledger.payouts.last;

      expect(ledger.collectedThisMonth, latest.grossCollected);
      expect(ledger.platformFeeThisMonth, latest.platformFee);
      expect(ledger.netThisMonth, latest.net);
    });

    test('another owner sees none of it', () {
      final theirs = server.ownerLedger('own_someone_else');

      expect(theirs.collections, isEmpty);
      expect(theirs.totalOutstanding.isZero, isTrue);
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
