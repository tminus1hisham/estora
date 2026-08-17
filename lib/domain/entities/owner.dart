import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

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
/// Counts rather than a rate, because this is what the status strip draws. The
/// occupancy *rate* is supplied separately by the server — deriving it here as
/// well would give the app two answers to the same question.
class UnitMix {
  const UnitMix({
    this.leased = 0,
    this.booked = 0,
    this.available = 0,
    this.unavailable = 0,
  });

  /// Let, and earning.
  final int leased;

  /// Reserved or booked — spoken for, not yet earning.
  final int booked;

  final int available;

  /// Under maintenance or deliberately withheld.
  final int unavailable;

  int get total => leased + booked + available + unavailable;
  bool get isEmpty => total == 0;
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
