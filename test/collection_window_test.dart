import 'package:flutter_test/flutter_test.dart';
import 'package:mall/domain/entities/owner.dart';

/// How a [CollectionWindow] is drawn, which both fake servers rely on.
///
/// Calendar arithmetic only: the buckets say where the columns fall and what
/// the ticks read, never what goes in them.
void main() {
  final now = DateTime(2026, 9, 16, 14, 30);

  test('three months are bounded to themselves and drawn as themselves', () {
    final bounds = const CollectionWindow.threeMonths().resolve(now);

    expect(bounds.from, DateTime(2026, 7));
    expect(bounds.to, DateTime(2026, 10));
    expect(bounds.buckets.map((b) => b.label), ['Jul', 'Aug', 'Sep']);
    expect(bounds.buckets.every((b) => b.isBillingPeriod), isTrue);
    expect(bounds.buckets.first.name, 'July 2026');
  });

  test('three months step back across a year end', () {
    final bounds = const CollectionWindow.threeMonths().resolve(
      DateTime(2027, 1, 9),
    );

    expect(bounds.from, DateTime(2026, 11));
    expect(bounds.to, DateTime(2027, 2));
    expect(bounds.buckets.map((b) => b.name), [
      'November 2026',
      'December 2026',
      'January 2027',
    ]);
  });

  test('the month is bounded to itself but drawn against the five before', () {
    final bounds = const CollectionWindow.month().resolve(now);

    expect(bounds.from, DateTime(2026, 9));
    expect(bounds.to, DateTime(2026, 10));
    expect(bounds.buckets.map((b) => b.label), [
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
    ]);
    expect(bounds.buckets.every((b) => b.isBillingPeriod), isTrue);
    expect(bounds.buckets.last.name, 'September 2026');
  });

  test('a short custom span is drawn by the day, in either order', () {
    final window = CollectionWindow.custom(
      from: DateTime(2026, 9, 14, 23),
      to: DateTime(2026, 9, 3, 8),
    );
    final bounds = window.resolve(now);

    // Inclusive of both picked days, whole days, oldest first.
    expect(bounds.from, DateTime(2026, 9, 3));
    expect(bounds.to, DateTime(2026, 9, 15));
    expect(bounds.buckets, hasLength(12));
    expect(bounds.buckets.first.name, 'Thu 3 Sep');
    // A tick each week and one on the last day.
    expect(
      bounds.buckets.where((b) => b.label.isNotEmpty).map((b) => b.label),
      ['3 Sep', '10 Sep', '14 Sep'],
    );
  });

  test('a long custom span is drawn by the month with billed alongside', () {
    final window = CollectionWindow.custom(
      from: DateTime(2026, 3, 20),
      to: DateTime(2026, 9, 2),
    );
    final bounds = window.resolve(now);

    expect(bounds.buckets.map((b) => b.label), [
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
    ]);
    expect(bounds.buckets.every((b) => b.isBillingPeriod), isTrue);
  });

  test('windows compare by what they ask for', () {
    expect(const CollectionWindow.month(), const CollectionWindow.month());
    expect(
      CollectionWindow.custom(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 5),
      ),
      CollectionWindow.custom(
        from: DateTime(2026, 9, 5),
        to: DateTime(2026, 9, 1),
      ),
    );
    expect(
      const CollectionWindow.month(),
      isNot(const CollectionWindow.threeMonths()),
    );
  });
}
