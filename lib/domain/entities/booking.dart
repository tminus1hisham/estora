import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

/// Who is asking for the unit, and on whose behalf.
///
/// The contract wants these details on the booking request itself rather than
/// reading them off the session, and it is right to: the person tapping the
/// button is not always the person whose name goes on the lease, and a company
/// letting a shop is identified by its trading name, not by whoever holds the
/// phone. The form is prefilled from the signed-in account so the common case
/// stays one confirmation.
class BookingApplicant {
  const BookingApplicant({
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    this.companyName,
    this.businessType,
  });

  final String fullName;
  final String phoneNumber;
  final String email;

  /// Set when the unit is being taken by a business rather than an individual.
  final String? companyName;

  /// What the business does — what will actually trade out of the unit. This
  /// is a letting decision, not a formality: a landlord balancing a tenant mix
  /// needs to know before agreeing, not after.
  final String? businessType;

  bool get isCompany => companyName != null && companyName!.trim().isNotEmpty;

  /// Common categories, offered so a tenant mix stays comparable across
  /// bookings instead of accumulating twelve spellings of "restaurant". Free
  /// text is still accepted; the contract does not constrain the field.
  static const List<String> businessTypes = [
    'Retail',
    'Fashion and apparel',
    'Food and beverage',
    'Groceries and supermarket',
    'Health and beauty',
    'Electronics',
    'Financial services',
    'Professional services',
    'Entertainment',
    'Other',
  ];
}

/// What a booking is for, as the contract identifies it.
///
/// The published request names a property and a block, and nothing smaller:
/// the server allocates a unit within the block. That is also all the
/// availability engine — the one route Browse reads — can name, since it
/// answers with blocks and the sizes in stock rather than with unit records.
/// So the tenant books a *space* ([SpaceTarget]), and a unit id only enters
/// the picture when a caller already holds a unit record ([UnitTarget]).
sealed class BookingTarget {
  const BookingTarget();

  /// The intent this target represents, for the idempotency key. Booking the
  /// same space twice is the same intent; a different size in the same block
  /// is not.
  String get intent;
}

/// A size in a block, straight off the availability engine.
class SpaceTarget extends BookingTarget {
  const SpaceTarget({
    required this.propertyId,
    required this.blockId,
    this.size,
  });

  final String propertyId;
  final String blockId;

  /// The area wanted, in the unit the engine measures in (square feet), or
  /// null for any size the block has.
  final double? size;

  @override
  String get intent => 'space:$propertyId/$blockId/${size ?? '*'}';
}

/// A specific unit, from a caller that has its record in hand — the unit
/// detail screen, or the demo fixtures. Never reached from Browse.
class UnitTarget extends BookingTarget {
  const UnitTarget(this.unitId);

  final String unitId;

  @override
  String get intent => 'unit:$unitId';
}

/// Section 21. A temporary reservation of a unit, ahead of a lease.
///
/// The critical property of this entity is that it **captures its commercial
/// terms at the moment of booking**. If the unit's rent later moves from
/// 150,000 to 170,000, this booking stays at 150,000. Nothing in the app may
/// re-derive [monthlyRent], [depositAmount] or [bookingFee] from the unit's
/// current pricing.
class Booking {
  const Booking({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.bookingReference,
    required this.monthlyRent,
    required this.depositAmount,
    required this.bookingFee,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.propertyId,
    this.propertyName,
    this.unitNumber,
    this.leaseId,
    this.bookingFeeInvoiceId,
    this.depositInvoiceId,
    this.isPaid = false,
    this.phoneNumber,
    this.requirements = const <BookingRequirement>[],
  });

  final String id;
  final String unitId;
  final String tenantId;

  /// Whether the server has received the booking fee.
  ///
  /// Carried separately from [status] because the contract states both, and
  /// they can disagree for a moment: a fee that has landed but whose booking
  /// the worker has not yet activated. Either one is enough to take the pay
  /// action off the screen — see [canPayFee].
  final bool isPaid;

  /// The applicant's phone number, as given on the booking request.
  ///
  /// Seeds the M-Pesa prompt: the handset the applicant gave is, nearly
  /// always, the one they will pay from.
  final String? phoneNumber;

  final String bookingReference;

  /// Terms as at booking time. See the class doc.
  final Money monthlyRent;
  final Money depositAmount;
  final Money bookingFee;

  /// When the reservation lapses (section 23). Null before the booking becomes
  /// ACTIVE, since the countdown starts on successful payment of the fee.
  final DateTime? expiresAt;

  final BookingStatus status;
  final DateTime createdAt;

  final String? propertyId;
  final String? propertyName;
  final String? unitNumber;

  /// Set once the booking converts (section 22).
  final String? leaseId;

  /// The booking fee is raised as an invoice rather than a boolean, so there is
  /// a complete financial trail (section 31 makes the same point about
  /// deposits).
  final String? bookingFeeInvoiceId;
  final String? depositInvoiceId;

  final List<BookingRequirement> requirements;

  /// Time left before expiry, or null when the booking is not counting down.
  ///
  /// Purely for display. The server decides whether a booking has actually
  /// expired — a background worker flips the status (section 23) — so a zero
  /// here means "re-fetch and see", not "this booking is expired".
  Duration? get timeRemaining {
    if (expiresAt == null || !status.isCountingDown) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the booking fee can be paid from here (section 24).
  ///
  /// The fee is payable while the server is still waiting for it, and only
  /// then. A paid booking, an active one, or one that has lapsed has nothing
  /// left to collect.
  bool get canPayFee => status.awaitsBookingFee && !isPaid;

  bool get isExpiringSoon {
    final remaining = timeRemaining;
    return remaining != null && remaining < const Duration(hours: 6);
  }

  int get satisfiedRequirementCount =>
      requirements.where((r) => r.isSatisfied).length;

  int get mandatoryRequirementCount =>
      requirements.where((r) => r.isMandatory).length;

  bool get allMandatoryRequirementsSatisfied =>
      requirements.where((r) => r.isMandatory).every((r) => r.isSatisfied);
}

/// A [UnitRequirement] as it applies to one booking, with the tenant's progress
/// against it.
class BookingRequirement {
  const BookingRequirement({
    required this.id,
    required this.requirementType,
    required this.name,
    required this.isMandatory,
    required this.isSatisfied,
    this.description,
    this.documentType,
    this.documentId,
    this.satisfiedAt,
  });

  final String id;
  final RequirementType requirementType;
  final String name;
  final String? description;
  final bool isMandatory;

  /// Server-evaluated (section 30).
  final bool isSatisfied;

  final DocumentType? documentType;

  /// The uploaded document that satisfied this requirement, when it was a
  /// document requirement.
  final String? documentId;

  final DateTime? satisfiedAt;
}

/// The server's answer to "what would it cost me to book this unit?".
///
/// Section 65 forbids the client from computing or submitting authoritative
/// financial amounts, so the booking screen asks the server for a quote and
/// renders it verbatim. There is deliberately no arithmetic in this class —
/// [total] is a server-supplied field, not a sum of the others.
class BookingQuote {
  const BookingQuote({
    required this.unitId,
    required this.monthlyRent,
    required this.depositAmount,
    required this.bookingFee,
    required this.total,
    required this.currency,
    required this.expiryHours,
    this.depositMonths,
    this.taxAmount,
    this.taxLabel,
    this.requirements = const <UnitRequirementSummary>[],
  });

  final String unitId;
  final Money monthlyRent;
  final Money depositAmount;
  final Money bookingFee;

  /// Tax on the booking fee, if the property charges any (section 57).
  final Money? taxAmount;
  final String? taxLabel;

  /// The amount payable **now** to hold the unit. Server-computed.
  final Money total;

  final String currency;

  /// Deposit expressed in months, for the explanatory line
  /// "5 months × KES 150,000".
  final int? depositMonths;

  /// How long the reservation will hold once paid (section 23).
  final int expiryHours;

  final List<UnitRequirementSummary> requirements;
}

/// Lightweight requirement description shown on the booking quote.
class UnitRequirementSummary {
  const UnitRequirementSummary({
    required this.name,
    required this.requirementType,
    required this.isMandatory,
    this.description,
  });

  final String name;
  final String? description;
  final RequirementType requirementType;
  final bool isMandatory;
}
