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
