/// JSON to domain mapping.
///
/// These functions define the wire contract the app expects from the API in
/// section 64. They are the only place that knows about JSON key names, so a
/// change in the response shape is a change in one file.
///
/// Conventions assumed of the API, per section 65's call for consistent
/// formats:
///
/// * Successful responses wrap the payload in `data`, with list responses
///   carrying `meta: { page, pageSize, total }`.
/// * Money fields arrive as major-unit numbers or decimal strings alongside a
///   sibling `currency`; both forms are parsed through [Money.fromJson].
/// * Timestamps are ISO-8601 in UTC.
/// * Enum fields arrive as the spec's SCREAMING_SNAKE strings, and an
///   unrecognised value degrades to the enum's `unknown` member rather than
///   throwing — a new server status must not crash an older build.
library;

import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../json.dart';

export '../json.dart' show Json;

// -- Primitive helpers -------------------------------------------------------

String _str(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;

String? _strOrNull(Object? value) {
  final text = value?.toString();
  return (text == null || text.isEmpty) ? null : text;
}

int _int(Object? value, [int fallback = 0]) => switch (value) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v) ?? fallback,
  _ => fallback,
};

int? _intOrNull(Object? value) => value == null ? null : _int(value);

double? _doubleOrNull(Object? value) => switch (value) {
  num v => v.toDouble(),
  String v => double.tryParse(v),
  _ => null,
};

bool _bool(Object? value, [bool fallback = false]) => switch (value) {
  bool v => v,
  String v => v.toLowerCase() == 'true',
  num v => v != 0,
  _ => fallback,
};

DateTime _date(Object? value) =>
    DateTime.tryParse(_str(value))?.toLocal() ?? DateTime.now();

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// Reads a money field, defaulting the currency from the enclosing object.
Money _money(Json json, String key, String currency) =>
    Money.fromJson(json[key], _str(json['currency'], currency));

List<Json> _list(Object? value) => switch (value) {
  List list => list.whereType<Json>().toList(growable: false),
  _ => const <Json>[],
};

/// Unwraps `{ "data": ..., "meta": ... }` into a [Page].
Page<T> pageFromJson<T>(Json json, T Function(Json) item) {
  final meta = json['meta'] as Json? ?? const {};
  final items = _list(json['data']).map(item).toList(growable: false);
  return Page(
    items: items,
    page: _int(meta['page'], 1),
    pageSize: _int(meta['pageSize'], items.length),
    total: _int(meta['total'], items.length),
  );
}

// -- Property ----------------------------------------------------------------

Property propertyFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Property(
    id: _str(json['id']),
    name: _str(json['name']),
    code: _str(json['code']),
    propertyType: PropertyType.fromApi(_strOrNull(json['propertyType'])),
    status: PropertyStatus.fromApi(_strOrNull(json['status'])),
    description: _strOrNull(json['description']),
    address: _strOrNull(json['address']),
    city: _str(json['city']),
    county: _strOrNull(json['county'] ?? json['state']),
    country: _str(json['country']),
    latitude: _doubleOrNull(json['latitude']),
    longitude: _doubleOrNull(json['longitude']),
    totalArea: _doubleOrNull(json['totalArea']),
    totalUnits: _intOrNull(json['totalUnits']),
    availableUnits: _intOrNull(json['availableUnits']),
    ownerId: _strOrNull(json['ownerId']),
    rentRatePerSqm: json['rentRatePerSqm'] == null
        ? null
        : _money(json, 'rentRatePerSqm', currency),
    logoUrl: _strOrNull(json['logo'] ?? json['logoUrl']),
    imageUrl: _strOrNull(json['imageUrl']),
  );
}

Building buildingFromJson(Json json) => Building(
  id: _str(json['id']),
  propertyId: _str(json['propertyId']),
  name: _str(json['name']),
  code: _str(json['code']),
  description: _strOrNull(json['description']),
);

Floor floorFromJson(Json json) => Floor(
  id: _str(json['id']),
  buildingId: _str(json['buildingId']),
  name: _str(json['name']),
  floorNumber: _int(json['floorNumber']),
  description: _strOrNull(json['description']),
);

// -- Unit --------------------------------------------------------------------

Unit unitFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Unit(
    id: _str(json['id']),
    propertyId: _str(json['propertyId']),
    buildingId: _strOrNull(json['buildingId']),
    floorId: _strOrNull(json['floorId']),
    unitTypeId: _strOrNull(json['unitTypeId']),
    unitNumber: _str(json['unitNumber']),
    unitCode: _str(json['unitCode']),
    name: _strOrNull(json['name']),
    description: _strOrNull(json['description']),
    length: _doubleOrNull(json['length']),
    width: _doubleOrNull(json['width']),
    area: _doubleOrNull(json['area']),
    areaUnit: _str(json['areaUnit'], 'm²'),
    baseRent: _money(json, 'baseRent', currency),
    billingFrequency: BillingFrequency.fromApi(
      _strOrNull(json['billingFrequency']),
    ),
    status: UnitStatus.fromApi(_strOrNull(json['status'])),
    depositMonths: _intOrNull(json['depositMonths']),
    bookingFee: json['bookingFee'] == null
        ? null
        : _money(json, 'bookingFee', currency),
    ratePerSqm: json['ratePerSqm'] == null
        ? null
        : _money(json, 'ratePerSqm', currency),
    rentOverridden: _bool(json['rentOverridden']),
    requirements: _list(
      json['requirements'],
    ).map(unitRequirementFromJson).toList(growable: false),
    propertyName: _strOrNull(json['propertyName']),
    buildingName: _strOrNull(json['buildingName']),
    floorName: _strOrNull(json['floorName']),
    imageUrls: _list(json['images'])
        .map((i) => _str(i['url']))
        .where((url) => url.isNotEmpty)
        .toList(growable: false),
  );
}

UnitRequirement unitRequirementFromJson(Json json) => UnitRequirement(
  id: _str(json['id']),
  unitId: _str(json['unitId']),
  requirementType: RequirementType.fromApi(_strOrNull(json['requirementType'])),
  name: _str(json['name']),
  description: _strOrNull(json['description']),
  isMandatory: _bool(json['isMandatory']),
  value: _strOrNull(json['value']),
  isSatisfied: _bool(json['isSatisfied']),
  documentType: json['documentType'] == null
      ? null
      : DocumentType.fromApi(_strOrNull(json['documentType'])),
);

UnitType unitTypeFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return UnitType(
    id: _str(json['id']),
    propertyId: _str(json['propertyId']),
    name: _str(json['name']),
    code: _str(json['code']),
    description: _strOrNull(json['description']),
    length: _doubleOrNull(json['length']),
    width: _doubleOrNull(json['width']),
    area: _doubleOrNull(json['area']),
    baseRent: _money(json, 'baseRent', currency),
    defaultDepositMonths: _intOrNull(json['defaultDepositMonths']),
    defaultBookingFee: json['defaultBookingFee'] == null
        ? null
        : _money(json, 'defaultBookingFee', currency),
    ratePerSqm: json['ratePerSqm'] == null
        ? null
        : _money(json, 'ratePerSqm', currency),
  );
}

UnitPricing unitPricingFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return UnitPricing(
    id: _str(json['id']),
    unitId: _str(json['unitId']),
    billingFrequency: BillingFrequency.fromApi(
      _strOrNull(json['billingFrequency']),
    ),
    amount: _money(json, 'amount', currency),
    effectiveFrom: _date(json['effectiveFrom']),
    effectiveTo: _dateOrNull(json['effectiveTo']),
    isActive: _bool(json['isActive']),
  );
}

// -- Booking -----------------------------------------------------------------

Booking bookingFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Booking(
    id: _str(json['id']),
    unitId: _str(json['unitId']),
    tenantId: _str(json['tenantId']),
    propertyId: _strOrNull(json['propertyId']),
    propertyName: _strOrNull(json['propertyName']),
    unitNumber: _strOrNull(json['unitNumber']),
    bookingReference: _str(json['bookingReference']),
    // Section 21: these are the terms the server captured at booking time.
    // Rendered as received; never recomputed from the unit's current pricing.
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    bookingFee: _money(json, 'bookingFee', currency),
    expiresAt: _dateOrNull(json['expiresAt']),
    status: BookingStatus.fromApi(_strOrNull(json['status'])),
    createdAt: _date(json['createdAt']),
    leaseId: _strOrNull(json['leaseId']),
    bookingFeeInvoiceId: _strOrNull(json['bookingFeeInvoiceId']),
    depositInvoiceId: _strOrNull(json['depositInvoiceId']),
    requirements: _list(
      json['requirements'],
    ).map(bookingRequirementFromJson).toList(growable: false),
  );
}

BookingRequirement bookingRequirementFromJson(Json json) => BookingRequirement(
  id: _str(json['id']),
  requirementType: RequirementType.fromApi(_strOrNull(json['requirementType'])),
  name: _str(json['name']),
  description: _strOrNull(json['description']),
  isMandatory: _bool(json['isMandatory']),
  isSatisfied: _bool(json['isSatisfied']),
  documentType: json['documentType'] == null
      ? null
      : DocumentType.fromApi(_strOrNull(json['documentType'])),
  documentId: _strOrNull(json['documentId']),
  satisfiedAt: _dateOrNull(json['satisfiedAt']),
);

BookingQuote bookingQuoteFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return BookingQuote(
    unitId: _str(json['unitId']),
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    bookingFee: _money(json, 'bookingFee', currency),
    taxAmount: json['taxAmount'] == null
        ? null
        : _money(json, 'taxAmount', currency),
    taxLabel: _strOrNull(json['taxLabel']),
    // Section 65: the payable total is the server's figure, taken verbatim.
    total: _money(json, 'total', currency),
    currency: currency,
    depositMonths: _intOrNull(json['depositMonths']),
    expiryHours: _int(json['expiryHours'], 48),
    requirements: _list(json['requirements'])
        .map(
          (r) => UnitRequirementSummary(
            name: _str(r['name']),
            description: _strOrNull(r['description']),
            requirementType: RequirementType.fromApi(
              _strOrNull(r['requirementType']),
            ),
            isMandatory: _bool(r['isMandatory']),
          ),
        )
        .toList(growable: false),
  );
}

// -- Lease -------------------------------------------------------------------

Lease leaseFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Lease(
    id: _str(json['id']),
    leaseNumber: _str(json['leaseNumber']),
    propertyId: _str(json['propertyId']),
    unitId: _str(json['unitId']),
    tenantId: _str(json['tenantId']),
    bookingId: _strOrNull(json['bookingId']),
    propertyName: _strOrNull(json['propertyName']),
    unitNumber: _strOrNull(json['unitNumber']),
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    billingFrequency: BillingFrequency.fromApi(
      _strOrNull(json['billingFrequency']),
    ),
    paymentDueDay: _int(json['paymentDueDay'], 1),
    status: LeaseStatus.fromApi(_strOrNull(json['status'])),
    signedAt: _dateOrNull(json['signedAt']),
    activatedAt: _dateOrNull(json['activatedAt']),
    terminatedAt: _dateOrNull(json['terminatedAt']),
    createdAt: _date(json['createdAt']),
    agreementDocumentId: _strOrNull(json['agreementDocumentId']),
    signedAgreementDocumentId: _strOrNull(json['signedAgreementDocumentId']),
    terms: _list(json['terms'])
        .map(
          (t) => LeaseTerm(
            id: _str(t['id']),
            label: _str(t['label']),
            value: _str(t['value']),
            description: _strOrNull(t['description']),
            group: _strOrNull(t['group']),
          ),
        )
        .toList(growable: false),
    activationConditions: _list(json['activationConditions'])
        .map(
          (c) => LeaseActivationCondition(
            id: _str(c['id']),
            label: _str(c['label']),
            detail: _strOrNull(c['detail']),
            isMet: _bool(c['isMet']),
            isMandatory: _bool(c['isMandatory'], true),
          ),
        )
        .toList(growable: false),
    signatures: _list(
      json['signatures'],
    ).map(leaseSignatureFromJson).toList(growable: false),
  );
}

LeaseSignature leaseSignatureFromJson(Json json) => LeaseSignature(
  id: _str(json['id']),
  leaseId: _str(json['leaseId']),
  userId: _strOrNull(json['userId']),
  signerName: _strOrNull(json['signerName']),
  signatureType: SignatureType.fromApi(_strOrNull(json['signatureType'])),
  signedAt: _date(json['signedAt']),
  documentHash: _strOrNull(json['documentHash']),
);

LeaseAgreement leaseAgreementFromJson(Json json) => LeaseAgreement(
  leaseId: _str(json['leaseId']),
  // Section 29: bound back to the signature so it is provable which version
  // was agreed to.
  documentHash: _str(json['documentHash']),
  version: _int(json['version'], 1),
  generatedAt: _date(json['generatedAt']),
  body: _strOrNull(json['body']),
  documentId: _strOrNull(json['documentId']),
  pdfUrl: _strOrNull(json['pdfUrl']),
);

// -- Billing -----------------------------------------------------------------

Invoice invoiceFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Invoice(
    id: _str(json['id']),
    invoiceNumber: _str(json['invoiceNumber']),
    tenantId: _str(json['tenantId']),
    leaseId: _strOrNull(json['leaseId']),
    propertyId: _strOrNull(json['propertyId']),
    unitId: _strOrNull(json['unitId']),
    propertyName: _strOrNull(json['propertyName']),
    unitNumber: _strOrNull(json['unitNumber']),
    invoiceDate: _date(json['invoiceDate']),
    dueDate: _date(json['dueDate']),
    billingPeriodStart: _dateOrNull(json['billingPeriodStart']),
    billingPeriodEnd: _dateOrNull(json['billingPeriodEnd']),
    // Section 84 rules 4 and 7: every figure below is the server's, frozen at
    // issue. Nothing here re-derives a total from the lines.
    subtotal: _money(json, 'subtotal', currency),
    tax: _money(json, 'tax', currency),
    discount: _money(json, 'discount', currency),
    total: _money(json, 'total', currency),
    amountPaid: _money(json, 'amountPaid', currency),
    amountDue: _money(json, 'amountDue', currency),
    currency: currency,
    status: InvoiceStatus.fromApi(_strOrNull(json['status'])),
    lines: _list(
      json['lines'],
    ).map((l) => invoiceLineFromJson(l, currency)).toList(growable: false),
    documentId: _strOrNull(json['documentId']),
  );
}

InvoiceLine invoiceLineFromJson(Json json, String currency) => InvoiceLine(
  id: _str(json['id']),
  invoiceId: _str(json['invoiceId']),
  description: _str(json['description']),
  quantity: _doubleOrNull(json['quantity']) ?? 1,
  unitPrice: _money(json, 'unitPrice', currency),
  amount: _money(json, 'amount', currency),
  taxRate: _doubleOrNull(json['taxRate']),
  taxAmount: json['taxAmount'] == null
      ? null
      : _money(json, 'taxAmount', currency),
  lineType: InvoiceLineType.fromApi(_strOrNull(json['lineType'])),
  referenceId: _strOrNull(json['referenceId']),
);

Payment paymentFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Payment(
    id: _str(json['id']),
    paymentReference: _str(json['paymentReference']),
    tenantId: _str(json['tenantId']),
    invoiceId: _strOrNull(json['invoiceId']),
    invoiceNumber: _strOrNull(json['invoiceNumber']),
    leaseId: _strOrNull(json['leaseId']),
    propertyId: _strOrNull(json['propertyId']),
    amount: _money(json, 'amount', currency),
    currency: currency,
    paymentMethod: PaymentMethod.fromApi(_strOrNull(json['paymentMethod'])),
    provider: _strOrNull(json['provider']),
    providerTransactionId: _strOrNull(json['providerTransactionId']),
    // Section 39: this is the server's verdict on the payment. The app polls
    // for it and never substitutes its own.
    status: PaymentStatus.fromApi(_strOrNull(json['status'])),
    paidAt: _dateOrNull(json['paidAt']),
    createdAt: _date(json['createdAt']),
    failureReason: _strOrNull(json['failureReason']),
    receiptId: _strOrNull(json['receiptId']),
    description: _strOrNull(json['description']),
    allocations: _list(json['allocations'])
        .map(
          (a) => PaymentAllocation(
            id: _str(a['id']),
            paymentId: _str(a['paymentId']),
            invoiceId: _str(a['invoiceId']),
            invoiceNumber: _strOrNull(a['invoiceNumber']),
            amount: _money(a, 'amount', currency),
            allocatedAt: _date(a['allocatedAt']),
          ),
        )
        .toList(growable: false),
  );
}

PaymentIntent paymentIntentFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return PaymentIntent(
    paymentId: _str(json['paymentId'] ?? json['id']),
    status: PaymentStatus.fromApi(_strOrNull(json['status'])),
    amount: _money(json, 'amount', currency),
    providerReference: _strOrNull(json['providerReference']),
    instruction: _strOrNull(json['instruction']),
    redirectUrl: _strOrNull(json['redirectUrl']),
  );
}

Receipt receiptFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return Receipt(
    id: _str(json['id']),
    receiptNumber: _str(json['receiptNumber']),
    paymentId: _str(json['paymentId']),
    tenantId: _str(json['tenantId']),
    propertyId: _strOrNull(json['propertyId']),
    propertyName: _strOrNull(json['propertyName']),
    amount: _money(json, 'amount', currency),
    currency: currency,
    issuedAt: _date(json['issuedAt']),
    paymentMethod: json['paymentMethod'] == null
        ? null
        : PaymentMethod.fromApi(_strOrNull(json['paymentMethod'])),
    paymentReference: _strOrNull(json['paymentReference']),
    documentId: _strOrNull(json['documentId']),
  );
}

// -- Tenant, documents, notifications ----------------------------------------

AppUser userFromJson(Json json) => AppUser(
  id: _str(json['id']),
  organizationId: _strOrNull(json['organizationId']),
  firstName: _str(json['firstName']),
  lastName: _str(json['lastName']),
  email: _strOrNull(json['email']),
  phone: _strOrNull(json['phone']),
  status: _str(json['status'], 'ACTIVE'),
  role: AccountRole.fromApi(_strOrNull(json['role'])),
  emailVerified: _bool(json['emailVerified']),
  phoneVerified: _bool(json['phoneVerified']),
  lastLoginAt: _dateOrNull(json['lastLoginAt']),
);

// -- Owner reporting (section 88) --------------------------------------------

UnitMix _unitMixFromJson(Json? json) => json == null
    ? const UnitMix()
    : UnitMix(
        leased: _int(json['leased']),
        booked: _int(json['booked']),
        available: _int(json['available']),
        unavailable: _int(json['unavailable']),
      );

MonthlyCollection _monthlyCollectionFromJson(Json json, String currency) =>
    MonthlyCollection(
      month: _date(json['month']),
      billed: _money(json, 'billed', currency),
      collected: _money(json, 'collected', currency),
    );

OwnerAlert _ownerAlertFromJson(Json json) => OwnerAlert(
  type: OwnerAlertType.fromApi(_strOrNull(json['type'])),
  title: _str(json['title']),
  detail: _str(json['detail']),
  target: NotificationTarget.values.firstWhere(
    (value) => value.name.toUpperCase() == _str(json['target'], 'NONE'),
    orElse: () => NotificationTarget.none,
  ),
  targetId: _strOrNull(json['targetId']),
);

PropertyPerformance propertyPerformanceFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return PropertyPerformance(
    propertyId: _str(json['propertyId']),
    propertyName: _str(json['propertyName']),
    imageUrl: _strOrNull(json['imageUrl']),
    currency: currency,
    mix: _unitMixFromJson(json['mix'] as Json?),
    occupancyRate: _doubleOrNull(json['occupancyRate']) ?? 0,
    totalArea: _doubleOrNull(json['totalArea']),
    letArea: _doubleOrNull(json['letArea']),
    rentRatePerSqm: json['rentRatePerSqm'] == null
        ? null
        : _money(json, 'rentRatePerSqm', currency),
    monthlyContractedRent: _money(json, 'monthlyContractedRent', currency),
    billedThisMonth: _money(json, 'billedThisMonth', currency),
    collectedThisMonth: _money(json, 'collectedThisMonth', currency),
    outstanding: _money(json, 'outstanding', currency),
    overdue: _money(json, 'overdue', currency),
    collectionRate: _doubleOrNull(json['collectionRate']) ?? 0,
    expiringLeases: _int(json['expiringLeases']),
    tenantsInArrears: _int(json['tenantsInArrears']),
    history: _list(json['history'])
        .map((month) => _monthlyCollectionFromJson(month, currency))
        .toList(growable: false),
  );
}

OwnerPortfolio ownerPortfolioFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return OwnerPortfolio(
    ownerId: _str(json['ownerId']),
    currency: currency,
    mix: _unitMixFromJson(json['mix'] as Json?),
    occupancyRate: _doubleOrNull(json['occupancyRate']) ?? 0,
    totalArea: _doubleOrNull(json['totalArea']),
    monthlyContractedRent: _money(json, 'monthlyContractedRent', currency),
    billedThisMonth: _money(json, 'billedThisMonth', currency),
    collectedThisMonth: _money(json, 'collectedThisMonth', currency),
    outstanding: _money(json, 'outstanding', currency),
    overdue: _money(json, 'overdue', currency),
    collectionRate: _doubleOrNull(json['collectionRate']) ?? 0,
    platformFee: _money(json, 'platformFee', currency),
    netPayout: _money(json, 'netPayout', currency),
    properties: _list(
      json['properties'],
    ).map(propertyPerformanceFromJson).toList(growable: false),
    history: _list(json['history'])
        .map((month) => _monthlyCollectionFromJson(month, currency))
        .toList(growable: false),
    alerts: _list(json['alerts']).map(_ownerAlertFromJson).toList(
      growable: false,
    ),
  );
}

PropertyOwner ownerFromJson(Json json) => PropertyOwner(
  id: _str(json['id']),
  userId: _str(json['userId']),
  ownerType: OwnerType.fromApi(_strOrNull(json['ownerType'])),
  displayName: _str(json['displayName']),
  status: _str(json['status'], 'ACTIVE'),
  legalName: _strOrNull(json['legalName']),
  registrationNumber: _strOrNull(json['registrationNumber']),
  taxNumber: _strOrNull(json['taxNumber']),
  payoutAccountNumber: _strOrNull(json['payoutAccountNumber']),
);

Tenant tenantFromJson(Json json) => Tenant(
  id: _str(json['id']),
  userId: _str(json['userId']),
  tenantType: TenantType.fromApi(_strOrNull(json['tenantType'])),
  displayName: _str(json['displayName']),
  status: _str(json['status'], 'ACTIVE'),
  profile: json['profile'] == null
      ? null
      : tenantProfileFromJson(json['profile'] as Json),
);

TenantProfile tenantProfileFromJson(Json json) => TenantProfile(
  tenantId: _str(json['tenantId']),
  legalName: _strOrNull(json['legalName']),
  registrationNumber: _strOrNull(json['registrationNumber']),
  taxNumber: _strOrNull(json['taxNumber']),
  nationalId: _strOrNull(json['nationalId']),
  passportNumber: _strOrNull(json['passportNumber']),
  email: _strOrNull(json['email']),
  phone: _strOrNull(json['phone']),
  address: _strOrNull(json['address']),
  contactPerson: _strOrNull(json['contactPerson']),
  contactPersonPhone: _strOrNull(json['contactPersonPhone']),
);

Json tenantProfileToJson(TenantProfile profile) => {
  'legalName': profile.legalName,
  'registrationNumber': profile.registrationNumber,
  'taxNumber': profile.taxNumber,
  'nationalId': profile.nationalId,
  'passportNumber': profile.passportNumber,
  'email': profile.email,
  'phone': profile.phone,
  'address': profile.address,
  'contactPerson': profile.contactPerson,
  'contactPersonPhone': profile.contactPersonPhone,
};

Document documentFromJson(Json json) => Document(
  id: _str(json['id']),
  ownerType: _strOrNull(json['ownerType']),
  ownerId: _strOrNull(json['ownerId']),
  documentType: DocumentType.fromApi(_strOrNull(json['documentType'])),
  fileName: _str(json['fileName']),
  fileUrl: _strOrNull(json['fileUrl']),
  mimeType: _strOrNull(json['mimeType']),
  fileSize: _intOrNull(json['fileSize']),
  version: _int(json['version'], 1),
  hash: _strOrNull(json['hash']),
  status: _strOrNull(json['status']),
  createdAt: _date(json['createdAt']),
);

NotificationItem notificationFromJson(Json json) => NotificationItem(
  id: _str(json['id']),
  type: NotificationType.fromApi(_strOrNull(json['type'])),
  title: _str(json['title']),
  // Section 50: rendered server-side from a template, so copy changes without
  // an app release.
  body: _str(json['body']),
  createdAt: _date(json['createdAt']),
  isRead: _bool(json['isRead']),
  target: switch (_strOrNull(json['targetType'])?.toUpperCase()) {
    'BOOKING' => NotificationTarget.booking,
    'LEASE' => NotificationTarget.lease,
    'INVOICE' => NotificationTarget.invoice,
    'PAYMENT' => NotificationTarget.payment,
    'DOCUMENT' => NotificationTarget.document,
    _ => NotificationTarget.none,
  },
  targetId: _strOrNull(json['targetId']),
);

// -- Dashboard ---------------------------------------------------------------

DashboardSummary dashboardFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return DashboardSummary(
    currency: currency,
    propertyId: _strOrNull(json['propertyId']),
    propertyName: _strOrNull(json['propertyName']),
    propertyImageUrl: _strOrNull(json['propertyImageUrl']),
    unitId: _strOrNull(json['unitId']),
    unitNumber: _strOrNull(json['unitNumber']),
    leaseId: _strOrNull(json['leaseId']),
    leaseStatus: json['leaseStatus'] == null
        ? null
        : LeaseStatus.fromApi(_strOrNull(json['leaseStatus'])),
    leaseEndDate: _dateOrNull(json['leaseEndDate']),
    // Section 71: server-derived from transactional data.
    outstandingBalance: _money(json, 'outstandingBalance', currency),
    overdueAmount: json['overdueAmount'] == null
        ? null
        : _money(json, 'overdueAmount', currency),
    nextInvoiceAmount: json['nextInvoiceAmount'] == null
        ? null
        : _money(json, 'nextInvoiceAmount', currency),
    nextPaymentDueDate: _dateOrNull(json['nextPaymentDueDate']),
    nextInvoice: json['nextInvoice'] == null
        ? null
        : invoiceFromJson(json['nextInvoice'] as Json),
    recentPayments: _list(
      json['recentPayments'],
    ).map(paymentFromJson).toList(growable: false),
    activeBookingId: _strOrNull(json['activeBookingId']),
    activeBookingReference: _strOrNull(json['activeBookingReference']),
    activeBookingExpiresAt: _dateOrNull(json['activeBookingExpiresAt']),
    pendingSignatureLeaseId: _strOrNull(json['pendingSignatureLeaseId']),
    unreadNotifications: _int(json['unreadNotifications']),
  );
}
