import 'package:intl/intl.dart';

/// A currency amount held in **minor units** as an [int].
///
/// Section 84 governs financial data. Binary floating point cannot represent
/// decimal currency exactly, so `double` is never used for money anywhere in
/// this app. All arithmetic happens on whole minor units (cents), and parsing
/// and formatting are centralised here.
///
/// The client never *computes* a payable amount (section 65) — the server does.
/// [Money] exists to carry and display server-supplied amounts faithfully, and
/// for the mock data source to model server-side arithmetic in one place.
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  /// Zero in [currency].
  const Money.zero(this.currency) : minorUnits = 0;

  /// Builds from a major-unit value, e.g. `Money.fromMajor(150000, 'KES')`.
  ///
  /// Rounds half-away-from-zero so 0.005 becomes 0.01 rather than sitting on a
  /// float boundary.
  factory Money.fromMajor(num major, String currency) =>
      Money((major * _factor).round(), currency);

  /// Parses a JSON amount. The API may send a number or a decimal string; both
  /// are handled, and both go through the same rounding path.
  factory Money.fromJson(Object? json, String currency) {
    if (json == null) return Money.zero(currency);
    if (json is num) return Money.fromMajor(json, currency);
    final parsed = num.tryParse(json.toString());
    if (parsed == null) return Money.zero(currency);
    return Money.fromMajor(parsed, currency);
  }

  final int minorUnits;
  final String currency;

  /// Every currency this platform handles uses two decimal places. If a
  /// zero-decimal currency is ever added, this becomes a per-currency lookup
  /// and every call site keeps working because the arithmetic already runs on
  /// minor units.
  static const int _decimals = 2;
  static const int _factor = 100;

  /// The major-unit value, for display and for serialisation only.
  double get majorUnits => minorUnits / _factor;

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  /// Scales by a whole number, e.g. rent times deposit months (section 25).
  Money operator *(int multiplier) => Money(minorUnits * multiplier, currency);

  Money operator -() => Money(-minorUnits, currency);

  /// Applies a percentage rate, e.g. the 2% platform fee in section 41 or a VAT
  /// rate from section 57. Rounds to the nearest minor unit.
  Money percentage(num rate) => Money((minorUnits * rate / 100).round(), currency);

  /// Scales by a fractional factor, e.g. a rate per square metre times an area.
  ///
  /// [operator *] only takes an `int` because the cases it was written for —
  /// rent times deposit months — are whole. An area is not: a 1,250.5 m² unit
  /// at a rate per square metre needs the fraction carried through the
  /// multiplication and rounded once, at the end, onto a whole minor unit.
  ///
  /// Server arithmetic only. Section 65 keeps the client out of computing
  /// payable amounts, so the only caller in this app is the mock server's
  /// pricing helper; a screen that wants a rent asks for one.
  Money scaledBy(num factor) => Money((minorUnits * factor).round(), currency);

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Cannot combine $currency with ${other.currency}. '
      'Multi-currency arithmetic needs an explicit conversion.',
    );
  }

  /// `KES 150,000` — the trailing `.00` is dropped when the amount is whole,
  /// matching how the spec writes amounts throughout.
  String format() {
    final hasFraction = minorUnits % _factor != 0;
    return NumberFormat.currency(
      symbol: '$currency ',
      decimalDigits: hasFraction ? _decimals : 0,
    ).format(majorUnits);
  }

  /// `150,000` — no currency code, for tables and line items where the currency
  /// is already stated in a header.
  String formatBare() {
    final hasFraction = minorUnits % _factor != 0;
    return NumberFormat.decimalPatternDigits(
      decimalDigits: hasFraction ? _decimals : 0,
    ).format(majorUnits);
  }

  /// `KES 150K` / `KES 1.2M`, for dashboard tiles where space is tight.
  String formatCompact() {
    return '$currency ${NumberFormat.compact().format(majorUnits)}';
  }

  /// Serialises back to a major-unit number for the API.
  num toJson() => minorUnits % _factor == 0 ? minorUnits ~/ _factor : majorUnits;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => format();
}
