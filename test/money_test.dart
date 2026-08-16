import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/utils/money.dart';

/// Money is the foundation every financial figure in the app sits on, so it is
/// tested first. Section 84 governs financial data; the reason `Money` holds
/// integer minor units rather than a `double` is that binary floating point
/// cannot represent decimal currency exactly, and the tests below are what
/// stops that assumption quietly regressing.
void main() {
  group('Money parsing and formatting', () {
    test('parses a whole major-unit number', () {
      final money = Money.fromMajor(150000, 'KES');
      expect(money.minorUnits, 15000000);
      expect(money.format(), 'KES 150,000');
    });

    test('formats the section 80 figures exactly as the spec writes them', () {
      expect(Money.fromMajor(150000, 'KES').format(), 'KES 150,000');
      expect(Money.fromMajor(750000, 'KES').format(), 'KES 750,000');
      expect(Money.fromMajor(20000, 'KES').format(), 'KES 20,000');
    });

    test('keeps decimals only when there are any', () {
      expect(Money.fromMajor(1500.5, 'KES').format(), 'KES 1,500.50');
      expect(Money.fromMajor(1500, 'KES').format(), 'KES 1,500');
    });

    test('parses a JSON number or a decimal string identically', () {
      expect(Money.fromJson(150000, 'KES'), Money.fromJson('150000', 'KES'));
      expect(Money.fromJson(1500.75, 'KES'), Money.fromJson('1500.75', 'KES'));
    });

    test(
      'a missing or unparseable amount becomes zero rather than throwing',
      () {
        expect(Money.fromJson(null, 'KES').isZero, isTrue);
        expect(Money.fromJson('not a number', 'KES').isZero, isTrue);
      },
    );

    test('round-trips through JSON without drift', () {
      final original = Money.fromMajor(150000, 'KES');
      expect(Money.fromJson(original.toJson(), 'KES'), original);
    });
  });

  group('Money arithmetic', () {
    test('adding a tenth of a unit a hundred times lands exactly', () {
      // The case a double gets wrong: 0.1 summed 100 times is 9.99999... in
      // binary floating point.
      var total = Money.zero('KES');
      for (var i = 0; i < 100; i++) {
        total += Money.fromMajor(0.1, 'KES');
      }
      expect(total, Money.fromMajor(10, 'KES'));
      expect(total.minorUnits, 1000);
    });

    test('deposit is months times rent (section 25)', () {
      final rent = Money.fromMajor(150000, 'KES');
      expect(rent * 5, Money.fromMajor(750000, 'KES'));
    });

    test('percentage computes the section 41 platform fee', () {
      final payment = Money.fromMajor(150000, 'KES');
      expect(payment.percentage(2), Money.fromMajor(3000, 'KES'));
    });

    test('percentage rounds to the nearest minor unit', () {
      // 16% VAT on 20,000 is 3,200 exactly; a rate producing a fraction of a
      // cent must land on a whole one rather than carrying a float.
      expect(
        Money.fromMajor(20000, 'KES').percentage(16),
        Money.fromMajor(3200, 'KES'),
      );
      expect(
        Money.fromMajor(0.01, 'KES').percentage(50).minorUnits,
        1, // 0.005 rounds away from zero
      );
    });

    test('scaledBy derives a rent from a rate per square metre', () {
      // The seeded case: Sarit asks KES 30/m² and a retail unit is 5,000 m²,
      // which must land exactly on the KES 150,000 the fixtures already use.
      final rate = Money.fromMajor(30, 'KES');
      expect(rate.scaledBy(5000), Money.fromMajor(150000, 'KES'));
    });

    test('scaledBy carries a fractional area and rounds once', () {
      // 1,250.5 m² at KES 22.50 is 28,136.25 — the quarter cent has to round
      // onto a whole minor unit rather than sitting on a float boundary.
      final rate = Money.fromMajor(22.50, 'KES');
      expect(rate.scaledBy(1250.5).minorUnits, 2813625);
      expect(rate.scaledBy(1250.5).format(), 'KES 28,136.25');
    });

    test('scaledBy rounds away from zero on a half minor unit', () {
      expect(Money.fromMajor(0.01, 'KES').scaledBy(0.5).minorUnits, 1);
    });

    test('scaledBy by a whole number agrees with operator *', () {
      final rent = Money.fromMajor(150000, 'KES');
      expect(rent.scaledBy(5), rent * 5);
    });

    test('subtraction and comparison behave', () {
      final total = Money.fromMajor(150000, 'KES');
      final paid = Money.fromMajor(50000, 'KES');
      expect(total - paid, Money.fromMajor(100000, 'KES'));
      expect(total > paid, isTrue);
      expect((total - total).isZero, isTrue);
    });

    test('equality is by amount and currency together', () {
      expect(Money.fromMajor(100, 'KES'), isNot(Money.fromMajor(100, 'USD')));
      expect(Money.fromMajor(100, 'KES'), Money.fromMajor(100, 'KES'));
    });
  });
}
