import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

/// Section 26. The central legal and commercial agreement.
class Lease {
  const Lease({
    required this.id,
    required this.leaseNumber,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.depositAmount,
    required this.billingFrequency,
    required this.paymentDueDay,
    required this.status,
    required this.createdAt,
    this.bookingId,
    this.signedAt,
    this.activatedAt,
    this.terminatedAt,
    this.propertyName,
    this.unitNumber,
    this.agreementDocumentId,
    this.signedAgreementDocumentId,
    this.terms = const <LeaseTerm>[],
    this.activationConditions = const <LeaseActivationCondition>[],
    this.signatures = const <LeaseSignature>[],
  });

  final String id;
  final String leaseNumber;

  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? bookingId;

  final DateTime startDate;
  final DateTime endDate;

  /// The rent this lease was written at. Section 55: historical invoices keep
  /// their original pricing, and a renewal creates a *new* lease rather than
  /// editing this one (section 54).
  final Money monthlyRent;
  final Money depositAmount;
  final BillingFrequency billingFrequency;

  /// Day of month rent falls due, e.g. 5 (section 34).
  final int paymentDueDay;

  final LeaseStatus status;

  final DateTime? signedAt;
  final DateTime? activatedAt;
  final DateTime? terminatedAt;
  final DateTime createdAt;

  final String? propertyName;
  final String? unitNumber;

  /// The generated agreement (section 28) and, once signed, the immutable
  /// signed copy (section 29).
  final String? agreementDocumentId;
  final String? signedAgreementDocumentId;

  final List<LeaseTerm> terms;

  /// Section 30's checklist, evaluated server-side. Rendered read-only — the
  /// app never flips a lease to ACTIVE.
  final List<LeaseActivationCondition> activationConditions;

  final List<LeaseSignature> signatures;

  Duration get remainingTerm => endDate.difference(DateTime.now());

  int get daysUntilExpiry => remainingTerm.inDays;

  bool get isExpiringSoon =>
      status.isCurrent && daysUntilExpiry <= 90 && daysUntilExpiry >= 0;

  bool get hasTenantSigned => signatures.isNotEmpty || signedAt != null;

  /// True when every mandatory activation condition is met. Informational only:
  /// the property manager still has to approve (section 30), and the server
  /// still owns the transition.
  bool get allConditionsMet =>
      activationConditions.where((c) => c.isMandatory).every((c) => c.isMet);
}

/// Section 27. A single commercial or legal term.
///
/// Terms are rows rather than fields so that adding "subletting policy" or
/// "utility responsibility" needs no schema or UI change.
class LeaseTerm {
  const LeaseTerm({
    required this.id,
    required this.label,
    required this.value,
    this.description,
    this.group,
  });

  final String id;
  final String label;
  final String value;
  final String? description;

  /// Optional grouping heading, e.g. "Financial", "Notice and renewal".
  final String? group;
}

/// One line of section 30's activation checklist.
class LeaseActivationCondition {
  const LeaseActivationCondition({
    required this.id,
    required this.label,
    required this.isMet,
    required this.isMandatory,
    this.detail,
  });

  final String id;
  final String label;
  final String? detail;
  final bool isMet;
  final bool isMandatory;
}

/// Section 29.
class LeaseSignature {
  const LeaseSignature({
    required this.id,
    required this.leaseId,
    required this.signatureType,
    required this.signedAt,
    this.userId,
    this.signerName,
    this.documentHash,
  });

  final String id;
  final String leaseId;
  final String? userId;
  final String? signerName;
  final SignatureType signatureType;
  final DateTime signedAt;

  /// Hash of the exact document version that was signed, so a later dispute can
  /// prove which text the tenant agreed to (section 85).
  final String? documentHash;
}
