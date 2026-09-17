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
import '../../core/utils/phone_number.dart';
import '../../domain/entities/access.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/treasury.dart';
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

/// Sends an id back in the shape the contract expects.
///
/// The domain holds every id as a string, because an id is a name and not a
/// quantity. The contract types them as integers. This converts where it can
/// and passes the string through where it cannot — a server that starts
/// issuing opaque ids should not need a client release.
Object? _idToApi(String? id) {
  if (id == null || id.isEmpty) return null;
  return int.tryParse(id) ?? id;
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

/// Reads a route that answers with a bare array.
///
/// The transport boxes an array under `data` so every parse function receives
/// a map; this unboxes it. A route that answers with a single object instead
/// of a one-element array — which the contract does in a couple of places —
/// still reads as a list of one rather than as nothing.
List<T> listFromJson<T>(Json json, T Function(Json) item) =>
    rawListFromJson(json).map(item).toList(growable: false);

List<Json> rawListFromJson(Json json) {
  final data = json['data'];
  if (data is List) return data.whereType<Json>().toList(growable: false);
  if (data is Json) return [data];
  // No `data` key at all: the response was already the object being asked for.
  return json.isEmpty ? const <Json>[] : [json];
}

// -- Property ----------------------------------------------------------------

/// The contract measures in square feet and says so in the field names —
/// `totalAreaSqFeet`, `areaSqFeet`. Areas are carried through unchanged and
/// labelled in the unit they arrived in. Converting them to square metres here
/// would put a number on screen that nobody typed and no lease mentions.
const String _apiAreaUnit = 'sq ft';

/// The contract states no currency outside the invoice, where it is
/// `currencyCode`. Everything else is read in the platform's own currency.
const String _defaultCurrency = 'KES';

Property propertyFromJson(Json json) {
  final units = _list(json['units']);
  return Property(
    id: _str(json['id']),
    name: _str(json['propertyName']),
    // The contract has no short code for a property. Rather than invent one,
    // the field stays empty and the screens that offer it fall back to the
    // name.
    code: _str(json['code']),
    propertyType: PropertyType.fromCode(json['type']),
    status: PropertyStatus.fromCode(json['status']),
    description: _strOrNull(json['description']),
    address: _strOrNull(json['address']),
    city: _str(json['city']),
    county: _strOrNull(json['county']),
    country: _str(json['country']),
    latitude: _doubleOrNull(json['latitude']),
    longitude: _doubleOrNull(json['longitude']),
    totalArea: _doubleOrNull(json['totalAreaSqFeet']),
    totalUnits: _intOrNull(json['totalUnits']),
    // `leasableUnits` counts what *could* be let, not what is free today. When
    // the payload carries the units themselves, availability is counted from
    // them; otherwise it is left unstated rather than guessed at.
    availableUnits: units.isEmpty
        ? null
        : units.where((unit) => _bool(unit['isAvailable'])).length,
    ownerId: _strOrNull(json['ownerId']),
    rentRatePerSqm: null,
    logoUrl: _strOrNull(json['logo'] ?? json['logoUrl']),
    imageUrl: _strOrNull(json['imageUrl']),
  );
}

Building buildingFromJson(Json json) => Building(
  id: _str(json['id']),
  propertyId: _str(json['propertyId']),
  name: _str(json['blockName']),
  code: _str(json['code']),
  description: _strOrNull(json['description']),
  status: BlockStatus.fromCode(json['status']),
  totalArea: _doubleOrNull(json['totalAreaSqFeet']),
  numberOfFloors: _intOrNull(json['numberOfFloors']),
  totalUnits: _intOrNull(json['totalUnits']),
  leasableUnits: _intOrNull(json['leasableUnits']),
  propertyName: json['property'] is Json
      ? _strOrNull((json['property'] as Json)['propertyName'])
      : null,
);

Json buildingDraftToJson(BuildingDraft draft) => {
  'propertyId': _idToApi(draft.propertyId),
  'blockName': draft.name,
  'description': draft.description,
  'status': draft.status.code,
  'totalAreaSqFeet': draft.totalArea,
  'numberOfFloors': draft.numberOfFloors,
  'totalUnits': draft.totalUnits,
  'leasableUnits': draft.leasableUnits,
};

/// Expands a block's floor *count* into floor records.
///
/// The contract models floors as a number on the block, not as entities. The
/// browse filter needs something to select, so the count is projected into
/// "Floor 1..n" — with ground as floor 0 where the block says it has one. This
/// is a rendering of what the server said, not a second source of truth: no id
/// here is ever sent back.
List<Floor> floorsFromBlock(Json json) {
  final blockId = _str(json['id']);
  final count = _int(json['numberOfFloors']);
  if (count <= 0) return const <Floor>[];
  return [
    for (var level = 0; level < count; level++)
      Floor(
        id: '$blockId:$level',
        buildingId: blockId,
        name: level == 0 ? 'Ground floor' : 'Floor $level',
        floorNumber: level,
      ),
  ];
}

Floor floorFromJson(Json json) => Floor(
  id: _str(json['id']),
  buildingId: _str(json['buildingId']),
  name: _str(json['name']),
  floorNumber: _int(json['floorNumber']),
  description: _strOrNull(json['description']),
);

// -- Unit --------------------------------------------------------------------

Unit unitFromJson(Json json) {
  final currency = _str(json['currencyCode'], _defaultCurrency);
  final floorNumber = _intOrNull(json['floorNumber']);
  final property = json['property'] is Json ? json['property'] as Json : null;
  final block = json['block'] is Json ? json['block'] as Json : null;

  return Unit(
    id: _str(json['id']),
    propertyId: _str(json['propertyId']),
    buildingId: _strOrNull(json['blockId']),
    floorId: floorNumber == null
        ? null
        : '${_str(json['blockId'])}:$floorNumber',
    unitTypeId: _strOrNull(json['unitTypeId']),
    unitNumber: _str(json['unitNumber']),
    // The contract has one identifier for a unit, and this is it. The app's
    // separate "code" is the same string rather than a second one nobody
    // maintains.
    unitCode: _str(json['unitNumber']),
    name: _strOrNull(json['name']),
    description: _strOrNull(json['description']),
    category: UnitCategory.fromCode(json['type']),
    length: _doubleOrNull(json['length']),
    width: _doubleOrNull(json['width']),
    area: _doubleOrNull(json['areaSqFeet']),
    areaUnit: _apiAreaUnit,
    baseRent: _money(json, 'monthlyRent', currency),
    // Rent is quoted per month throughout the contract; there is no field
    // offering anything else.
    billingFrequency: BillingFrequency.monthly,
    status: UnitStatus.fromCode(json['status']),
    depositMonths: _intOrNull(json['depositMonths']),
    depositAmount: json['depositAmount'] == null
        ? null
        : _money(json, 'depositAmount', currency),
    serviceCharge: json['serviceChargeAmount'] == null
        ? null
        : _money(json, 'serviceChargeAmount', currency),
    bookingFee: null,
    ratePerSqm: null,
    rentOverridden: false,
    wing: _strOrNull(json['wing']),
    section: _strOrNull(json['section']),
    floorNumber: floorNumber,
    availableFrom: _dateOrNull(json['availableFrom']),
    requirements: _list(
      json['requirements'],
    ).map(unitRequirementFromJson).toList(growable: false),
    propertyName: _strOrNull(property?['propertyName']),
    buildingName: _strOrNull(block?['blockName']),
    floorName: floorNumber == null
        ? null
        : (floorNumber == 0 ? 'Ground floor' : 'Floor $floorNumber'),
    imageUrls: _list(json['images'])
        .map((i) => _str(i['url']))
        .where((url) => url.isNotEmpty)
        .toList(growable: false),
  );
}

/// One row of `GET /properties/available/units/to/book`:
///
/// ```json
/// {"propertyId": 2, "propertyName": "Grace Mall",
///  "blockId": 2, "blockName": "North Wing",
///  "availableUnitsGroupedBySize": [{"size": 480, "count": 10}]}
/// ```
///
/// `size` is the unit's `areaSqFeet`, in the contract's own unit — see
/// `_apiAreaUnit` — so it compares directly against `Unit.area`.
UnitAvailability unitAvailabilityFromJson(Json json) => UnitAvailability(
  propertyId: _str(json['propertyId']),
  propertyName: _str(json['propertyName']),
  blockId: _str(json['blockId']),
  blockName: _str(json['blockName']),
  bySize: _list(json['availableUnitsGroupedBySize'])
      .map(
        (group) => UnitAvailabilitySize(
          size: _doubleOrNull(group['size']) ?? 0,
          count: _int(group['count']),
        ),
      )
      .where((group) => group.count > 0)
      .toList(growable: false),
);

Json unitDraftToJson(UnitDraft draft) => {
  'propertyId': _idToApi(draft.propertyId),
  'blockId': _idToApi(draft.blockId),
  'unitNumber': draft.unitNumber,
  'type': draft.category.code,
  'description': draft.description,
  'length': draft.length,
  'width': draft.width,
  'areaSqFeet': draft.area,
  'monthlyRent': draft.monthlyRent.toJson(),
  'bookingFeeType': draft.bookingFeeType,
  'depositAmount': draft.depositAmount?.toJson(),
  'depositPercentage': draft.depositPercentage,
  'serviceChargeAmount': draft.serviceCharge?.toJson(),
  'bookingFeePercentage': draft.bookingFeePercentage,
  'wing': draft.wing,
  'section': draft.section,
  'floorNumber': draft.floorNumber,
};

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
  final currency = _str(json['currencyCode'], _defaultCurrency);
  final property = json['property'] is Json ? json['property'] as Json : null;
  final unit = json['unit'] is Json ? json['unit'] as Json : null;

  return Booking(
    id: _str(json['id']),
    unitId: _str(json['unitId']),
    tenantId: _str(json['tenantId']),
    propertyId: _strOrNull(json['propertyId']),
    propertyName: _strOrNull(property?['propertyName']),
    unitNumber: _strOrNull(unit?['unitNumber']),
    // The contract identifies a booking by its id alone. The reference shown
    // to the tenant is that id rather than a second one the server has never
    // heard of.
    bookingReference: _str(json['bookingReference'], _str(json['id'])),
    // Section 21: these are the terms the server captured at booking time.
    // Rendered as received; never recomputed from the unit's current pricing.
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    bookingFee: _money(json, 'bookingFee', currency),
    expiresAt: _dateOrNull(json['expiryDate']),
    status: BookingStatus.fromCode(json['status']),
    createdAt: _date(json['bookingDate'] ?? json['createdAt']),
    leaseId: _strOrNull(json['leaseId']),
    bookingFeeInvoiceId: _strOrNull(json['bookingFeeInvoiceId']),
    depositInvoiceId: _strOrNull(json['depositInvoiceId']),
    isPaid: _bool(json['isPaid']),
    phoneNumber: _strOrNull(json['phoneNumber']),
    requirements: _list(
      json['requirements'],
    ).map(bookingRequirementFromJson).toList(growable: false),
  );
}

/// Reads the answer to an STK request.
///
/// Both of the contract's prompt routes answer without a payment record: the
/// booking confirmation with `{message, success}`, the invoice request with
/// the invoices it touched. Neither is something to poll, so the prompt is
/// built from what was asked for and the server's message, when it sent one.
/// A `success: false` with a 200 is still a refusal, and is thrown as such
/// rather than dressed up as a prompt the tenant is now waiting on.
PaymentPrompt paymentPromptFromJson(
  Json json, {
  required String phoneNumber,
  required Money amount,
}) {
  if (json.containsKey('success') && !_bool(json['success'], true)) {
    throw FormatException(
      _str(json['message'], 'The payment request was not accepted.'),
    );
  }
  return PaymentPrompt(
    phoneNumber: phoneNumber,
    amount: amount,
    message: _strOrNull(json['message']),
  );
}

/// Builds the payment intent an M-Pesa request just started.
///
/// Polling requires an API-issued payment reference. A response containing
/// only invoices must not produce an invented payment id or claim settlement.
PaymentIntent paymentIntentFromRequest(
  Json json,
  String invoiceId,
  Money amount,
) {
  final paymentId = _strOrNull(json['paymentId']);
  if (paymentId == null || paymentId.isEmpty) {
    throw const FormatException(
      'The payment request was received, but no payment reference was returned. '
      'Check your invoice status before trying again.',
    );
  }
  return PaymentIntent(
    paymentId: paymentId,
    status: PaymentStatus.pending,
    amount: amount,
    providerReference: _strOrNull(json['transactionId']),
    instruction:
        'Check your phone for the M-Pesa prompt and enter your PIN to '
        'authorise the payment.',
  );
}

/// The published `CreateBookingRequest`: a property, a block, and who is
/// asking. There is no unit on it — the server allocates one — and the
/// contract's `description` is where the one thing the tenant chose that the
/// request cannot otherwise carry, the size, is written down.
Json bookingRequestToJson({
  required SpaceTarget target,
  required BookingApplicant applicant,
}) => {
  'propertyId': _idToApi(target.propertyId),
  'blockId': _idToApi(target.blockId),
  'fullName': applicant.fullName,
  'phoneNumber': PhoneNumber.normalize(applicant.phoneNumber),
  'email': applicant.email,
  'companyName': applicant.companyName,
  'businessType': applicant.businessType,
  'description': target.size == null
      ? 'Any available unit'
      : '${UnitAvailabilitySize(size: target.size!, count: 0).label} unit',
};

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
  final currency = _str(json['currencyCode'], _defaultCurrency);
  final property = json['property'] is Json ? json['property'] as Json : null;
  final unit = json['unit'] is Json ? json['unit'] as Json : null;

  return Lease(
    id: _str(json['id']),
    leaseNumber: _str(json['leaseNumber']),
    propertyId: _str(json['propertyId']),
    unitId: _str(json['unitId']),
    tenantId: _str(json['tenantId']),
    bookingId: _strOrNull(json['bookingId']),
    propertyName: _strOrNull(property?['propertyName']),
    unitNumber: _strOrNull(unit?['unitNumber']),
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    // The contract quotes rent monthly and bills on a day of the month; there
    // is no field offering another frequency.
    billingFrequency: BillingFrequency.monthly,
    paymentDueDay: _int(json['paymentDueDay'], 1),
    status: LeaseStatus.fromCode(json['status']),
    signedAt: _dateOrNull(json['tenantSignedAt'] ?? json['signedAt']),
    activatedAt: _dateOrNull(json['activatedAt']),
    terminatedAt: _dateOrNull(json['terminationDate']),
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
  final currency = _str(json['currencyCode'], _defaultCurrency);
  final property = json['property'] is Json ? json['property'] as Json : null;
  final unit = json['unit'] is Json ? json['unit'] as Json : null;

  return Invoice(
    id: _str(json['id']),
    // The contract numbers invoices by id. Shown as `INV-` plus the id rather
    // than as a bare integer, so a tenant quoting it on a bank transfer is
    // quoting something that looks like a reference.
    invoiceNumber: _str(json['invoiceNumber'], 'INV-${_str(json['id'])}'),
    tenantId: _str(json['tenantId']),
    leaseId: _strOrNull(json['leaseId']),
    propertyId: _strOrNull(json['propertyId']),
    unitId: _strOrNull(json['unitId']),
    propertyName: _strOrNull(property?['propertyName']),
    unitNumber: _strOrNull(unit?['unitNumber']),
    invoiceDate: _date(json['invoiceDate']),
    dueDate: _date(json['dueDate']),
    billingPeriodStart: _dateOrNull(json['billingPeriodStart']),
    billingPeriodEnd: _dateOrNull(json['billingPeriodEnd']),
    // Section 84 rules 4 and 7: every figure below is the server's, frozen at
    // issue. Nothing here re-derives a total from the lines.
    subtotal: _money(json, 'subtotal', currency),
    tax: _money(json, 'taxAmount', currency),
    discount: _money(json, 'discountAmount', currency),
    total: _money(json, 'totalAmount', currency),
    amountPaid: _money(json, 'paidAmount', currency),
    amountDue: _money(json, 'balanceDue', currency),
    currency: currency,
    status: _invoiceStatusFromContract(json),
    // The contract carries a single typed invoice rather than a line
    // breakdown. One line is synthesised from the invoice's own type and
    // total so the detail screen has something true to show — it is the
    // server's figure, relabelled, not a breakdown the app invented.
    lines: _list(json['lines']).isEmpty
        ? [_invoiceLineFromInvoice(json, currency)]
        : _list(json['lines'])
              .map((l) => invoiceLineFromJson(l, currency))
              .toList(growable: false),
    documentId: _strOrNull(json['documentId']),
    isDeferred: _bool(json['isDeferred']),
    deferReason: _strOrNull(json['deferReason']),
    settledOn: _dateOrNull(json['settledOn']),
    paymentReceipt: _strOrNull(json['paymentReceipt']),
  );
}

/// Works out an invoice's status from the several fields the contract spreads
/// it across.
///
/// `invoiceStatus` is free text and may be absent; `isPaid`, `cancelledDate`
/// and `dueDate` are the facts. Reading them in that order gives a status the
/// tenant would recognise, and never contradicts an explicit one the server
/// sent.
InvoiceStatus _invoiceStatusFromContract(Json json) {
  final stated = InvoiceStatus.fromApi(
    _wireName(_strOrNull(json['invoiceStatus'])),
  );
  if (stated != InvoiceStatus.unknown) return stated;

  if (_dateOrNull(json['cancelledDate']) != null) {
    return InvoiceStatus.cancelled;
  }
  if (_bool(json['isPaid'])) return InvoiceStatus.paid;

  final paid = _doubleOrNull(json['paidAmount']) ?? 0;
  final due = _dateOrNull(json['dueDate']);
  if (due != null && due.isBefore(DateTime.now())) {
    return InvoiceStatus.overdue;
  }
  return paid > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.issued;
}

/// A status the server spelled its own way, in the app's wire spelling.
///
/// The contract leaves `invoiceStatus` as a string and does not say how it is
/// written. A .NET service writes an enum's name — `PartiallyPaid` — where the
/// app expects `PARTIALLY_PAID`; a hand-typed one may say `Partially paid`.
/// All three are the same word, and this makes them compare as such.
String? _wireName(String? raw) {
  if (raw == null) return null;
  return raw
      .trim()
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => '_')
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .toUpperCase();
}

InvoiceLine _invoiceLineFromInvoice(Json json, String currency) {
  final lineType = InvoiceLineType.fromCode(json['type']);
  return InvoiceLine(
    id: 'invoice-${_str(json['id'])}',
    invoiceId: _str(json['id']),
    description: _str(json['notes'], lineType.label),
    quantity: 1,
    unitPrice: _money(json, 'subtotal', currency),
    amount: _money(json, 'subtotal', currency),
    lineType: lineType,
    taxAmount: json['taxAmount'] == null
        ? null
        : _money(json, 'taxAmount', currency),
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

/// Reads the contract's `MallUsers` into the app's signed-in user.
///
/// The contract holds one `fullName`; the app shows a first and last name and
/// builds initials from them. Splitting on the last space is a display
/// convenience and nothing more — the whole string is preserved between the
/// two fields, so nothing is lost on a name that does not split the way the
/// split assumes.
AppUser userFromJson(Json json) {
  final (firstName, lastName) = _splitName(
    _str(json['fullName'], _str(json['userName'])),
    fallbackFirst: _str(json['firstName']),
    fallbackLast: _str(json['lastName']),
  );

  return AppUser(
    id: _str(json['userId'], _str(json['id'])),
    organizationId: _strOrNull(json['organizationId']),
    firstName: firstName,
    lastName: lastName,
    email: _strOrNull(json['emailAddress'] ?? json['email']),
    phone: _strOrNull(json['phoneNumber'] ?? json['phone']),
    status: _bool(json['userActive'], true) ? 'ACTIVE' : 'DISABLED',
    role: AccountRole.fromApi(_strOrNull(json['userRole'] ?? json['role'])),
    emailVerified: _bool(json['emailConfirmed'] ?? json['emailVerified']),
    phoneVerified: _bool(json['phoneNumberConfirmed'] ?? json['phoneVerified']),
    lastLoginAt: _dateOrNull(json['lastLogin'] ?? json['lastLoginAt']),
  );
}

(String, String) _splitName(
  String fullName, {
  String fallbackFirst = '',
  String fallbackLast = '',
}) {
  if (fallbackFirst.isNotEmpty || fallbackLast.isNotEmpty) {
    return (fallbackFirst, fallbackLast);
  }
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return ('', '');
  final split = trimmed.lastIndexOf(' ');
  if (split == -1) return (trimmed, '');
  return (trimmed.substring(0, split), trimmed.substring(split + 1));
}

// -- Accounts, roles and claims ----------------------------------------------

PlatformUser platformUserFromJson(Json json) => PlatformUser(
  id: _str(json['id']),
  userId: _strOrNull(json['userId']),
  fullName: _str(json['fullName'], _str(json['userName'])),
  phoneNumber: _strOrNull(json['phoneNumber']),
  emailAddress: _strOrNull(json['emailAddress'] ?? json['email']),
  role: _strOrNull(json['userRole']),
  profileImage: _strOrNull(json['profileImage']),
  roles: _list(json['roles']).isEmpty
      ? (json['roles'] is List
            ? (json['roles'] as List)
                  .map((role) => role.toString())
                  .where((role) => role.isNotEmpty)
                  .toList(growable: false)
            : const <String>[])
      : const <String>[],
  isActive: _bool(json['userActive'], true),
  isDeleted: _bool(json['isDeleted']),
  emailConfirmed: _bool(json['emailConfirmed']),
  phoneConfirmed: _bool(json['phoneNumberConfirmed']),
  twoFactorEnabled: _bool(json['twoFactorEnabled']),
  lockoutEnabled: _bool(json['lockoutEnabled']),
  lockedOutUntil: _dateOrNull(json['lockoutEnd']),
  createdByName: _strOrNull(json['createdByName']),
  lastLoginAt: _dateOrNull(json['lastLogin']),
  createdAt: _dateOrNull(json['createdAt']),
);

AccessRole accessRoleFromJson(Json json) => AccessRole(
  id: _strOrNull(json['id']),
  name: _str(json['name'], _str(json['normalizedName'])),
);

AccessClaim accessClaimFromJson(Json json) => AccessClaim(
  type: _str(json['type']),
  value: _str(json['value']),
  issuer: _strOrNull(json['issuer']),
);

// -- Treasury ----------------------------------------------------------------

MpesaTransaction mpesaTransactionFromJson(Json json) => MpesaTransaction(
  id: _str(json['id']),
  transactionId: _str(json['transID']),
  // The gateway sends amounts as strings. Parsed once, here, and never
  // arithmetic'd afterwards.
  amount: Money.fromJson(json['transAmount'], _defaultCurrency),
  processed: _bool(json['processed']),
  transactionType: _strOrNull(json['transactionType']),
  transactedAt:
      _mpesaTimestamp(json['transTime']) ?? _dateOrNull(json['createdAt']),
  businessShortCode: _strOrNull(json['businessShortCode']),
  accountNumber: _strOrNull(json['billRefNumber']),
  invoiceNumber: _strOrNull(json['invoiceNumber']),
  payerPhone: _strOrNull(json['msisdn']),
  payerName: _strOrNull(json['firstName']),
  propertyId: _strOrNull(json['propertyId']),
  blockId: _strOrNull(json['blockId']),
  thirdPartyTransactionId: _strOrNull(json['thirdPartyTransID']),
  organisationBalance: _strOrNull(json['orgAccountBalance']),
  isReissued: _bool(json['is_reissued']),
  isEdited: _bool(json['is_edited']),
  isSplit: _bool(json['is_split']),
  createdAt: _dateOrNull(json['createdAt']),
);

/// M-Pesa stamps its timestamps as `yyyyMMddHHmmss`, which is not ISO-8601 and
/// will not parse as one. Anything else is left to the ordinary date parser.
DateTime? _mpesaTimestamp(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.length != 14) return _dateOrNull(raw);
  final parsed = DateTime.tryParse(
    '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)} '
    '${text.substring(8, 10)}:${text.substring(10, 12)}:'
    '${text.substring(12, 14)}',
  );
  return parsed ?? _dateOrNull(raw);
}

BankPayment bankPaymentFromJson(Json json) => BankPayment(
  id: _str(json['id']),
  amount: Money.fromJson(json['amount'], _defaultCurrency),
  paidAt: _date(json['paymentDate']),
  paymentMethod: _str(json['paymentMethod']),
  paymentReference: _str(json['paymentReference']),
  invoiceId: _strOrNull(json['invoiceId']),
  tenantId: _strOrNull(json['tenantId']),
  propertyId: _strOrNull(json['propertyId']),
  blockId: _strOrNull(json['blockId']),
  purpose: _strOrNull(json['purpose']),
  paidByName: _strOrNull(json['paidBy']),
  bankAccountNumber: _strOrNull(json['bankAccountNumber']),
  bankName: _strOrNull(json['bankName']),
  branchName: _strOrNull(json['branchName']),
  status: _strOrNull(json['status']),
  proofOfPaymentUrl: _strOrNull(json['proofOfPaymentUrl']),
  isProcessed: _bool(json['isProcessed']),
  isSplit: _bool(json['isSplit']),
  isReissued: _bool(json['isReissued']),
  createdByName: _strOrNull(json['createdByName']),
  createdAt: _dateOrNull(json['createdAt']),
);

Json bankPaymentDraftToJson(BankPaymentDraft draft) => {
  'paymentDate': draft.paidAt.toUtc().toIso8601String(),
  'amount': draft.amount.toJson(),
  'paymentMethod': draft.paymentMethod,
  'paymentReference': draft.paymentReference,
  'invoiceId': _idToApi(draft.invoiceId),
  'tenantId': _idToApi(draft.tenantId),
  'purpose': draft.purpose,
  'paidByName': draft.paidByName,
  'bankAccountNumber': draft.bankAccountNumber,
  'bankName': draft.bankName,
  'branchName': draft.branchName,
  'proofOfPaymentUrl': draft.proofOfPaymentUrl,
};

Json bankPaymentToJson(BankPayment payment) => {
  'id': _idToApi(payment.id),
  'paymentDate': payment.paidAt.toUtc().toIso8601String(),
  'amount': payment.amount.toJson(),
  'paymentMethod': payment.paymentMethod,
  'paymentReference': payment.paymentReference,
  'invoiceId': _idToApi(payment.invoiceId),
  'tenantId': _idToApi(payment.tenantId),
  'propertyId': _idToApi(payment.propertyId),
  'blockId': _idToApi(payment.blockId),
  'purpose': payment.purpose,
  'paidBy': payment.paidByName,
  'bankAccountNumber': payment.bankAccountNumber,
  'bankName': payment.bankName,
  'branchName': payment.branchName,
  'status': payment.status,
  'proofOfPaymentUrl': payment.proofOfPaymentUrl,
};

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

RepricingImpact repricingImpactFromJson(Json json) => RepricingImpact(
  repriceable: _int(json['repriceable']),
  overridden: _int(json['overridden']),
  let: _int(json['let']),
);

/// The client describes what it wants; the server decides what it gets. No id,
/// no status, no derived counts — and notably no rents, only the rate they are
/// derived from.
/// The contract's `CreatePropertyRequest`.
///
/// Two fields the app carries have nowhere to go: the street address, which
/// the contract records only as a city and a country, and the rate per square
/// metre, which it has no concept of. The rate is not dropped silently — it is
/// what every generated unit's rent is worked out from before the units are
/// sent, so it survives where it matters even though the property itself
/// cannot hold it.
Json propertyDraftToJson(PropertyDraft draft) => {
  'propertyName': draft.name,
  'type': draft.propertyType.code,
  'status': PropertyStatus.active.code,
  'description': draft.description,
  'city': draft.city,
  'country': draft.country,
  'totalAreaSqFeet': draft.totalArea,
  'leasableAreaSqFeet': draft.totalArea,
};

/// One unit out of a batch, numbered.
///
/// The contract creates units singly, so a batch becomes this called
/// repeatedly. Each unit's rent is the batch's rate times its area — worked
/// out here because the server has no rate to work it out from, and worked out
/// once per unit rather than once and copied, so a rounding is the same
/// rounding the owner was shown.
UnitDraft unitDraftFromBatch(
  UnitBatchDraft draft,
  String propertyId,
  int index,
) {
  final rate = draft.ratePerSqm;
  return UnitDraft(
    propertyId: propertyId,
    unitNumber: '${draft.numberPrefix}-${draft.startNumber + index}',
    category: UnitCategory.shop,
    monthlyRent: rate == null
        ? Money.zero(_defaultCurrency)
        : rate.scaledBy(draft.area),
    description: draft.description,
    length: draft.length,
    width: draft.width,
    area: draft.area,
    depositAmount: null,
    serviceCharge: null,
  );
}

Json unitBatchDraftToJson(UnitBatchDraft draft) => {
  'typeName': draft.typeName,
  'description': draft.description,
  'length': draft.length,
  'width': draft.width,
  'area': draft.area,
  'quantity': draft.quantity,
  'numberPrefix': draft.numberPrefix,
  'startNumber': draft.startNumber,
  'depositMonths': draft.depositMonths,
  'bookingFee': draft.bookingFee?.toJson(),
  'ratePerSqm': draft.ratePerSqm?.toJson(),
  'buildingName': draft.buildingName,
  'floorName': draft.floorName,
};

OwnerLedger ownerLedgerFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return OwnerLedger(
    currency: currency,
    collectedThisMonth: _money(json, 'collectedThisMonth', currency),
    platformFeeThisMonth: _money(json, 'platformFeeThisMonth', currency),
    netThisMonth: _money(json, 'netThisMonth', currency),
    totalOutstanding: _money(json, 'totalOutstanding', currency),
    payouts: _list(json['payouts'])
        .map(
          (payout) => OwnerPayout(
            month: _date(payout['month']),
            grossCollected: _money(payout, 'grossCollected', currency),
            platformFee: _money(payout, 'platformFee', currency),
            net: _money(payout, 'net', currency),
          ),
        )
        .toList(growable: false),
    ageing: _list(json['ageing'])
        .map(
          (bucket) => ArrearsBucket(
            label: _str(bucket['label']),
            amount: _money(bucket, 'amount', currency),
            invoiceCount: _int(bucket['invoiceCount']),
          ),
        )
        .toList(growable: false),
    collections: _list(json['collections'])
        .map(
          (collection) => OwnerCollection(
            paymentId: _str(collection['paymentId']),
            paidAt: _date(collection['paidAt']),
            amount: _money(collection, 'amount', currency),
            tenantName: _str(collection['tenantName']),
            propertyName: _str(collection['propertyName']),
            unitNumber: _strOrNull(collection['unitNumber']),
            method: PaymentMethod.fromApi(_strOrNull(collection['method'])),
            receiptId: _strOrNull(collection['receiptId']),
          ),
        )
        .toList(growable: false),
    history: _list(json['history'])
        .map((month) => _monthlyCollectionFromJson(month, currency))
        .toList(growable: false),
  );
}

RentRollEntry rentRollEntryFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return RentRollEntry(
    unitId: _str(json['unitId']),
    unitNumber: _str(json['unitNumber']),
    name: _strOrNull(json['name']),
    status: UnitStatus.fromApi(_strOrNull(json['status'])),
    area: _doubleOrNull(json['area']),
    areaUnit: _str(json['areaUnit'], 'm²'),
    baseRent: _money(json, 'baseRent', currency),
    ratePerSqm: json['ratePerSqm'] == null
        ? null
        : _money(json, 'ratePerSqm', currency),
    rentOverridden: _bool(json['rentOverridden']),
    tenantId: _strOrNull(json['tenantId']),
    tenantName: _strOrNull(json['tenantName']),
    leaseId: _strOrNull(json['leaseId']),
    leaseEndDate: _dateOrNull(json['leaseEndDate']),
    outstanding: json['outstanding'] == null
        ? null
        : _money(json, 'outstanding', currency),
  );
}

OwnerTenancy ownerTenancyFromJson(Json json) {
  final currency = _str(json['currency'], 'KES');
  return OwnerTenancy(
    leaseId: _str(json['leaseId']),
    leaseNumber: _str(json['leaseNumber']),
    propertyId: _str(json['propertyId']),
    propertyName: _str(json['propertyName']),
    unitId: _strOrNull(json['unitId']),
    unitNumber: _str(json['unitNumber']),
    tenantId: _str(json['tenantId']),
    tenantName: _str(json['tenantName']),
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
    monthlyRent: _money(json, 'monthlyRent', currency),
    depositAmount: _money(json, 'depositAmount', currency),
    status: LeaseStatus.fromApi(_strOrNull(json['status'])),
    outstanding: _money(json, 'outstanding', currency),
    overdue: _money(json, 'overdue', currency),
    lastPaymentAt: _dateOrNull(json['lastPaymentAt']),
  );
}

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
    alerts: _list(
      json['alerts'],
    ).map(_ownerAlertFromJson).toList(growable: false),
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
  'phone': PhoneNumber.normalizeOrNull(profile.phone),
  'address': profile.address,
  'contactPerson': profile.contactPerson,
  'contactPersonPhone': PhoneNumber.normalizeOrNull(profile.contactPersonPhone),
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
