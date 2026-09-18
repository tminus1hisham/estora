import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';
import 'billing.dart';
import 'treasury.dart';
import 'unit.dart';

/// Section 88. The individual or company that owns a property and lets it.
///
/// The counterpart to [Tenant]. Where a tenant occupies one unit under one
/// lease, an owner holds a portfolio: properties, the units inside them, and
/// the money those units bring in. The two never share a screen — an account is
/// one or the other, decided by [AccountRole] and enforced once in the router.
///
/// Ownership itself lives on the property, not here. `Property.ownerId` is the
/// edge, so a property can change hands without rewriting the owner.
class PropertyOwner {
  const PropertyOwner({
    required this.id,
    required this.userId,
    required this.ownerType,
    required this.displayName,
    required this.status,
    this.legalName,
    this.registrationNumber,
    this.taxNumber,
    this.payoutAccountNumber,
  });

  final String id;
  final String userId;
  final OwnerType ownerType;

  /// What the owner is called on screen. A trading name for a company, a
  /// person's name for an individual.
  final String displayName;

  final String status;

  final String? legalName;
  final String? registrationNumber;
  final String? taxNumber;

  /// Where collected rent is paid out to. Held in full only on the server;
  /// render [maskedPayoutAccount] rather than this.
  final String? payoutAccountNumber;

  /// The last four digits only, e.g. `••••4821`.
  ///
  /// The same treatment [TenantProfile] gives identification numbers, for the
  /// same reason: enough to confirm the right account is on file without
  /// putting it on a screen someone could be reading over your shoulder.
  String? get maskedPayoutAccount {
    final value = payoutAccountNumber;
    if (value == null || value.isEmpty) return null;
    if (value.length <= 4) return '•' * value.length;
    return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Section 88. What an owner fills in to register a property.
///
/// A draft, not a [Property]: it carries no id, no derived counts and no
/// status, because those are the server's to decide. The client describes what
/// it wants; what comes back is the record that was actually created.
class PropertyDraft {
  const PropertyDraft({
    required this.name,
    required this.propertyType,
    required this.city,
    required this.country,
    required this.rentRatePerSqm,
    this.description,
    this.address,
    this.county,
    this.totalArea,
  });

  final String name;
  final PropertyType propertyType;
  final String? description;
  final String? address;
  final String city;
  final String? county;
  final String country;
  final double? totalArea;

  /// What the property will ask per square metre. Every unit created under it
  /// takes its rent from this unless the batch or the unit overrides it.
  final Money rentRatePerSqm;
}

/// Section 17. A batch of units to create from one template.
///
/// The batch is a creation mechanism only — section 17 is explicit that each
/// generated unit is an independent entity afterwards, so nothing links them
/// once they exist.
class UnitBatchDraft {
  const UnitBatchDraft({
    required this.typeName,
    required this.area,
    required this.quantity,
    required this.numberPrefix,
    this.startNumber = 1,
    this.length,
    this.width,
    this.depositMonths,
    this.bookingFee,
    this.ratePerSqm,
    this.buildingName,
    this.floorName,
    this.description,
  });

  /// Names the unit type the batch creates, e.g. `50x100 Retail Unit`.
  final String typeName;
  final String? description;

  final double? length;
  final double? width;
  final double area;

  final int quantity;

  /// `SHOP` plus [startNumber] gives SHOP-101, SHOP-102, and so on.
  final String numberPrefix;
  final int startNumber;

  final int? depositMonths;
  final Money? bookingFee;

  /// Overrides the property's rate for the units in this batch — a kiosk earns
  /// more per square metre than a shop floor in the same building.
  final Money? ratePerSqm;

  final String? buildingName;
  final String? floorName;
}

/// What a repricing would actually move, worked out before it happens.
///
/// The confirmation has to name a number before the owner commits, and working
/// it out on the client would be a second implementation of the rule — free to
/// disagree with the one that runs.
class RepricingImpact {
  const RepricingImpact({
    required this.repriceable,
    required this.overridden,
    required this.let,
  });

  /// Unlet, unoverridden units: the ones that will move.
  final int repriceable;

  /// Priced by hand, so left alone.
  final int overridden;

  /// Under a live lease. These take the new rate when they next come free.
  final int let;

  int get untouched => overridden + let;
}

/// How a property's units are distributed across the states that matter to an
/// owner.
///
/// Counts rather than a rate, because this is what the status strip draws.
/// Where the server reports occupancy itself ([PropertyPerformance] carries
/// its own `occupancyRate`) that figure is the one shown. The published
/// contract reports none, so a property or block read off the live API has
/// its mix counted from the unit records the server sent, and [occupancy] is
/// section 71's rule applied to that count — let units over all units, the
/// same arithmetic the reporting side uses. It is derived from records the
/// server holds, never from anything the app made up.
class UnitMix {
  const UnitMix({
    this.leased = 0,
    this.booked = 0,
    this.available = 0,
    this.unavailable = 0,
  });

  /// Counted from unit records, one to a status.
  factory UnitMix.of(Iterable<Unit> units) {
    var leased = 0;
    var booked = 0;
    var available = 0;
    var unavailable = 0;
    for (final unit in units) {
      switch (unit.status) {
        case UnitStatus.leased:
          leased++;
        case UnitStatus.reserved || UnitStatus.booked:
          booked++;
        case UnitStatus.available:
          available++;
        case _:
          unavailable++;
      }
    }
    return UnitMix(
      leased: leased,
      booked: booked,
      available: available,
      unavailable: unavailable,
    );
  }

  /// Let, and earning.
  final int leased;

  /// Reserved or booked — spoken for, not yet earning.
  final int booked;

  final int available;

  /// Under maintenance or deliberately withheld.
  final int unavailable;

  int get total => leased + booked + available + unavailable;
  bool get isEmpty => total == 0;

  /// Share of units let, 0–1. Zero when there are no units to let.
  double get occupancy => total == 0 ? 0 : (leased / total).clamp(0, 1);

  int get occupancyPercent => (occupancy * 100).round();

  /// `9 of 12 let`.
  String get occupancyLabel => '$leased of $total let';
}

/// A property's [UnitMix], whole and split by block.
///
/// One count of the property's unit records serves both the property screen
/// and its block list, so the two never disagree about the same units.
class PropertyOccupancy {
  const PropertyOccupancy({required this.mix, required this.byBlock});

  factory PropertyOccupancy.of(Iterable<Unit> units) {
    final grouped = <String, List<Unit>>{};
    for (final unit in units) {
      final blockId = unit.buildingId;
      if (blockId != null) (grouped[blockId] ??= <Unit>[]).add(unit);
    }
    return PropertyOccupancy(
      mix: UnitMix.of(units),
      byBlock: {
        for (final entry in grouped.entries) entry.key: UnitMix.of(entry.value),
      },
    );
  }

  final UnitMix mix;

  /// Keyed on block id. A block with no units has no entry.
  final Map<String, UnitMix> byBlock;

  UnitMix? forBlock(String blockId) => byBlock[blockId];
}

/// What was billed and what came in, for one month.
class MonthlyCollection {
  const MonthlyCollection({
    required this.month,
    required this.billed,
    required this.collected,
  });

  /// The first of the month it covers.
  final DateTime month;
  final Money billed;
  final Money collected;
}

/// Something asking for the owner's attention, with somewhere to go about it.
class OwnerAlert {
  const OwnerAlert({
    required this.type,
    required this.title,
    required this.detail,
    this.target = NotificationTarget.none,
    this.targetId,
  });

  final OwnerAlertType type;
  final String title;
  final String detail;

  /// Reuses the tenant app's deep-link vocabulary rather than inventing a
  /// second one — an alert about a lease points at that lease the same way a
  /// notification does.
  final NotificationTarget target;
  final String? targetId;
}

/// Section 88. How one property is doing.
///
/// Every figure here is computed by the server. Section 84 rule 7 puts
/// totalling on the server and section 65 keeps the client out of computing
/// payable amounts, and neither exempts a dashboard — an occupancy rate the app
/// worked out for itself is a second source of truth waiting to disagree with
/// the one the accounts are kept in.
class PropertyPerformance {
  const PropertyPerformance({
    required this.propertyId,
    required this.propertyName,
    required this.currency,
    required this.mix,
    required this.occupancyRate,
    required this.monthlyContractedRent,
    required this.billedThisMonth,
    required this.collectedThisMonth,
    required this.outstanding,
    required this.overdue,
    required this.collectionRate,
    this.imageUrl,
    this.totalArea,
    this.rentRatePerSqm,
    this.letArea,
    this.expiringLeases = 0,
    this.tenantsInArrears = 0,
    this.history = const <MonthlyCollection>[],
  });

  final String propertyId;
  final String propertyName;
  final String? imageUrl;
  final String currency;

  final UnitMix mix;

  /// Share of units let, 0–1. Server-supplied.
  final double occupancyRate;

  final double? totalArea;
  final double? letArea;
  final Money? rentRatePerSqm;

  /// What the signed leases add up to per month. The rent roll.
  final Money monthlyContractedRent;

  final Money billedThisMonth;
  final Money collectedThisMonth;
  final Money outstanding;
  final Money overdue;

  /// Collected over billed for the current month, 0–1. Server-supplied.
  final double collectionRate;

  final int expiringLeases;
  final int tenantsInArrears;

  /// Most recent month last.
  final List<MonthlyCollection> history;

  bool get hasArrears => tenantsInArrears > 0;
  bool get isFullyLet => mix.available == 0 && !mix.isEmpty;

  /// `KES 30 / m²`, or null if the property is not priced by area.
  String? get rateLabel {
    final rate = rentRatePerSqm;
    return rate == null ? null : '${rate.format()} / m²';
  }
}

/// Section 88. One unit in a property's rent roll.
///
/// What the owner needs on a line: what it is, who is in it, what it asks, and
/// whether that figure came from the rate or from someone's judgement.
class RentRollEntry {
  const RentRollEntry({
    required this.unitId,
    required this.unitNumber,
    required this.status,
    required this.baseRent,
    required this.rentOverridden,
    this.name,
    this.area,
    this.areaUnit = 'm²',
    this.ratePerSqm,
    this.tenantId,
    this.tenantName,
    this.leaseId,
    this.leaseEndDate,
    this.outstanding,
  });

  final String unitId;
  final String unitNumber;
  final String? name;
  final UnitStatus status;

  final double? area;
  final String areaUnit;

  final Money baseRent;
  final Money? ratePerSqm;
  final bool rentOverridden;

  /// Null when the unit is not let.
  final String? tenantId;
  final String? tenantName;
  final String? leaseId;
  final DateTime? leaseEndDate;

  /// What the occupant owes, if anything.
  final Money? outstanding;

  bool get isLet => leaseId != null;
  bool get isInArrears => (outstanding?.isPositive ?? false);

  /// `KES 30 / m²`, with a note when the rent was set by hand instead.
  String? get rateLabel {
    final rate = ratePerSqm;
    if (rate == null) return rentOverridden ? 'Priced by hand' : null;
    return rentOverridden
        ? '${rate.format()} / $areaUnit · overridden'
        : '${rate.format()} / $areaUnit';
  }
}

/// Section 88. A tenancy as the owner sees it.
///
/// The same lease a tenant reads on their own screen, turned around: the
/// occupant is the subject rather than the reader.
class OwnerTenancy {
  const OwnerTenancy({
    required this.leaseId,
    required this.leaseNumber,
    required this.propertyId,
    required this.propertyName,
    required this.unitNumber,
    required this.tenantId,
    required this.tenantName,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.depositAmount,
    required this.status,
    required this.outstanding,
    required this.overdue,
    this.unitId,
    this.lastPaymentAt,
  });

  final String leaseId;
  final String leaseNumber;
  final String propertyId;
  final String propertyName;
  final String? unitId;
  final String unitNumber;

  final String tenantId;
  final String tenantName;

  final DateTime startDate;
  final DateTime endDate;

  /// Section 55: struck at signing and never re-derived from the unit's
  /// current asking rent.
  final Money monthlyRent;
  final Money depositAmount;

  final LeaseStatus status;

  final Money outstanding;
  final Money overdue;
  final DateTime? lastPaymentAt;

  bool get isInArrears => overdue.isPositive;
  int get daysUntilExpiry => endDate.difference(DateTime.now()).inDays;
  bool get isExpiringSoon =>
      status.isCurrent && daysUntilExpiry <= 60 && daysUntilExpiry >= 0;

  /// How far through the term the tenancy is, 0–1.
  double get termProgress {
    final total = endDate.difference(startDate).inDays;
    if (total <= 0) return 1;
    final run = DateTime.now().difference(startDate).inDays;
    return (run / total).clamp(0, 1);
  }
}

/// Section 41. What is due out to the owner for one month.
class OwnerPayout {
  const OwnerPayout({
    required this.month,
    required this.grossCollected,
    required this.platformFee,
    required this.net,
  });

  /// The first of the month it covers.
  final DateTime month;

  /// Everything that came in.
  final Money grossCollected;

  /// The platform's cut, shown rather than netted off quietly — an owner
  /// should be able to see what they were charged.
  final Money platformFee;

  /// Gross less the fee.
  final Money net;

  bool get isEmpty => grossCollected.isZero;
}

/// One band of the arrears ageing.
class ArrearsBucket {
  const ArrearsBucket({
    required this.label,
    required this.amount,
    required this.invoiceCount,
  });

  /// `Current`, `1–30 days`, and so on.
  final String label;
  final Money amount;
  final int invoiceCount;

  bool get isEmpty => invoiceCount == 0;
}

/// Money that has actually arrived.
class OwnerCollection {
  const OwnerCollection({
    required this.paymentId,
    required this.paidAt,
    required this.amount,
    required this.tenantName,
    required this.propertyName,
    required this.method,
    this.unitNumber,
    this.receiptId,
  });

  final String paymentId;
  final DateTime paidAt;
  final Money amount;
  final String tenantName;
  final String propertyName;
  final String? unitNumber;
  final PaymentMethod method;
  final String? receiptId;
}

/// Which slice of the owner's collections is being looked at.
enum CollectionPeriod { today, yesterday, month, custom }

/// A request for a slice of the owner's collections.
///
/// The client names the slice; the server draws the lines. Dates are only
/// carried for [CollectionPeriod.custom], and even then they are the two days
/// the owner picked, not the timestamps the query runs between — the server
/// widens "14 September" to the whole of that day, in its own timezone.
class CollectionWindow {
  const CollectionWindow.today()
    : period = CollectionPeriod.today,
      from = null,
      to = null;

  const CollectionWindow.yesterday()
    : period = CollectionPeriod.yesterday,
      from = null,
      to = null;

  /// The calendar month in progress.
  const CollectionWindow.month()
    : period = CollectionPeriod.month,
      from = null,
      to = null;

  /// Two dates, inclusive, in either order.
  CollectionWindow.custom({required DateTime from, required DateTime to})
    : period = CollectionPeriod.custom,
      from = _day(from.isAfter(to) ? to : from),
      to = _day(from.isAfter(to) ? from : to);

  final CollectionPeriod period;
  final DateTime? from;
  final DateTime? to;

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Resolves the window to its bounds and the columns it should be drawn
  /// in, relative to [now].
  ///
  /// Calendar arithmetic, not money: this is the one piece of a collections
  /// query every server answers identically, so the demo fixtures and the
  /// test server share it rather than each drawing the lines slightly
  /// differently. Neither sums anything here.
  ///
  /// The buckets are chosen for the shape of the window rather than for its
  /// length alone. A day is drawn by the hour; a month is drawn against the
  /// five before it, billed beside collected, because the gap between the two
  /// is what that view exists to show; a custom span is drawn by the day up to
  /// five weeks and by the month beyond.
  CollectionBounds resolve(DateTime now) {
    final today = _day(now);
    switch (period) {
      case CollectionPeriod.today:
        return _hours(today);
      case CollectionPeriod.yesterday:
        return _hours(today.subtract(const Duration(days: 1)));
      case CollectionPeriod.month:
        final start = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1);
        return CollectionBounds(
          from: start,
          to: end,
          buckets: [
            for (var back = 5; back >= 0; back--)
              _monthBucket(DateTime(now.year, now.month - back)),
          ],
        );
      case CollectionPeriod.custom:
        final start = from!;
        final end = to!.add(const Duration(days: 1));
        final days = end.difference(start).inDays;
        if (days <= 35) {
          return CollectionBounds(
            from: start,
            to: end,
            buckets: [
              for (var day = 0; day < days; day++)
                _dayBucket(start.add(Duration(days: day)), day, days),
            ],
          );
        }
        final buckets = <CollectionBucket>[];
        var month = DateTime(start.year, start.month);
        while (month.isBefore(end)) {
          buckets.add(_monthBucket(month));
          month = DateTime(month.year, month.month + 1);
        }
        return CollectionBounds(from: start, to: end, buckets: buckets);
    }
  }

  static CollectionBounds _hours(DateTime day) {
    final end = day.add(const Duration(days: 1));
    return CollectionBounds(
      from: day,
      to: end,
      buckets: [
        for (var hour = 0; hour < 24; hour++)
          CollectionBucket(
            start: day.add(Duration(hours: hour)),
            end: day.add(Duration(hours: hour + 1)),
            // Four ticks across the day; every hour labelled is a smear.
            label: hour % 6 == 0 ? _hourLabel(hour) : '',
            name: '${_hourLabel(hour)}–${_hourLabel(hour + 1)}',
          ),
      ],
    );
  }

  static CollectionBucket _dayBucket(DateTime day, int index, int count) =>
      CollectionBucket(
        start: day,
        end: day.add(const Duration(days: 1)),
        // A tick each week, and one on the last day so the span reads at a
        // glance — unless the weekly tick already lands there.
        label: index % 7 == 0 || (index == count - 1 && index % 7 != 0)
            ? DateFormat('d MMM').format(day)
            : '',
        name: DateFormat('EEE d MMM').format(day),
      );

  static CollectionBucket _monthBucket(DateTime month) => CollectionBucket(
    start: month,
    end: DateTime(month.year, month.month + 1),
    label: DateFormat('MMM').format(month),
    name: DateFormat('MMMM yyyy').format(month),
    isBillingPeriod: true,
  );

  static String _hourLabel(int hour) {
    final h = hour % 24;
    if (h == 0) return '12am';
    if (h == 12) return '12pm';
    return h < 12 ? '${h}am' : '${h - 12}pm';
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionWindow &&
      other.period == period &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);
}

/// Where a [CollectionWindow] starts and stops, and how it is divided.
class CollectionBounds {
  const CollectionBounds({
    required this.from,
    required this.to,
    required this.buckets,
  });

  /// Half-open: [from] is inside the window, [to] is not.
  final DateTime from;
  final DateTime to;
  final List<CollectionBucket> buckets;
}

/// One column's worth of time, before anything has been counted into it.
class CollectionBucket {
  const CollectionBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.name,
    this.isBillingPeriod = false,
  });

  final DateTime start;
  final DateTime end;

  /// The tick under the column, or empty where the axis stays quiet.
  final String label;

  /// The column's full name, for the readout and for a screen reader.
  final String name;

  /// Whether invoices are raised for this span, so a billed figure means
  /// something. True of a month; false of an hour or a day.
  final bool isBillingPeriod;

  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);
}

/// One column of the collections chart, as the server counted it.
class CollectionPoint {
  const CollectionPoint({
    required this.at,
    required this.label,
    required this.name,
    required this.collected,
    this.billed,
  });

  /// The column for a [MonthlyCollection], so the six-month history the
  /// ledger already carries is drawn by the same chart.
  CollectionPoint.month(MonthlyCollection month)
    : at = month.month,
      label = DateFormat('MMM').format(month.month),
      name = DateFormat('MMMM yyyy').format(month.month),
      collected = month.collected,
      billed = month.billed;

  /// The start of the span the column covers.
  final DateTime at;

  /// The tick under the column; empty where none is wanted.
  final String label;

  /// The span in words: "September 2026", "Tue 14 Sep", "2pm–3pm".
  final String name;

  final Money collected;

  /// What was invoiced over the same span, where the span is one invoices are
  /// raised for. Null for an hour or a day.
  final Money? billed;
}

/// A slice of the owner's collections, totalled and divided by the server.
///
/// Section 84 rule 7: the headline figure is [collected] as sent, never the
/// sum of [points], and [points] are never re-bucketed on the client.
class CollectionSeries {
  const CollectionSeries({
    required this.window,
    required this.from,
    required this.to,
    required this.collected,
    required this.platformFee,
    required this.net,
    required this.paymentCount,
    required this.points,
  });

  final CollectionWindow window;

  /// The bounds the server actually answered for. Half-open.
  final DateTime from;
  final DateTime to;

  final Money collected;
  final Money platformFee;
  final Money net;
  final int paymentCount;

  /// Oldest first.
  final List<CollectionPoint> points;

  bool get isEmpty => paymentCount == 0 && collected.isZero;
}

/// Section 88. What came in, what is owed, and what goes out to the owner.
class OwnerLedger {
  const OwnerLedger({
    required this.currency,
    required this.collectedThisMonth,
    required this.platformFeeThisMonth,
    required this.netThisMonth,
    required this.totalOutstanding,
    this.payouts = const <OwnerPayout>[],
    this.ageing = const <ArrearsBucket>[],
    this.collections = const <OwnerCollection>[],
    this.history = const <MonthlyCollection>[],
  });

  final String currency;

  final Money collectedThisMonth;
  final Money platformFeeThisMonth;
  final Money netThisMonth;
  final Money totalOutstanding;

  /// Oldest first.
  final List<OwnerPayout> payouts;

  /// Outstanding money, banded by how long it has been owed.
  final List<ArrearsBucket> ageing;

  /// Recent arrivals, newest first.
  final List<OwnerCollection> collections;

  /// Oldest first.
  final List<MonthlyCollection> history;

  bool get hasArrears => ageing.any((bucket) => !bucket.isEmpty);
}

/// Section 88. The owner's whole position, in one payload.
///
/// The counterpart to [DashboardSummary]: one request, everything the opening
/// screen shows, so the app is not stitching a headline figure together out of
/// four calls that were true at four different moments.
class OwnerPortfolio {
  const OwnerPortfolio({
    required this.ownerId,
    required this.currency,
    required this.mix,
    required this.occupancyRate,
    required this.monthlyContractedRent,
    required this.billedThisMonth,
    required this.collectedThisMonth,
    required this.outstanding,
    required this.overdue,
    required this.collectionRate,
    required this.platformFee,
    required this.netPayout,
    this.totalArea,
    this.properties = const <PropertyPerformance>[],
    this.history = const <MonthlyCollection>[],
    this.alerts = const <OwnerAlert>[],
  });

  final String ownerId;
  final String currency;

  final UnitMix mix;
  final double occupancyRate;
  final double? totalArea;

  final Money monthlyContractedRent;
  final Money billedThisMonth;
  final Money collectedThisMonth;
  final Money outstanding;
  final Money overdue;
  final double collectionRate;

  /// Section 41. Taken out of what was collected, and shown rather than netted
  /// off quietly — an owner should be able to see what the platform charged.
  final Money platformFee;

  /// What is due out to the owner: collected less [platformFee].
  final Money netPayout;

  final List<PropertyPerformance> properties;

  /// Most recent month last.
  final List<MonthlyCollection> history;

  final List<OwnerAlert> alerts;

  int get propertyCount => properties.length;
  bool get hasProperties => properties.isNotEmpty;
  bool get hasAlerts => alerts.isNotEmpty;
  bool get hasOutstanding => outstanding.isPositive;
}

/// Section 88. The owner's money, as the published contract states it.
///
/// The contract has no ledger route. What it serves an owner is records: every
/// M-Pesa arrival across the properties they hold (or one property's), and
/// every invoice raised on those properties. This is those two lists, with
/// the questions the Revenue screen asks answered from them — what came in
/// over a window, what is still owed and for how long. Each figure is arrived
/// at the way [UnitMix.of] arrives at occupancy: counted from records the
/// server holds, never from anything the app made up, and counted here rather
/// than in a widget so every screen that asks gets the same answer.
///
/// Nothing is netted. The contract does not state a platform fee, so no fee
/// is invented and no "net" is shown.
class OwnerReport {
  OwnerReport({
    required List<MpesaTransaction> received,
    required List<Invoice> invoices,
    this.propertyId,
    String? currency,
  }) : currency =
           currency ??
           invoices.firstOrNull?.currency ??
           received.firstOrNull?.amount.currency ??
           'KES',
       received = List<MpesaTransaction>.unmodifiable(
         [...received]..sort((a, b) => _when(b).compareTo(_when(a))),
       ),
       invoices = List<Invoice>.unmodifiable(
         [...invoices]..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate)),
       );

  /// The property the report is cut to, or null for every property the owner
  /// holds.
  final String? propertyId;

  /// The currency the figures are added up in: the records' own, where there
  /// are any.
  final String currency;

  /// Every M-Pesa transaction the till received for these properties, newest
  /// first.
  final List<MpesaTransaction> received;

  /// Every invoice raised on these properties, newest first.
  final List<Invoice> invoices;

  bool get isEmpty => received.isEmpty && invoices.isEmpty;

  /// The invoices still carrying a balance, soonest due first.
  List<Invoice> get outstandingInvoices =>
      invoices.where((invoice) => invoice.status.isOutstanding).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// What is still owed across [outstandingInvoices].
  Money get outstanding =>
      _sum(outstandingInvoices.map((invoice) => invoice.amountDue));

  bool get hasArrears => outstandingInvoices.isNotEmpty;

  /// Outstanding money, banded by how long it has been owed — the same bands
  /// the demo ledger uses, so the screen reads the same whichever served it.
  List<ArrearsBucket> ageingAt(DateTime now) {
    final owed = outstandingInvoices;
    ArrearsBucket bucket(String label, bool Function(int days) test) {
      final matching = owed
          .where((invoice) => test(now.difference(invoice.dueDate).inDays))
          .toList(growable: false);
      return ArrearsBucket(
        label: label,
        amount: _sum(matching.map((invoice) => invoice.amountDue)),
        invoiceCount: matching.length,
      );
    }

    return [
      bucket('Not yet due', (days) => days <= 0),
      bucket('1–30 days', (days) => days > 0 && days <= 30),
      bucket('31–60 days', (days) => days > 30 && days <= 60),
      bucket('Over 60 days', (days) => days > 60),
    ];
  }

  /// What came in over [window], with a column per bucket the window draws.
  ///
  /// A transaction is placed by the time the till stamped it; one the till did
  /// not stamp falls back to when the platform recorded it, and one with
  /// neither cannot be placed in any window and is left out of every one. A
  /// month's column also carries what was invoiced in it, because the gap
  /// between billed and collected is what that view exists to show.
  ReportSlice sliceOver(CollectionWindow window, {DateTime? now}) {
    final bounds = window.resolve(now ?? DateTime.now());
    final inWindow = received
        .where((row) {
          final at = _whenOrNull(row);
          return at != null &&
              !at.isBefore(bounds.from) &&
              at.isBefore(bounds.to);
        })
        .toList(growable: false);

    return ReportSlice(
      window: window,
      from: bounds.from,
      to: bounds.to,
      collected: _sum(inWindow.map((row) => row.amount)),
      paymentCount: inWindow.length,
      points: [
        for (final bucket in bounds.buckets)
          CollectionPoint(
            at: bucket.start,
            label: bucket.label,
            name: bucket.name,
            // Counted over everything received, not just the window: a
            // month's view draws the five months before it for comparison.
            collected: _sum(
              received
                  .where((row) => bucket.contains(_when(row)))
                  .map((row) => row.amount),
            ),
            billed: bucket.isBillingPeriod
                ? _sum(
                    invoices
                        .where(
                          (invoice) => bucket.contains(invoice.invoiceDate),
                        )
                        .map((invoice) => invoice.total),
                  )
                : null,
          ),
      ],
    );
  }

  /// Adds up amounts in the report's [currency]. An amount in another currency
  /// is not converted — there is no rate to convert it at — and so is not
  /// counted; the record itself still appears in the lists.
  Money _sum(Iterable<Money> amounts) => amounts
      .where((amount) => amount.currency == currency)
      .fold(Money.zero(currency), (total, amount) => total + amount);

  static DateTime? _whenOrNull(MpesaTransaction row) =>
      row.transactedAt ?? row.createdAt;

  /// For ordering only: a row with no time at all sorts last.
  static DateTime _when(MpesaTransaction row) =>
      _whenOrNull(row) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// One [CollectionWindow] of an [OwnerReport].
class ReportSlice {
  const ReportSlice({
    required this.window,
    required this.from,
    required this.to,
    required this.collected,
    required this.paymentCount,
    required this.points,
  });

  final CollectionWindow window;

  /// Half-open.
  final DateTime from;
  final DateTime to;

  final Money collected;
  final int paymentCount;

  /// Oldest first.
  final List<CollectionPoint> points;

  bool get isEmpty => paymentCount == 0;
}
