import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import 'utility_models.dart';

/// Every figure on this screen is in shillings; there is no meter anywhere in
/// the estate billed in anything else.
const String _currency = 'KES';

/// What the supplier charges per unit, in major units.
///
/// These stand in for a tariff the server will one day publish. They live here
/// rather than on [UtilityAccount] because a tariff belongs to the supplier,
/// not to a tenant's meter, and because the mock needs to re-cost a month when
/// a tenant submits a reading.
const Map<UtilityKind, num> _tariffPerUnit = {
  UtilityKind.water: 172.00,
  UtilityKind.electricity: 27.50,
};

/// The tenant's meters.
///
/// There is no utilities endpoint yet, so this notifier is both the store and
/// the stand-in for the server: it seeds plausible figures, and it does the
/// small amount of arithmetic — re-costing a month, re-totalling what is owed —
/// that a server would own once one exists. Nothing here is sent anywhere.
final utilityAccountsProvider =
    NotifierProvider<UtilityController, List<UtilityAccount>>(
      UtilityController.new,
    );

class UtilityController extends Notifier<List<UtilityAccount>> {
  @override
  List<UtilityAccount> build() => _seed();

  /// Records a reading the tenant has taken off the dial.
  ///
  /// The reading replaces the current dial figure; the opening figure for the
  /// month stays where it is, so the month's use grows rather than resetting.
  /// The month in the history and the bill raised against it are re-costed at
  /// the tariff, which is what keeps the card, the history and the total owed
  /// telling the same story.
  ///
  /// A figure below the opening reading is ignored rather than allowed to
  /// produce negative use — the form validates for this, and a meter that has
  /// run backwards is a fault to report, not a reading to file.
  void submitReading(UtilityKind kind, double reading) {
    state = [
      for (final account in state)
        if (account.kind == kind) _applyReading(account, reading) else account,
    ];
  }

  /// Settles a bill.
  ///
  /// Mock only: no money moves, and no payment has been raised. It exists so
  /// the preview can show what the screen looks like once a bill clears.
  void markPaid(String billReference) {
    state = [
      for (final account in state)
        if (account.bills.any((bill) => bill.reference == billReference))
          _settle(account, [
            for (final bill in account.bills)
              if (bill.reference == billReference)
                bill.copyWith(status: UtilityBillStatus.paid)
              else
                bill,
          ])
        else
          account,
    ];
  }

  /// Pull-to-refresh.
  ///
  /// There is nothing to fetch, so this only settles for a beat. It
  /// deliberately does not re-seed: a tenant who submits a reading and then
  /// pulls the list down would watch it disappear, which reads as the app
  /// losing their work rather than as a preview being honest about itself.
  /// The note at the top of the screen is where that honesty belongs.
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  UtilityAccount _applyReading(UtilityAccount account, double reading) {
    if (reading < account.previousReading) return account;
    if (account.readings.isEmpty) return account;

    final used = reading - account.previousReading;
    final cost = _cost(account.kind, used);
    final current = account.readings.last;

    final readings = [
      ...account.readings.take(account.readings.length - 1),
      UtilityReading(period: current.period, consumption: used, cost: cost),
    ];

    // Only a bill still open is re-costed. A bill already paid is history, and
    // a new reading does not reopen it.
    final bills = [
      for (final bill in account.bills)
        if (bill.period == current.period && !bill.status.isSettled)
          UtilityBill(
            reference: bill.reference,
            kind: bill.kind,
            issuedOn: bill.issuedOn,
            dueOn: bill.dueOn,
            amount: cost,
            status: bill.status,
          )
        else
          bill,
    ];

    return _settle(
      account.copyWith(
        latestReading: reading,
        readingDate: DateTime.now(),
        readings: readings,
      ),
      bills,
    );
  }

  /// Re-totals a meter from its bills.
  ///
  /// The one place in the module that adds money up, so there is one place to
  /// delete when a server starts supplying the figure (section 84 rule 7 puts
  /// totalling on the server; this module has no server yet).
  UtilityAccount _settle(UtilityAccount account, List<UtilityBill> bills) {
    final open = bills.where((bill) => !bill.status.isSettled);
    final outstanding = open.fold(
      const Money.zero(_currency),
      (total, bill) => total + bill.amount,
    );

    return account.copyWith(
      bills: bills,
      amountDue: outstanding,
      status: open.any((bill) => bill.status == UtilityBillStatus.overdue)
          ? UtilityBillStatus.overdue
          : open.isEmpty
          ? UtilityBillStatus.paid
          : UtilityBillStatus.due,
    );
  }
}

/// One meter, by kind.
///
/// Falls back to a freshly seeded account rather than returning null: both
/// kinds are always seeded, and a nullable return would buy an empty state
/// that can never be reached.
final utilityAccountProvider = Provider.family<UtilityAccount, UtilityKind>((
  ref,
  kind,
) {
  final accounts = ref.watch(utilityAccountsProvider);
  return accounts.firstWhere(
    (account) => account.kind == kind,
    orElse: () => _seed().firstWhere((account) => account.kind == kind),
  );
});

/// Everything owed across both meters.
final utilityTotalDueProvider = Provider<Money>((ref) {
  final accounts = ref.watch(utilityAccountsProvider);
  return accounts.fold(
    const Money.zero(_currency),
    (total, account) => total + account.amountDue,
  );
});

/// The part of the total that is already late, so the screen can say so
/// instead of folding it silently into "due this month".
final utilityOverdueTotalProvider = Provider<Money>((ref) {
  final accounts = ref.watch(utilityAccountsProvider);
  return accounts.fold(const Money.zero(_currency), (total, account) {
    final late = account.bills
        .where((bill) => bill.status == UtilityBillStatus.overdue)
        .fold(const Money.zero(_currency), (sum, bill) => sum + bill.amount);
    return total + late;
  });
});

/// Both meters' bills interleaved, newest first, for the list on the overview.
final utilityBillsProvider = Provider<List<UtilityBill>>((ref) {
  final accounts = ref.watch(utilityAccountsProvider);
  final bills = [for (final account in accounts) ...account.bills]
    ..sort((a, b) => b.issuedOn.compareTo(a.issuedOn));
  return bills;
});

Money _cost(UtilityKind kind, double consumption) =>
    Money.fromMajor(consumption * _tariffPerUnit[kind]!, _currency);

/// Six months of plausible meter history for both services.
///
/// Anchored on the current month so the screen never shows a year that has
/// been and gone, and otherwise entirely fixed: the same months always carry
/// the same figures, which is what makes a preview safe to screenshot and
/// stable to test against. `DateTime` normalises a month of 0 or -1 into the
/// previous year, so the arithmetic needs no special case in January.
List<UtilityAccount> _seed() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);

  return [
    _account(
      kind: UtilityKind.water,
      meterNumber: 'WM-4471-08',
      supplier: 'Nairobi Water & Sewerage Co.',
      reference: 'WTR',
      openingReading: 1180,
      readingTakenDaysAgo: 4,
      monthlyConsumption: const [38.0, 41.5, 36.0, 44.0, 39.5, 42.0],
      // Water has been paid up; only the month in progress is outstanding.
      billStatuses: const [
        UtilityBillStatus.due,
        UtilityBillStatus.paid,
        UtilityBillStatus.paid,
        UtilityBillStatus.paid,
      ],
      thisMonth: thisMonth,
    ),
    _account(
      kind: UtilityKind.electricity,
      meterNumber: 'EM-9920-13',
      supplier: 'Kenya Power (KPLC)',
      reference: 'ELC',
      openingReading: 24500,
      readingTakenDaysAgo: 2,
      monthlyConsumption: const [860.0, 935.0, 902.0, 1010.0, 968.0, 1044.0],
      // Last month's bill was missed, so the screen has an overdue state to
      // show without the tenant having to imagine one.
      billStatuses: const [
        UtilityBillStatus.due,
        UtilityBillStatus.overdue,
        UtilityBillStatus.paid,
        UtilityBillStatus.paid,
      ],
      thisMonth: thisMonth,
    ),
  ];
}

/// Builds one meter from a run of monthly figures.
///
/// [monthlyConsumption] runs oldest first and ends on the month in progress.
/// [billStatuses] runs newest first, one per billed month, and is allowed to be
/// shorter than the history — the estate only keeps a few months of bills in
/// front of a tenant.
UtilityAccount _account({
  required UtilityKind kind,
  required String meterNumber,
  required String supplier,
  required String reference,
  required double openingReading,
  required int readingTakenDaysAgo,
  required List<double> monthlyConsumption,
  required List<UtilityBillStatus> billStatuses,
  required DateTime thisMonth,
}) {
  final months = monthlyConsumption.length;
  final readings = <UtilityReading>[
    for (var i = 0; i < months; i++)
      UtilityReading(
        period: DateTime(thisMonth.year, thisMonth.month - (months - 1 - i)),
        consumption: monthlyConsumption[i],
        cost: _cost(kind, monthlyConsumption[i]),
      ),
  ];

  // The dial: everything ever used, so the last two figures differ by the
  // month in progress.
  final dial = monthlyConsumption.fold<double>(
    openingReading,
    (total, used) => total + used,
  );
  final monthOpening = dial - monthlyConsumption.last;

  final bills = <UtilityBill>[
    for (var i = 0; i < billStatuses.length; i++)
      () {
        final period = DateTime(thisMonth.year, thisMonth.month - i);
        final reading = readings.firstWhere(
          (entry) => entry.period == period,
          orElse: () => readings.first,
        );
        return UtilityBill(
          reference:
              '$reference-${period.year}-${period.month.toString().padLeft(2, '0')}',
          kind: kind,
          issuedOn: period,
          // Suppliers in the estate give a fortnight from the first.
          dueOn: DateTime(period.year, period.month, 15),
          amount: reading.cost,
          status: billStatuses[i],
        );
      }(),
  ];

  final open = bills.where((bill) => !bill.status.isSettled);

  return UtilityAccount(
    kind: kind,
    meterNumber: meterNumber,
    supplier: supplier,
    latestReading: dial,
    previousReading: monthOpening,
    // Relative to today rather than a day of the month: a meter read "on the
    // 2nd" would sit in the future for the first day of every month.
    readingDate: DateTime.now().subtract(Duration(days: readingTakenDaysAgo)),
    amountDue: open.fold(
      const Money.zero(_currency),
      (total, bill) => total + bill.amount,
    ),
    status: open.any((bill) => bill.status == UtilityBillStatus.overdue)
        ? UtilityBillStatus.overdue
        : open.isEmpty
        ? UtilityBillStatus.paid
        : UtilityBillStatus.due,
    readings: readings,
    bills: bills,
  );
}
