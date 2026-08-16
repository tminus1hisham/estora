/// Every enumeration the spec defines, transcribed verbatim.
///
/// Two rules govern this file:
///
/// 1. **No invented values** (section 96.1). If a value is not in the spec it
///    is not here. The one addition is an `unknown` member on each enum, which
///    exists purely so that a server rolling out a new status cannot crash an
///    older build — an unrecognised wire value degrades to `unknown` instead of
///    throwing during JSON parsing.
/// 2. **Wire format never leaks into widgets.** The API speaks
///    `PENDING_PAYMENT`; the UI shows `Pending payment`. `fromApi`/`toApi`
///    handle the former, `label` the latter.
library;

import '../../core/theme/status_palette.dart';

/// Shared parsing helper. Case-insensitive so a server that sends lowercase
/// still resolves.
T _parse<T>(String? raw, List<T> values, String Function(T) wire, T fallback) {
  if (raw == null) return fallback;
  final needle = raw.trim().toUpperCase();
  for (final value in values) {
    if (wire(value) == needle) return value;
  }
  return fallback;
}

// ---------------------------------------------------------------------------
// Section 11 - Property
// ---------------------------------------------------------------------------

enum PropertyType {
  mall,
  retailCenter,
  office,
  warehouse,
  businessCenter,
  mixedUse,
  other,
  unknown;

  String get api => switch (this) {
    PropertyType.mall => 'MALL',
    PropertyType.retailCenter => 'RETAIL_CENTER',
    PropertyType.office => 'OFFICE',
    PropertyType.warehouse => 'WAREHOUSE',
    PropertyType.businessCenter => 'BUSINESS_CENTER',
    PropertyType.mixedUse => 'MIXED_USE',
    PropertyType.other => 'OTHER',
    PropertyType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    PropertyType.mall => 'Mall',
    PropertyType.retailCenter => 'Retail centre',
    PropertyType.office => 'Office',
    PropertyType.warehouse => 'Warehouse',
    PropertyType.businessCenter => 'Business centre',
    PropertyType.mixedUse => 'Mixed use',
    PropertyType.other => 'Other',
    PropertyType.unknown => 'Property',
  };

  static PropertyType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, PropertyType.unknown);
}

enum PropertyStatus {
  active,
  inactive,
  underConstruction,
  archived,
  unknown;

  String get api => switch (this) {
    PropertyStatus.active => 'ACTIVE',
    PropertyStatus.inactive => 'INACTIVE',
    PropertyStatus.underConstruction => 'UNDER_CONSTRUCTION',
    PropertyStatus.archived => 'ARCHIVED',
    PropertyStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    PropertyStatus.active => 'Active',
    PropertyStatus.inactive => 'Inactive',
    PropertyStatus.underConstruction => 'Under construction',
    PropertyStatus.archived => 'Archived',
    PropertyStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    PropertyStatus.active => StatusTone.positive,
    PropertyStatus.underConstruction => StatusTone.warning,
    PropertyStatus.inactive ||
    PropertyStatus.archived ||
    PropertyStatus.unknown => StatusTone.neutral,
  };

  static PropertyStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, PropertyStatus.unknown);
}

// ---------------------------------------------------------------------------
// Section 15 - Unit status
// ---------------------------------------------------------------------------

enum UnitStatus {
  available,
  reserved,
  booked,
  leased,
  underMaintenance,
  unavailable,
  blocked,
  unknown;

  String get api => switch (this) {
    UnitStatus.available => 'AVAILABLE',
    UnitStatus.reserved => 'RESERVED',
    UnitStatus.booked => 'BOOKED',
    UnitStatus.leased => 'LEASED',
    UnitStatus.underMaintenance => 'UNDER_MAINTENANCE',
    UnitStatus.unavailable => 'UNAVAILABLE',
    UnitStatus.blocked => 'BLOCKED',
    UnitStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    UnitStatus.available => 'Available',
    UnitStatus.reserved => 'Reserved',
    UnitStatus.booked => 'Booked',
    UnitStatus.leased => 'Leased',
    UnitStatus.underMaintenance => 'Under maintenance',
    UnitStatus.unavailable => 'Unavailable',
    UnitStatus.blocked => 'Blocked',
    UnitStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    UnitStatus.available => StatusTone.positive,
    UnitStatus.reserved || UnitStatus.booked => StatusTone.progress,
    UnitStatus.leased => StatusTone.info,
    UnitStatus.underMaintenance => StatusTone.warning,
    UnitStatus.unavailable ||
    UnitStatus.blocked ||
    UnitStatus.unknown => StatusTone.neutral,
  };

  /// Whether a tenant may start a booking.
  ///
  /// This is a *display* affordance only — it decides whether the button is
  /// enabled. Section 48 requires the real availability check to happen inside
  /// a locking transaction on the server, so a booking attempt on a unit that
  /// went stale still has to be able to come back with a conflict.
  bool get isBookable => this == UnitStatus.available;

  static UnitStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, UnitStatus.unknown);
}

// ---------------------------------------------------------------------------
// Section 21 / 81 - Booking lifecycle
// ---------------------------------------------------------------------------

enum BookingStatus {
  draft,
  pendingPayment,
  paymentPending,
  active,
  expired,
  cancelled,
  convertedToLease,
  rejected,
  unknown;

  String get api => switch (this) {
    BookingStatus.draft => 'DRAFT',
    BookingStatus.pendingPayment => 'PENDING_PAYMENT',
    BookingStatus.paymentPending => 'PAYMENT_PENDING',
    BookingStatus.active => 'ACTIVE',
    BookingStatus.expired => 'EXPIRED',
    BookingStatus.cancelled => 'CANCELLED',
    BookingStatus.convertedToLease => 'CONVERTED_TO_LEASE',
    BookingStatus.rejected => 'REJECTED',
    BookingStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    BookingStatus.draft => 'Draft',
    BookingStatus.pendingPayment => 'Awaiting payment',
    BookingStatus.paymentPending => 'Payment processing',
    BookingStatus.active => 'Active',
    BookingStatus.expired => 'Expired',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.convertedToLease => 'Converted to lease',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    BookingStatus.active => StatusTone.positive,
    BookingStatus.pendingPayment ||
    BookingStatus.paymentPending => StatusTone.progress,
    BookingStatus.draft => StatusTone.warning,
    BookingStatus.rejected => StatusTone.danger,
    BookingStatus.convertedToLease => StatusTone.info,
    BookingStatus.expired ||
    BookingStatus.cancelled ||
    BookingStatus.unknown => StatusTone.neutral,
  };

  /// No further transitions are possible from here.
  bool get isTerminal => switch (this) {
    BookingStatus.expired ||
    BookingStatus.cancelled ||
    BookingStatus.rejected ||
    BookingStatus.convertedToLease => true,
    _ => false,
  };

  /// Whether the expiry countdown from section 23 should be shown.
  bool get isCountingDown => this == BookingStatus.active;

  /// Whether the booking fee is still outstanding (section 24).
  bool get awaitsBookingFee => switch (this) {
    BookingStatus.draft ||
    BookingStatus.pendingPayment ||
    BookingStatus.paymentPending => true,
    _ => false,
  };

  static BookingStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, BookingStatus.unknown);
}

// ---------------------------------------------------------------------------
// Section 26 / 81 - Lease lifecycle
// ---------------------------------------------------------------------------

enum LeaseStatus {
  draft,
  pendingSignature,
  partiallySigned,
  signed,
  active,
  expiring,
  expired,
  terminated,
  cancelled,
  unknown;

  String get api => switch (this) {
    LeaseStatus.draft => 'DRAFT',
    LeaseStatus.pendingSignature => 'PENDING_SIGNATURE',
    LeaseStatus.partiallySigned => 'PARTIALLY_SIGNED',
    LeaseStatus.signed => 'SIGNED',
    LeaseStatus.active => 'ACTIVE',
    LeaseStatus.expiring => 'EXPIRING',
    LeaseStatus.expired => 'EXPIRED',
    LeaseStatus.terminated => 'TERMINATED',
    LeaseStatus.cancelled => 'CANCELLED',
    LeaseStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    LeaseStatus.draft => 'Draft',
    LeaseStatus.pendingSignature => 'Awaiting signature',
    LeaseStatus.partiallySigned => 'Partially signed',
    LeaseStatus.signed => 'Signed',
    LeaseStatus.active => 'Active',
    LeaseStatus.expiring => 'Expiring soon',
    LeaseStatus.expired => 'Expired',
    LeaseStatus.terminated => 'Terminated',
    LeaseStatus.cancelled => 'Cancelled',
    LeaseStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    LeaseStatus.active => StatusTone.positive,
    LeaseStatus.pendingSignature ||
    LeaseStatus.partiallySigned => StatusTone.progress,
    LeaseStatus.signed => StatusTone.info,
    LeaseStatus.draft || LeaseStatus.expiring => StatusTone.warning,
    LeaseStatus.terminated => StatusTone.danger,
    LeaseStatus.expired ||
    LeaseStatus.cancelled ||
    LeaseStatus.unknown => StatusTone.neutral,
  };

  /// The tenant still owes a signature (section 29).
  bool get needsTenantSignature => switch (this) {
    LeaseStatus.pendingSignature || LeaseStatus.partiallySigned => true,
    _ => false,
  };

  /// The lease is live, so invoices are being generated against it.
  bool get isCurrent => switch (this) {
    LeaseStatus.active || LeaseStatus.expiring => true,
    _ => false,
  };

  static LeaseStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, LeaseStatus.unknown);
}

// ---------------------------------------------------------------------------
// Section 32 / 81 - Invoice lifecycle
// ---------------------------------------------------------------------------

enum InvoiceStatus {
  draft,
  issued,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
  invoiceVoid,
  unknown;

  String get api => switch (this) {
    InvoiceStatus.draft => 'DRAFT',
    InvoiceStatus.issued => 'ISSUED',
    InvoiceStatus.partiallyPaid => 'PARTIALLY_PAID',
    InvoiceStatus.paid => 'PAID',
    InvoiceStatus.overdue => 'OVERDUE',
    InvoiceStatus.cancelled => 'CANCELLED',
    // `void` is a Dart keyword, hence the member name. The wire value is
    // unaffected.
    InvoiceStatus.invoiceVoid => 'VOID',
    InvoiceStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.issued => 'Issued',
    InvoiceStatus.partiallyPaid => 'Partially paid',
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.overdue => 'Overdue',
    InvoiceStatus.cancelled => 'Cancelled',
    InvoiceStatus.invoiceVoid => 'Void',
    InvoiceStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    InvoiceStatus.paid => StatusTone.positive,
    InvoiceStatus.issued => StatusTone.info,
    InvoiceStatus.partiallyPaid || InvoiceStatus.draft => StatusTone.warning,
    InvoiceStatus.overdue => StatusTone.danger,
    InvoiceStatus.cancelled ||
    InvoiceStatus.invoiceVoid ||
    InvoiceStatus.unknown => StatusTone.neutral,
  };

  /// Whether the tenant can pay this invoice.
  bool get isPayable => switch (this) {
    InvoiceStatus.issued ||
    InvoiceStatus.partiallyPaid ||
    InvoiceStatus.overdue => true,
    _ => false,
  };

  /// Counts toward the tenant's outstanding balance.
  bool get isOutstanding => isPayable;

  static InvoiceStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, InvoiceStatus.unknown);
}

// ---------------------------------------------------------------------------
// Section 33 - Invoice line types
// ---------------------------------------------------------------------------

enum InvoiceLineType {
  rent,
  deposit,
  bookingFee,
  serviceCharge,
  electricity,
  water,
  internet,
  parking,
  lateFee,
  other,
  unknown;

  String get api => switch (this) {
    InvoiceLineType.rent => 'RENT',
    InvoiceLineType.deposit => 'DEPOSIT',
    InvoiceLineType.bookingFee => 'BOOKING_FEE',
    InvoiceLineType.serviceCharge => 'SERVICE_CHARGE',
    InvoiceLineType.electricity => 'ELECTRICITY',
    InvoiceLineType.water => 'WATER',
    InvoiceLineType.internet => 'INTERNET',
    InvoiceLineType.parking => 'PARKING',
    InvoiceLineType.lateFee => 'LATE_FEE',
    InvoiceLineType.other => 'OTHER',
    InvoiceLineType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    InvoiceLineType.rent => 'Rent',
    InvoiceLineType.deposit => 'Deposit',
    InvoiceLineType.bookingFee => 'Booking fee',
    InvoiceLineType.serviceCharge => 'Service charge',
    InvoiceLineType.electricity => 'Electricity',
    InvoiceLineType.water => 'Water',
    InvoiceLineType.internet => 'Internet',
    InvoiceLineType.parking => 'Parking',
    InvoiceLineType.lateFee => 'Late fee',
    InvoiceLineType.other => 'Other',
    InvoiceLineType.unknown => 'Other',
  };

  static InvoiceLineType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, InvoiceLineType.unknown);
}

// ---------------------------------------------------------------------------
// Section 36 / 81 - Payment
// ---------------------------------------------------------------------------

enum PaymentStatus {
  pending,
  processing,
  success,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
  unknown;

  String get api => switch (this) {
    PaymentStatus.pending => 'PENDING',
    PaymentStatus.processing => 'PROCESSING',
    PaymentStatus.success => 'SUCCESS',
    PaymentStatus.failed => 'FAILED',
    PaymentStatus.cancelled => 'CANCELLED',
    PaymentStatus.refunded => 'REFUNDED',
    PaymentStatus.partiallyRefunded => 'PARTIALLY_REFUNDED',
    PaymentStatus.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    PaymentStatus.pending => 'Pending',
    PaymentStatus.processing => 'Processing',
    PaymentStatus.success => 'Successful',
    PaymentStatus.failed => 'Failed',
    PaymentStatus.cancelled => 'Cancelled',
    PaymentStatus.refunded => 'Refunded',
    PaymentStatus.partiallyRefunded => 'Partially refunded',
    PaymentStatus.unknown => 'Unknown',
  };

  StatusTone get tone => switch (this) {
    PaymentStatus.success => StatusTone.positive,
    PaymentStatus.pending || PaymentStatus.processing => StatusTone.progress,
    PaymentStatus.failed => StatusTone.danger,
    PaymentStatus.refunded ||
    PaymentStatus.partiallyRefunded => StatusTone.warning,
    PaymentStatus.cancelled || PaymentStatus.unknown => StatusTone.neutral,
  };

  /// The payment has settled one way or the other and polling should stop.
  ///
  /// Section 39 is explicit that the handset must not decide a payment
  /// succeeded — the app polls until the *server* reports one of these.
  bool get isTerminal => switch (this) {
    PaymentStatus.success ||
    PaymentStatus.failed ||
    PaymentStatus.cancelled ||
    PaymentStatus.refunded ||
    PaymentStatus.partiallyRefunded => true,
    _ => false,
  };

  bool get isInFlight => !isTerminal && this != PaymentStatus.unknown;

  static PaymentStatus fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, PaymentStatus.unknown);
}

enum PaymentMethod {
  mpesa,
  card,
  bankTransfer,
  cash,
  cheque,
  other,
  unknown;

  String get api => switch (this) {
    PaymentMethod.mpesa => 'MPESA',
    PaymentMethod.card => 'CARD',
    PaymentMethod.bankTransfer => 'BANK_TRANSFER',
    PaymentMethod.cash => 'CASH',
    PaymentMethod.cheque => 'CHEQUE',
    PaymentMethod.other => 'OTHER',
    PaymentMethod.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    PaymentMethod.mpesa => 'M-Pesa',
    PaymentMethod.card => 'Card',
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.cash => 'Cash',
    PaymentMethod.cheque => 'Cheque',
    PaymentMethod.other => 'Other',
    PaymentMethod.unknown => 'Unknown',
  };

  /// Methods a tenant can initiate from the handset. Cash and cheque are
  /// recorded by the property manager in the web app, not paid in-app.
  static List<PaymentMethod> get tenantSelectable => const [
    PaymentMethod.mpesa,
    PaymentMethod.card,
    PaymentMethod.bankTransfer,
  ];

  static PaymentMethod fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, PaymentMethod.unknown);
}

// ---------------------------------------------------------------------------
// Section 19 - Billing frequency
// ---------------------------------------------------------------------------

enum BillingFrequency {
  monthly,
  quarterly,
  yearly,
  custom,
  unknown;

  String get api => switch (this) {
    BillingFrequency.monthly => 'MONTHLY',
    BillingFrequency.quarterly => 'QUARTERLY',
    BillingFrequency.yearly => 'YEARLY',
    BillingFrequency.custom => 'CUSTOM',
    BillingFrequency.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    BillingFrequency.monthly => 'Monthly',
    BillingFrequency.quarterly => 'Quarterly',
    BillingFrequency.yearly => 'Yearly',
    BillingFrequency.custom => 'Custom',
    BillingFrequency.unknown => 'Unknown',
  };

  /// Suffix for a rent figure, e.g. `KES 150,000 / month`.
  String get perPeriod => switch (this) {
    BillingFrequency.monthly => '/ month',
    BillingFrequency.quarterly => '/ quarter',
    BillingFrequency.yearly => '/ year',
    BillingFrequency.custom || BillingFrequency.unknown => '',
  };

  static BillingFrequency fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, BillingFrequency.unknown);
}

// ---------------------------------------------------------------------------
// Section 18 - Unit requirements
// ---------------------------------------------------------------------------

enum RequirementType {
  document,
  payment,
  approval,
  custom,
  unknown;

  String get api => switch (this) {
    RequirementType.document => 'DOCUMENT',
    RequirementType.payment => 'PAYMENT',
    RequirementType.approval => 'APPROVAL',
    RequirementType.custom => 'CUSTOM',
    RequirementType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    RequirementType.document => 'Document',
    RequirementType.payment => 'Payment',
    RequirementType.approval => 'Approval',
    RequirementType.custom => 'Requirement',
    RequirementType.unknown => 'Requirement',
  };

  static RequirementType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, RequirementType.unknown);
}

// ---------------------------------------------------------------------------
// Section 20 - Tenant
// ---------------------------------------------------------------------------

enum TenantType {
  individual,
  business,
  corporate,
  unknown;

  String get api => switch (this) {
    TenantType.individual => 'INDIVIDUAL',
    TenantType.business => 'BUSINESS',
    TenantType.corporate => 'CORPORATE',
    TenantType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    TenantType.individual => 'Individual',
    TenantType.business => 'Business',
    TenantType.corporate => 'Corporate',
    TenantType.unknown => 'Unknown',
  };

  /// Whether the profile form should collect company fields (registration
  /// number, tax number) rather than personal identity fields.
  bool get isOrganisation => switch (this) {
    TenantType.business || TenantType.corporate => true,
    _ => false,
  };

  static TenantType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, TenantType.unknown);
}

// ---------------------------------------------------------------------------
// Section 9 - Account role
// ---------------------------------------------------------------------------

/// Which side of the platform an account is on.
///
/// The app serves two audiences off one sign-in. A tenant leases space; an
/// owner lets it. The distinction gates navigation only — it is read once, in
/// the router's redirect, and decides which shell an account lands in.
///
/// Section 88 lists property owners as Phase 3. This is the first of that work.
enum AccountRole {
  tenant,
  owner,
  unknown;

  String get api => switch (this) {
    AccountRole.tenant => 'TENANT',
    AccountRole.owner => 'OWNER',
    AccountRole.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    AccountRole.tenant => 'Tenant',
    AccountRole.owner => 'Owner',
    AccountRole.unknown => 'Unknown',
  };

  /// An unrecognised role is treated as a tenant rather than locked out. A
  /// server that grows a third role should not strand an account on a version
  /// of the app that predates it.
  bool get isOwner => this == AccountRole.owner;

  static AccountRole fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, AccountRole.unknown);
}

// ---------------------------------------------------------------------------
// Section 88 - Property owner
// ---------------------------------------------------------------------------

enum OwnerType {
  individual,
  company,
  unknown;

  String get api => switch (this) {
    OwnerType.individual => 'INDIVIDUAL',
    OwnerType.company => 'COMPANY',
    OwnerType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    OwnerType.individual => 'Individual',
    OwnerType.company => 'Company',
    OwnerType.unknown => 'Unknown',
  };

  /// Whether the profile form should collect company fields, mirroring
  /// [TenantType.isOrganisation].
  bool get isOrganisation => this == OwnerType.company;

  static OwnerType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, OwnerType.unknown);
}

/// What is asking for an owner's attention, and how loudly.
enum OwnerAlertType {
  arrears,
  leaseExpiring,
  vacancy,
  awaitingSignature,
  unknown;

  String get api => switch (this) {
    OwnerAlertType.arrears => 'ARREARS',
    OwnerAlertType.leaseExpiring => 'LEASE_EXPIRING',
    OwnerAlertType.vacancy => 'VACANCY',
    OwnerAlertType.awaitingSignature => 'AWAITING_SIGNATURE',
    OwnerAlertType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    OwnerAlertType.arrears => 'In arrears',
    OwnerAlertType.leaseExpiring => 'Expiring',
    OwnerAlertType.vacancy => 'Vacant',
    OwnerAlertType.awaitingSignature => 'Awaiting signature',
    OwnerAlertType.unknown => 'Attention',
  };

  StatusTone get tone => switch (this) {
    OwnerAlertType.arrears => StatusTone.danger,
    OwnerAlertType.leaseExpiring => StatusTone.warning,
    OwnerAlertType.vacancy => StatusTone.neutral,
    OwnerAlertType.awaitingSignature => StatusTone.progress,
    OwnerAlertType.unknown => StatusTone.neutral,
  };

  static OwnerAlertType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, OwnerAlertType.unknown);
}

// ---------------------------------------------------------------------------
// Section 29 - Lease signatures
// ---------------------------------------------------------------------------

enum SignatureType {
  drawnSignature,
  uploadedSignature,
  otpSignature,
  eSignatureProvider,
  unknown;

  String get api => switch (this) {
    SignatureType.drawnSignature => 'DRAWN_SIGNATURE',
    SignatureType.uploadedSignature => 'UPLOADED_SIGNATURE',
    SignatureType.otpSignature => 'OTP_SIGNATURE',
    SignatureType.eSignatureProvider => 'E_SIGNATURE_PROVIDER',
    SignatureType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    SignatureType.drawnSignature => 'Drawn signature',
    SignatureType.uploadedSignature => 'Uploaded signature',
    SignatureType.otpSignature => 'OTP signature',
    SignatureType.eSignatureProvider => 'E-signature provider',
    SignatureType.unknown => 'Signature',
  };

  static SignatureType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, SignatureType.unknown);
}

// ---------------------------------------------------------------------------
// Section 51 - Documents
// ---------------------------------------------------------------------------

enum DocumentType {
  leaseAgreement,
  signedLease,
  receipt,
  invoice,
  tenantId,
  businessRegistration,
  taxCertificate,
  other,
  unknown;

  String get api => switch (this) {
    DocumentType.leaseAgreement => 'LEASE_AGREEMENT',
    DocumentType.signedLease => 'SIGNED_LEASE',
    DocumentType.receipt => 'RECEIPT',
    DocumentType.invoice => 'INVOICE',
    DocumentType.tenantId => 'TENANT_ID',
    DocumentType.businessRegistration => 'BUSINESS_REGISTRATION',
    DocumentType.taxCertificate => 'TAX_CERTIFICATE',
    DocumentType.other => 'OTHER',
    DocumentType.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    DocumentType.leaseAgreement => 'Lease agreement',
    DocumentType.signedLease => 'Signed lease',
    DocumentType.receipt => 'Receipt',
    DocumentType.invoice => 'Invoice',
    DocumentType.tenantId => 'National ID',
    DocumentType.businessRegistration => 'Business registration',
    DocumentType.taxCertificate => 'Tax certificate',
    DocumentType.other => 'Other',
    DocumentType.unknown => 'Document',
  };

  /// Documents the tenant uploads, as opposed to ones the platform generates.
  static List<DocumentType> get tenantUploadable => const [
    DocumentType.tenantId,
    DocumentType.businessRegistration,
    DocumentType.taxCertificate,
    DocumentType.other,
  ];

  static DocumentType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, DocumentType.unknown);
}

// ---------------------------------------------------------------------------
// Section 49 - Notifications
// ---------------------------------------------------------------------------

enum NotificationType {
  bookingCreated,
  bookingExpiring,
  bookingExpired,
  paymentSuccess,
  paymentFailed,
  invoiceGenerated,
  invoiceDue,
  invoiceOverdue,
  leaseReady,
  leaseSigned,
  leaseActivated,
  leaseExpiring,
  documentRequired,
  unknown;

  String get api => switch (this) {
    NotificationType.bookingCreated => 'BOOKING_CREATED',
    NotificationType.bookingExpiring => 'BOOKING_EXPIRING',
    NotificationType.bookingExpired => 'BOOKING_EXPIRED',
    NotificationType.paymentSuccess => 'PAYMENT_SUCCESS',
    NotificationType.paymentFailed => 'PAYMENT_FAILED',
    NotificationType.invoiceGenerated => 'INVOICE_GENERATED',
    NotificationType.invoiceDue => 'INVOICE_DUE',
    NotificationType.invoiceOverdue => 'INVOICE_OVERDUE',
    NotificationType.leaseReady => 'LEASE_READY',
    NotificationType.leaseSigned => 'LEASE_SIGNED',
    NotificationType.leaseActivated => 'LEASE_ACTIVATED',
    NotificationType.leaseExpiring => 'LEASE_EXPIRING',
    NotificationType.documentRequired => 'DOCUMENT_REQUIRED',
    NotificationType.unknown => 'UNKNOWN',
  };

  static NotificationType fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, NotificationType.unknown);
}

/// What a notification points at, so tapping it can deep-link.
enum NotificationTarget { booking, lease, invoice, payment, document, none }

// ---------------------------------------------------------------------------
// Section 49 - Notification channels
// ---------------------------------------------------------------------------

enum NotificationChannel {
  push,
  sms,
  email,
  inApp,
  unknown;

  String get api => switch (this) {
    NotificationChannel.push => 'PUSH',
    NotificationChannel.sms => 'SMS',
    NotificationChannel.email => 'EMAIL',
    NotificationChannel.inApp => 'IN_APP',
    NotificationChannel.unknown => 'UNKNOWN',
  };

  String get label => switch (this) {
    NotificationChannel.push => 'Push notifications',
    NotificationChannel.sms => 'SMS',
    NotificationChannel.email => 'Email',
    NotificationChannel.inApp => 'In-app',
    NotificationChannel.unknown => 'Unknown',
  };

  static NotificationChannel fromApi(String? raw) =>
      _parse(raw, values, (v) => v.api, NotificationChannel.unknown);
}
