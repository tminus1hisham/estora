import 'package:intl/intl.dart';

import '../../../core/theme/status_palette.dart';
import '../../../core/utils/money.dart';

/// The two services a tenant is metered for.
///
/// Deliberately a closed set. Service charge, refuse and internet are billed on
/// the lease rather than read off a meter, so they belong on an invoice and not
/// here — a screen about meters should only show things that have one.
enum UtilityKind {
  water,
  electricity;

  String get label => switch (this) {
    UtilityKind.water => 'Water',
    UtilityKind.electricity => 'Electricity',
  };

  /// The unit the meter counts in, shown beside every quantity so a figure is
  /// never ambiguous between the two services.
  String get unit => switch (this) {
    UtilityKind.water => 'm³',
    UtilityKind.electricity => 'kWh',
  };

  /// The path segment this utility is addressed by.
  String get slug => switch (this) {
    UtilityKind.water => 'water',
    UtilityKind.electricity => 'electricity',
  };

  /// Reads a path segment back into a kind.
  ///
  /// Tolerant on purpose: a deep link, a stale bookmark or a hand-typed URL is
  /// not worth a crash or an error page on a screen this small. Anything that
  /// is not recognisably electricity opens water, which is the first card on
  /// the list the tenant came from.
  static UtilityKind fromSlug(String? slug) =>
      switch (slug?.trim().toLowerCase()) {
        'electricity' => UtilityKind.electricity,
        _ => UtilityKind.water,
      };

  /// `1,044 kWh` / `42.0 m³`.
  ///
  /// Water is read to a decimal because a cubic metre is a large step and the
  /// fraction is most of a month's difference; a kilowatt hour is small enough
  /// that the decimal would be noise.
  String formatQuantity(double value) {
    final digits = this == UtilityKind.water ? 1 : 0;
    return '${NumberFormat.decimalPatternDigits(decimalDigits: digits).format(value)} $unit';
  }
}

/// Where a utility bill stands.
enum UtilityBillStatus {
  paid,
  due,
  overdue;

  String get label => switch (this) {
    UtilityBillStatus.paid => 'Paid',
    UtilityBillStatus.due => 'Due',
    UtilityBillStatus.overdue => 'Overdue',
  };

  /// The domain decides its own tone and the palette decides what a tone looks
  /// like, the same way every other status in the app is styled.
  StatusTone get tone => switch (this) {
    UtilityBillStatus.paid => StatusTone.positive,
    UtilityBillStatus.due => StatusTone.warning,
    UtilityBillStatus.overdue => StatusTone.danger,
  };

  bool get isSettled => this == UtilityBillStatus.paid;
}

/// One month of metered use, with what it cost.
class UtilityReading {
  const UtilityReading({
    required this.period,
    required this.consumption,
    required this.cost,
  });

  /// The month this covers, held as its first day so two periods compare
  /// cleanly without any time-of-day creeping in.
  final DateTime period;

  /// Units used in [period], in the kind's own unit.
  final double consumption;

  final Money cost;
}

/// A bill raised against one meter.
class UtilityBill {
  const UtilityBill({
    required this.reference,
    required this.kind,
    required this.issuedOn,
    required this.dueOn,
    required this.amount,
    required this.status,
  });

  final String reference;
  final UtilityKind kind;
  final DateTime issuedOn;
  final DateTime dueOn;
  final Money amount;
  final UtilityBillStatus status;

  /// The month the bill covers. A bill is issued on the first of the month it
  /// bills for, so the issue date is the period.
  DateTime get period => DateTime(issuedOn.year, issuedOn.month);

  UtilityBill copyWith({UtilityBillStatus? status}) => UtilityBill(
    reference: reference,
    kind: kind,
    issuedOn: issuedOn,
    dueOn: dueOn,
    amount: amount,
    status: status ?? this.status,
  );
}

/// Everything known about one meter.
class UtilityAccount {
  const UtilityAccount({
    required this.kind,
    required this.meterNumber,
    required this.supplier,
    required this.latestReading,
    required this.previousReading,
    required this.readingDate,
    required this.amountDue,
    required this.status,
    required this.readings,
    required this.bills,
  });

  final UtilityKind kind;
  final String meterNumber;
  final String supplier;

  /// Cumulative figures off the dial, not a month's use.
  ///
  /// [previousReading] is where the dial stood when the current billing month
  /// opened, so [consumption] — the difference — is the month's use so far and
  /// grows each time a tenant submits a fresh reading, rather than resetting to
  /// the gap between the last two readings.
  final double latestReading;
  final double previousReading;

  final DateTime readingDate;

  /// Everything outstanding on this meter, settled or not.
  final Money amountDue;
  final UtilityBillStatus status;

  /// Oldest month first, so the history reads left to right and the last entry
  /// is always the month in progress.
  final List<UtilityReading> readings;

  /// Newest bill first — a tenant opening this screen is looking for the one
  /// they have not paid.
  final List<UtilityBill> bills;

  /// This month's use, taken from the two dial readings rather than the
  /// history, because a reading the tenant has just submitted moves the dial
  /// before anything has re-billed.
  double get consumption {
    final used = latestReading - previousReading;
    return used < 0 ? 0 : used;
  }

  /// Last month's use, for the comparison the card makes.
  double get previousConsumption =>
      readings.length < 2 ? 0 : readings[readings.length - 2].consumption;

  /// How this month sits against last, as a 0–1 fraction of whichever is
  /// larger. Both meters are drawn on the same scale so the shorter bar is
  /// always the smaller month, whichever way round they fall.
  double get consumptionRatio {
    final peak = consumption > previousConsumption
        ? consumption
        : previousConsumption;
    if (peak <= 0) return 0;
    return consumption / peak;
  }

  /// Signed change against last month, as a fraction. Null when there is no
  /// previous month to compare against rather than a misleading zero.
  double? get consumptionChange {
    if (previousConsumption <= 0) return null;
    return (consumption - previousConsumption) / previousConsumption;
  }

  /// The tallest month in [readings], which the history bars are scaled to.
  double get peakConsumption => readings.fold<double>(
    0,
    (peak, reading) => reading.consumption > peak ? reading.consumption : peak,
  );

  UtilityAccount copyWith({
    double? latestReading,
    double? previousReading,
    DateTime? readingDate,
    Money? amountDue,
    UtilityBillStatus? status,
    List<UtilityReading>? readings,
    List<UtilityBill>? bills,
  }) {
    return UtilityAccount(
      kind: kind,
      meterNumber: meterNumber,
      supplier: supplier,
      latestReading: latestReading ?? this.latestReading,
      previousReading: previousReading ?? this.previousReading,
      readingDate: readingDate ?? this.readingDate,
      amountDue: amountDue ?? this.amountDue,
      status: status ?? this.status,
      readings: readings ?? this.readings,
      bills: bills ?? this.bills,
    );
  }
}
