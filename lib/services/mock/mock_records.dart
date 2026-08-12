/// Mutable storage rows for the mock server.
///
/// Domain entities are immutable, which is right for everything that flows out
/// to the UI but awkward for something playing the part of a database. These
/// rows are the mock's internal, mutable representation; `toDomain()` produces
/// the immutable value the app actually sees.
///
/// Keeping the two separate means the domain layer never grows `copyWith`
/// methods that exist only to serve the mock.
library;

import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';

// ---------------------------------------------------------------------------
// Property configuration (section 12)
// ---------------------------------------------------------------------------

/// Section 12. Per-property business rules.
///
/// The spec is explicit that these are *defaults* which individual units and
/// leases may override — hence unit-level `depositMonths` and `bookingFee`
/// taking precedence over the values here.
class PropertyConfig {
  const PropertyConfig({
    required this.propertyId,
    required this.defaultCurrency,
    required this.bookingExpiryHours,
    required this.invoiceGenerationDay,
    required this.invoiceDueDay,
    required this.defaultDepositMonths,
    required this.defaultBookingFee,
    required this.platformFeePercent,
    this.bookingFeeType = BookingFeeType.fixed,
    this.bookingFeePercent = 0,
    this.paymentGracePeriodDays = 0,
    this.defaultLeaseMonths = 12,
    this.latePaymentEnabled = false,
    this.taxEnabled = false,
    this.taxName = 'VAT',
    this.taxRate = 0,
  });

  final String propertyId;
  final String defaultCurrency;

  /// Section 23.
  final int bookingExpiryHours;

  /// Section 34: generate on the 3rd, due on the 5th.
  final int invoiceGenerationDay;
  final int invoiceDueDay;

  final int defaultDepositMonths;
  final Money defaultBookingFee;

  /// Section 24.
  final BookingFeeType bookingFeeType;
  final num bookingFeePercent;

  final int paymentGracePeriodDays;
  final int defaultLeaseMonths;
  final bool latePaymentEnabled;

  /// Section 41.
  final num platformFeePercent;

  /// Section 57. Tax must not assume one country's system, so it is opt-in per
  /// property with its own name and rate.
  final bool taxEnabled;
  final String taxName;
  final num taxRate;

  /// Section 24. Booking fees may be a flat amount or a share of the rent.
  Money calculateBookingFee(Money monthlyRent) => switch (bookingFeeType) {
    BookingFeeType.fixed => defaultBookingFee,
    BookingFeeType.monthlyRentPercentage => monthlyRent.percentage(
      bookingFeePercent,
    ),
  };
}

/// Section 24.
enum BookingFeeType { fixed, monthlyRentPercentage }

// ---------------------------------------------------------------------------
// Units
// ---------------------------------------------------------------------------

class UnitRow {
  UnitRow({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.unitCode,
    required this.baseRent,
    required this.status,
    this.buildingId,
    this.floorId,
    this.unitTypeId,
    this.name,
    this.description,
    this.length,
    this.width,
    this.area,
    this.areaUnit = 'm²',
    this.depositMonths,
    this.bookingFee,
    this.requirements = const <UnitRequirement>[],
    this.propertyName,
    this.buildingName,
    this.floorName,
    this.billingFrequency = BillingFrequency.monthly,
  });

  final String id;
  final String propertyId;
  final String? buildingId;
  final String? floorId;
  final String? unitTypeId;

  final String unitNumber;
  final String unitCode;
  final String? name;
  final String? description;

  final double? length;
  final double? width;
  final double? area;
  final String areaUnit;

  final Money baseRent;
  final BillingFrequency billingFrequency;
  final int? depositMonths;
  final Money? bookingFee;
  final List<UnitRequirement> requirements;

  final String? propertyName;
  final String? buildingName;
  final String? floorName;

  /// Mutable: recomputed from bookings and leases (section 15).
  UnitStatus status;

  Unit toDomain() => Unit(
    id: id,
    propertyId: propertyId,
    buildingId: buildingId,
    floorId: floorId,
    unitTypeId: unitTypeId,
    unitNumber: unitNumber,
    unitCode: unitCode,
    name: name,
    description: description,
    length: length,
    width: width,
    area: area,
    areaUnit: areaUnit,
    baseRent: baseRent,
    billingFrequency: billingFrequency,
    status: status,
    depositMonths: depositMonths,
    bookingFee: bookingFee,
    requirements: requirements,
    propertyName: propertyName,
    buildingName: buildingName,
    floorName: floorName,
  );
}

// ---------------------------------------------------------------------------
// Bookings
// ---------------------------------------------------------------------------

class BookingRow {
  BookingRow({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.propertyId,
    required this.bookingReference,
    required this.monthlyRent,
    required this.depositAmount,
    required this.bookingFee,
    required this.status,
    required this.createdAt,
    required this.requirements,
    this.expiresAt,
    this.leaseId,
    this.bookingFeeInvoiceId,
    this.depositInvoiceId,
  });

  final String id;
  final String unitId;
  final String tenantId;
  final String propertyId;
  final String bookingReference;

  /// Immutable once written — section 21 requires the terms captured at booking
  /// time to survive later changes to the unit's pricing.
  final Money monthlyRent;
  final Money depositAmount;
  final Money bookingFee;

  final DateTime createdAt;
  final List<BookingRequirementRow> requirements;

  BookingStatus status;
  DateTime? expiresAt;
  String? leaseId;
  String? bookingFeeInvoiceId;
  String? depositInvoiceId;

  Booking toDomain({String? propertyName, String? unitNumber}) => Booking(
    id: id,
    unitId: unitId,
    tenantId: tenantId,
    propertyId: propertyId,
    propertyName: propertyName,
    unitNumber: unitNumber,
    bookingReference: bookingReference,
    monthlyRent: monthlyRent,
    depositAmount: depositAmount,
    bookingFee: bookingFee,
    expiresAt: expiresAt,
    status: status,
    createdAt: createdAt,
    leaseId: leaseId,
    bookingFeeInvoiceId: bookingFeeInvoiceId,
    depositInvoiceId: depositInvoiceId,
    requirements: requirements
        .map((r) => r.toDomain())
        .toList(growable: false),
  );
}

class BookingRequirementRow {
  BookingRequirementRow({
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
  final DocumentType? documentType;

  bool isSatisfied;
  String? documentId;
  DateTime? satisfiedAt;

  BookingRequirement toDomain() => BookingRequirement(
    id: id,
    requirementType: requirementType,
    name: name,
    description: description,
    isMandatory: isMandatory,
    isSatisfied: isSatisfied,
    documentType: documentType,
    documentId: documentId,
    satisfiedAt: satisfiedAt,
  );
}

// ---------------------------------------------------------------------------
// Leases
// ---------------------------------------------------------------------------

class LeaseRow {
  LeaseRow({
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
    this.propertyName,
    this.unitNumber,
    this.agreementVersion = 1,
    this.agreementDocumentId,
    this.signedAgreementDocumentId,
    this.signedAt,
    this.activatedAt,
    this.terminatedAt,
    List<LeaseSignature>? signatures,
    List<LeaseTerm>? terms,
  }) : signatures = signatures ?? <LeaseSignature>[],
       terms = terms ?? <LeaseTerm>[];

  final String id;
  final String leaseNumber;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? bookingId;
  final String? propertyName;
  final String? unitNumber;

  final DateTime startDate;
  final DateTime endDate;

  /// Section 55: never re-derived from the unit's current pricing.
  final Money monthlyRent;
  final Money depositAmount;
  final BillingFrequency billingFrequency;
  final int paymentDueDay;
  final DateTime createdAt;

  final List<LeaseSignature> signatures;
  final List<LeaseTerm> terms;

  LeaseStatus status;
  int agreementVersion;
  String? agreementDocumentId;
  String? signedAgreementDocumentId;
  DateTime? signedAt;
  DateTime? activatedAt;
  DateTime? terminatedAt;

  Lease toDomain({List<LeaseActivationCondition> conditions = const []}) =>
      Lease(
        id: id,
        leaseNumber: leaseNumber,
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        bookingId: bookingId,
        propertyName: propertyName,
        unitNumber: unitNumber,
        startDate: startDate,
        endDate: endDate,
        monthlyRent: monthlyRent,
        depositAmount: depositAmount,
        billingFrequency: billingFrequency,
        paymentDueDay: paymentDueDay,
        status: status,
        signedAt: signedAt,
        activatedAt: activatedAt,
        terminatedAt: terminatedAt,
        createdAt: createdAt,
        agreementDocumentId: agreementDocumentId,
        signedAgreementDocumentId: signedAgreementDocumentId,
        terms: terms,
        activationConditions: conditions,
        signatures: signatures,
      );
}

// ---------------------------------------------------------------------------
// Billing
// ---------------------------------------------------------------------------

/// Input to invoice creation. Only the mock server turns these into an
/// [Invoice], because only the server may total an invoice (section 84 rule 7).
class InvoiceLineDraft {
  const InvoiceLineDraft({
    required this.description,
    required this.amount,
    required this.lineType,
    this.quantity = 1,
    this.unitPrice,
    this.referenceId,
    this.taxable = true,
  });

  final String description;
  final Money amount;
  final InvoiceLineType lineType;
  final num quantity;
  final Money? unitPrice;
  final String? referenceId;

  /// Deposits are refundable and are not a supply, so they are not taxed.
  final bool taxable;
}

class InvoiceRow {
  InvoiceRow({
    required this.id,
    required this.invoiceNumber,
    required this.tenantId,
    required this.invoiceDate,
    required this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.amountDue,
    required this.currency,
    required this.status,
    required this.lines,
    this.leaseId,
    this.propertyId,
    this.unitId,
    this.propertyName,
    this.unitNumber,
    this.billingPeriodStart,
    this.billingPeriodEnd,
    this.documentId,
  });

  final String id;
  final String invoiceNumber;
  final String tenantId;
  final String? leaseId;
  final String? propertyId;
  final String? unitId;
  final String? propertyName;
  final String? unitNumber;

  final DateTime invoiceDate;
  final DateTime dueDate;
  final DateTime? billingPeriodStart;
  final DateTime? billingPeriodEnd;

  /// Frozen at issue. Section 84 rule 3 forbids modifying a paid invoice and
  /// rule 4 requires historical invoices to keep their original pricing, so
  /// these never change after creation.
  final Money subtotal;
  final Money tax;
  final Money discount;
  final Money total;
  final String currency;
  final List<InvoiceLine> lines;
  final String? documentId;

  /// Settlement progress does move, as payments are allocated (section 37).
  Money amountPaid;
  Money amountDue;
  InvoiceStatus status;

  Invoice toDomain() => Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    tenantId: tenantId,
    leaseId: leaseId,
    propertyId: propertyId,
    unitId: unitId,
    propertyName: propertyName,
    unitNumber: unitNumber,
    invoiceDate: invoiceDate,
    dueDate: dueDate,
    billingPeriodStart: billingPeriodStart,
    billingPeriodEnd: billingPeriodEnd,
    subtotal: subtotal,
    tax: tax,
    discount: discount,
    total: total,
    amountPaid: amountPaid,
    amountDue: amountDue,
    currency: currency,
    status: status,
    lines: lines,
    documentId: documentId,
  );
}

class PaymentRow {
  PaymentRow({
    required this.id,
    required this.paymentReference,
    required this.tenantId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.invoiceId,
    this.invoiceNumber,
    this.leaseId,
    this.propertyId,
    this.provider,
    this.providerTransactionId,
    this.paidAt,
    this.failureReason,
    this.receiptId,
    this.description,
    List<PaymentAllocation>? allocations,
  }) : allocations = allocations ?? <PaymentAllocation>[];

  final String id;
  final String paymentReference;
  final String tenantId;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? leaseId;
  final String? propertyId;

  /// Section 84 rule 1: a payment amount is never modified after the fact.
  final Money amount;
  final String currency;
  final PaymentMethod paymentMethod;
  final String? provider;
  final String? providerTransactionId;
  final DateTime createdAt;
  final String? description;
  final List<PaymentAllocation> allocations;

  PaymentStatus status;
  DateTime? paidAt;
  String? failureReason;
  String? receiptId;

  Payment toDomain() => Payment(
    id: id,
    paymentReference: paymentReference,
    tenantId: tenantId,
    invoiceId: invoiceId,
    invoiceNumber: invoiceNumber,
    leaseId: leaseId,
    propertyId: propertyId,
    amount: amount,
    currency: currency,
    paymentMethod: paymentMethod,
    provider: provider,
    providerTransactionId: providerTransactionId,
    status: status,
    paidAt: paidAt,
    createdAt: createdAt,
    failureReason: failureReason,
    receiptId: receiptId,
    description: description,
    allocations: allocations,
  );
}

// ---------------------------------------------------------------------------
// Notifications and ledger
// ---------------------------------------------------------------------------

class NotificationRow {
  NotificationRow({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.target = NotificationTarget.none,
    this.targetId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationTarget target;
  final String? targetId;

  bool isRead;

  NotificationItem toDomain() => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead,
    target: target,
    targetId: targetId,
  );
}

/// Section 42. A minimal ledger entry.
///
/// Not surfaced in the tenant app — a tenant has no business seeing the
/// platform's fee split. It exists so the mock records both sides of a
/// transaction as section 41 requires, rather than silently netting the fee
/// off, and so the behaviour is there to assert against.
class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.transactionType,
    required this.referenceType,
    required this.referenceId,
    required this.amount,
    required this.direction,
    required this.createdAt,
  });

  final String id;
  final String transactionType;
  final String referenceType;
  final String referenceId;
  final Money amount;
  final String direction;
  final DateTime createdAt;
}
