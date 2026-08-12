import '../../core/utils/money.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import 'mock_records.dart';
import 'mock_server.dart';

/// Seeds the mock server with the worked example from section 80.
///
/// The numbers here are the spec's own: Sarit Mall, SHOP-101 through SHOP-105,
/// 50 × 100, KES 150,000 a month, five months' deposit (KES 750,000), a
/// KES 20,000 booking fee, invoices generated on the 3rd and due on the 5th.
/// Keeping them identical means the acceptance walk in section 94 can be
/// followed against this app and the figures will match the document.
///
/// A second property, ABC Business Centre, exists to prove the model is not
/// mall-specific (section 6) and to exercise the tax path in section 57, which
/// Sarit Mall deliberately leaves off so its totals stay exactly as written.
void seedMockServer(MockServer server) {
  const kes = 'KES';

  // -- Organisation's first property ----------------------------------------

  const saritId = 'prp_sarit';
  server.properties[saritId] = Property(
    id: saritId,
    name: 'Sarit Mall',
    code: 'SARIT',
    propertyType: PropertyType.mall,
    status: PropertyStatus.active,
    description:
        'A flagship retail destination in Westlands with high footfall across '
        'three levels, anchored by a supermarket and a cinema.',
    address: 'Karuna Road, Westlands',
    city: 'Nairobi',
    county: 'Nairobi',
    country: 'Kenya',
    latitude: -1.2626,
    longitude: 36.8034,
    totalArea: 32000,
    totalUnits: 8,
    availableUnits: 4,
  );

  server.configs[saritId] = PropertyConfig(
    propertyId: saritId,
    defaultCurrency: kes,
    // Section 23.
    bookingExpiryHours: 48,
    // Section 34: generate on the 3rd, due on the 5th.
    invoiceGenerationDay: 3,
    invoiceDueDay: 5,
    defaultDepositMonths: 5,
    defaultBookingFee: Money.fromMajor(20000, kes),
    bookingFeeType: BookingFeeType.fixed,
    paymentGracePeriodDays: 5,
    platformFeePercent: 2,
    // Left off so the section 80 figures are reproduced exactly.
    taxEnabled: false,
  );

  const abcId = 'prp_abc';
  server.properties[abcId] = Property(
    id: abcId,
    name: 'ABC Business Centre',
    code: 'ABC-BC',
    propertyType: PropertyType.businessCenter,
    status: PropertyStatus.active,
    description:
        'Serviced office suites and co-working space on Waiyaki Way, with '
        'fibre, backup power and secure parking.',
    address: 'Waiyaki Way',
    city: 'Nairobi',
    county: 'Nairobi',
    country: 'Kenya',
    totalArea: 9000,
    totalUnits: 3,
    availableUnits: 3,
  );

  server.configs[abcId] = PropertyConfig(
    propertyId: abcId,
    defaultCurrency: kes,
    bookingExpiryHours: 24,
    invoiceGenerationDay: 25,
    invoiceDueDay: 1,
    defaultDepositMonths: 3,
    defaultBookingFee: Money.fromMajor(10000, kes),
    // Section 24's percentage variant, so both fee models are exercised.
    bookingFeeType: BookingFeeType.monthlyRentPercentage,
    bookingFeePercent: 10,
    platformFeePercent: 2.5,
    // Section 57: tax is per-property, not a global assumption.
    taxEnabled: true,
    taxName: 'VAT',
    taxRate: 16,
  );

  // -- Buildings and floors (sections 13 and 14) ----------------------------

  server.buildings.addAll(const [
    Building(
      id: 'bld_sarit_main',
      propertyId: saritId,
      name: 'Main Building',
      code: 'MAIN',
    ),
    Building(
      id: 'bld_sarit_east',
      propertyId: saritId,
      name: 'East Wing',
      code: 'EAST',
    ),
    Building(id: 'bld_abc_tower', propertyId: abcId, name: 'Tower', code: 'TWR'),
  ]);

  server.floors.addAll(const [
    Floor(
      id: 'flr_main_ground',
      buildingId: 'bld_sarit_main',
      name: 'Ground Floor',
      floorNumber: 0,
    ),
    Floor(
      id: 'flr_main_first',
      buildingId: 'bld_sarit_main',
      name: 'First Floor',
      floorNumber: 1,
    ),
    Floor(
      id: 'flr_east_ground',
      buildingId: 'bld_sarit_east',
      name: 'Ground Floor',
      floorNumber: 0,
    ),
    Floor(
      id: 'flr_abc_third',
      buildingId: 'bld_abc_tower',
      name: 'Third Floor',
      floorNumber: 3,
    ),
  ]);

  // -- Unit types (section 16) ----------------------------------------------

  server.unitTypes.addAll([
    UnitType(
      id: 'utp_retail_50x100',
      propertyId: saritId,
      name: '50x100 Retail Unit',
      code: 'RET-50100',
      description: 'Standard retail shop with frontage onto the main concourse',
      length: 50,
      width: 100,
      area: 5000,
      baseRent: Money.fromMajor(150000, kes),
      defaultDepositMonths: 5,
      defaultBookingFee: Money.fromMajor(20000, kes),
    ),
    UnitType(
      id: 'utp_kiosk_20x50',
      propertyId: saritId,
      name: '20x50 Kiosk',
      code: 'KSK-2050',
      description: 'Compact kiosk suited to service and takeaway concepts',
      length: 20,
      width: 50,
      area: 1000,
      baseRent: Money.fromMajor(45000, kes),
      defaultDepositMonths: 3,
      defaultBookingFee: Money.fromMajor(8000, kes),
    ),
    UnitType(
      id: 'utp_office_suite',
      propertyId: abcId,
      name: 'Serviced Office Suite',
      code: 'OFF-STE',
      length: 12,
      width: 8,
      area: 96,
      baseRent: Money.fromMajor(85000, kes),
      defaultDepositMonths: 3,
    ),
  ]);

  // -- Requirements (section 18) --------------------------------------------

  List<UnitRequirement> retailRequirements(String unitId) => [
    UnitRequirement(
      id: 'urq_${unitId}_deposit',
      unitId: unitId,
      requirementType: RequirementType.payment,
      name: 'Security deposit',
      description: 'Five months of rent, payable before the lease is issued',
      isMandatory: true,
      value: '5',
    ),
    UnitRequirement(
      id: 'urq_${unitId}_id',
      unitId: unitId,
      requirementType: RequirementType.document,
      name: 'National ID',
      description: 'A clear copy of the ID of the signing director or owner',
      isMandatory: true,
      documentType: DocumentType.tenantId,
    ),
    UnitRequirement(
      id: 'urq_${unitId}_reg',
      unitId: unitId,
      requirementType: RequirementType.document,
      name: 'Business registration certificate',
      description: 'Certificate of incorporation or business name registration',
      isMandatory: true,
      documentType: DocumentType.businessRegistration,
    ),
    UnitRequirement(
      id: 'urq_${unitId}_tax',
      unitId: unitId,
      requirementType: RequirementType.document,
      name: 'Tax compliance certificate',
      description: 'A valid KRA tax compliance certificate',
      isMandatory: false,
      documentType: DocumentType.taxCertificate,
    ),
  ];

  // -- Units: the batch from section 17 -------------------------------------
  //
  // Prefix SHOP, starting number 101, quantity 5 -- exactly the example. Each
  // generated unit is an independent entity; the batch was only a creation
  // mechanism and is not modelled here, which is what section 17 requires.

  void addRetailUnit({
    required String number,
    required String floorId,
    required String floorName,
    required String buildingId,
    required String buildingName,
    required UnitStatus status,
    Money? rent,
  }) {
    final id = 'unt_${number.toLowerCase().replaceAll('-', '_')}';
    server.units[id] = UnitRow(
      id: id,
      propertyId: saritId,
      buildingId: buildingId,
      floorId: floorId,
      unitTypeId: 'utp_retail_50x100',
      unitNumber: number,
      unitCode: 'SARIT-$number',
      name: 'Retail Unit $number',
      description:
          'Open-plan retail space with a glazed shopfront, three-phase power '
          'and access to the service corridor.',
      length: 50,
      width: 100,
      area: 5000,
      baseRent: rent ?? Money.fromMajor(150000, kes),
      depositMonths: 5,
      bookingFee: Money.fromMajor(20000, kes),
      status: status,
      requirements: retailRequirements(id),
      propertyName: 'Sarit Mall',
      buildingName: buildingName,
      floorName: floorName,
    );
  }

  // A spread of statuses so the browse list, filters and the "not bookable"
  // affordances all have something to render.
  addRetailUnit(
    number: 'SHOP-101',
    floorId: 'flr_main_ground',
    floorName: 'Ground Floor',
    buildingId: 'bld_sarit_main',
    buildingName: 'Main Building',
    // Leased to the demo tenant below.
    status: UnitStatus.leased,
  );
  addRetailUnit(
    number: 'SHOP-102',
    floorId: 'flr_main_ground',
    floorName: 'Ground Floor',
    buildingId: 'bld_sarit_main',
    buildingName: 'Main Building',
    status: UnitStatus.available,
  );
  addRetailUnit(
    number: 'SHOP-103',
    floorId: 'flr_main_first',
    floorName: 'First Floor',
    buildingId: 'bld_sarit_main',
    buildingName: 'Main Building',
    status: UnitStatus.available,
    rent: Money.fromMajor(135000, kes),
  );
  addRetailUnit(
    number: 'SHOP-104',
    floorId: 'flr_east_ground',
    floorName: 'Ground Floor',
    buildingId: 'bld_sarit_east',
    buildingName: 'East Wing',
    status: UnitStatus.available,
  );
  addRetailUnit(
    number: 'SHOP-105',
    floorId: 'flr_east_ground',
    floorName: 'Ground Floor',
    buildingId: 'bld_sarit_east',
    buildingName: 'East Wing',
    // Section 15's distinction: a physical hold, not a leasing state.
    status: UnitStatus.underMaintenance,
  );

  server.units['unt_kiosk_k01'] = UnitRow(
    id: 'unt_kiosk_k01',
    propertyId: saritId,
    buildingId: 'bld_sarit_main',
    floorId: 'flr_main_ground',
    unitTypeId: 'utp_kiosk_20x50',
    unitNumber: 'KIOSK-01',
    unitCode: 'SARIT-KIOSK-01',
    name: 'Concourse Kiosk 01',
    description: 'High-footfall kiosk beside the main escalator.',
    length: 20,
    width: 50,
    area: 1000,
    baseRent: Money.fromMajor(45000, kes),
    depositMonths: 3,
    bookingFee: Money.fromMajor(8000, kes),
    status: UnitStatus.available,
    requirements: retailRequirements('unt_kiosk_k01'),
    propertyName: 'Sarit Mall',
    buildingName: 'Main Building',
    floorName: 'Ground Floor',
  );

  server.units['unt_abc_3a'] = UnitRow(
    id: 'unt_abc_3a',
    propertyId: abcId,
    buildingId: 'bld_abc_tower',
    floorId: 'flr_abc_third',
    unitTypeId: 'utp_office_suite',
    unitNumber: 'OFFICE-3A',
    unitCode: 'ABC-3A',
    name: 'Suite 3A',
    description: 'Six-desk serviced suite with meeting room access.',
    length: 12,
    width: 8,
    area: 96,
    baseRent: Money.fromMajor(85000, kes),
    depositMonths: 3,
    status: UnitStatus.available,
    requirements: [
      UnitRequirement(
        id: 'urq_abc3a_deposit',
        unitId: 'unt_abc_3a',
        requirementType: RequirementType.payment,
        name: 'Security deposit',
        description: 'Three months of rent',
        isMandatory: true,
        value: '3',
      ),
      UnitRequirement(
        id: 'urq_abc3a_id',
        unitId: 'unt_abc_3a',
        requirementType: RequirementType.document,
        name: 'National ID',
        isMandatory: true,
        documentType: DocumentType.tenantId,
      ),
    ],
    propertyName: 'ABC Business Centre',
    buildingName: 'Tower',
    floorName: 'Third Floor',
  );

  // -- The demo tenant ------------------------------------------------------

  const userId = 'usr_demo';
  const tenantId = 'tnt_demo';

  server.currentUser = const AppUser(
    id: userId,
    firstName: 'Amina',
    lastName: 'Wanjiru',
    email: 'amina@example.co.ke',
    phone: '+254712345678',
    status: 'ACTIVE',
    emailVerified: true,
    phoneVerified: true,
  );

  server.currentTenant = const Tenant(
    id: tenantId,
    userId: userId,
    tenantType: TenantType.business,
    displayName: 'Wanjiru Retail Ltd',
    status: 'ACTIVE',
    profile: TenantProfile(
      tenantId: tenantId,
      legalName: 'Wanjiru Retail Limited',
      registrationNumber: 'PVT-8H2K9LM',
      taxNumber: 'P051234567X',
      nationalId: '28471932',
      email: 'amina@example.co.ke',
      phone: '+254712345678',
      address: 'PO Box 4821-00100, Nairobi',
      contactPerson: 'Amina Wanjiru',
      contactPersonPhone: '+254712345678',
    ),
  );

  // -- An established tenancy, so the app has content on first launch -------

  seedEstablishedTenancy(server, tenantId: tenantId, propertyId: saritId);
}

/// Gives the demo tenant an active lease on SHOP-101 with a settled deposit, a
/// paid rent invoice with a receipt, and a current rent invoice still due.
///
/// Without this, every screen would open empty and the app would only be
/// demonstrable by first walking the whole booking flow.
void seedEstablishedTenancy(
  MockServer server, {
  required String tenantId,
  required String propertyId,
}) {
  const kes = 'KES';
  final now = server.now;
  final config = server.configs[propertyId]!;
  final unit = server.units['unt_shop_101']!;

  final leaseStart = DateTime(now.year, now.month - 4, 1);
  final lease = LeaseRow(
    id: 'lse_demo',
    leaseNumber: 'LSE-00001',
    propertyId: propertyId,
    unitId: unit.id,
    tenantId: tenantId,
    propertyName: 'Sarit Mall',
    unitNumber: unit.unitNumber,
    startDate: leaseStart,
    endDate: DateTime(leaseStart.year + 1, leaseStart.month, leaseStart.day)
        .subtract(const Duration(days: 1)),
    monthlyRent: Money.fromMajor(150000, kes),
    depositAmount: Money.fromMajor(750000, kes),
    billingFrequency: BillingFrequency.monthly,
    paymentDueDay: config.invoiceDueDay,
    status: LeaseStatus.active,
    createdAt: leaseStart,
    signedAt: leaseStart,
    activatedAt: leaseStart,
    agreementVersion: 1,
    signatures: [
      LeaseSignature(
        id: 'sig_demo',
        leaseId: 'lse_demo',
        userId: 'usr_demo',
        signerName: 'Amina Wanjiru',
        signatureType: SignatureType.drawnSignature,
        signedAt: leaseStart,
        documentHash: server.hashOf('lse_demo:1:15000000'),
      ),
    ],
    terms: const [
      LeaseTerm(
        id: 'trm_rent',
        group: 'Financial',
        label: 'Monthly rent',
        value: 'KES 150,000, payable monthly in advance',
      ),
      LeaseTerm(
        id: 'trm_deposit',
        group: 'Financial',
        label: 'Security deposit',
        value: 'KES 750,000 (five months), refundable on expiry',
      ),
      LeaseTerm(
        id: 'trm_service',
        group: 'Financial',
        label: 'Service charge',
        value: 'KES 20,000 per month, reviewed annually',
      ),
      LeaseTerm(
        id: 'trm_late',
        group: 'Financial',
        label: 'Late payment fee',
        value: '2% per month on amounts outstanding beyond the grace period',
      ),
      LeaseTerm(
        id: 'trm_grace',
        group: 'Financial',
        label: 'Grace period',
        value: '5 days from the due date',
      ),
      LeaseTerm(
        id: 'trm_notice',
        group: 'Notice and renewal',
        label: 'Notice period',
        value: 'Three months in writing by either party',
      ),
      LeaseTerm(
        id: 'trm_renewal',
        group: 'Notice and renewal',
        label: 'Renewal',
        value: 'Renewable for a further twelve months by mutual agreement',
      ),
      LeaseTerm(
        id: 'trm_termination',
        group: 'Notice and renewal',
        label: 'Termination',
        value:
            'Either party may terminate for material breach that remains '
            'unremedied thirty days after written notice',
      ),
      LeaseTerm(
        id: 'trm_use',
        group: 'Use and responsibilities',
        label: 'Permitted use',
        value: 'Retail sale of apparel and accessories only',
      ),
      LeaseTerm(
        id: 'trm_sublet',
        group: 'Use and responsibilities',
        label: 'Subletting',
        value: 'Not permitted without the landlord’s prior written consent',
      ),
      LeaseTerm(
        id: 'trm_utilities',
        group: 'Use and responsibilities',
        label: 'Utilities',
        value: 'Electricity and water metered and billed to the tenant',
      ),
      LeaseTerm(
        id: 'trm_maintenance',
        group: 'Use and responsibilities',
        label: 'Maintenance',
        value:
            'Tenant maintains the interior; landlord maintains the structure '
            'and common areas',
      ),
    ],
  );
  server.leases[lease.id] = lease;

  final agreementDocId = 'doc_lse_demo';
  server.documents[agreementDocId] = Document(
    id: agreementDocId,
    documentType: DocumentType.signedLease,
    fileName: 'LSE-00001-signed.pdf',
    mimeType: 'application/pdf',
    fileSize: 412 * 1024,
    createdAt: leaseStart,
    ownerType: 'LEASE',
    ownerId: lease.id,
    version: 2,
    hash: server.hashOf('lse_demo:1:15000000'),
  );
  lease.signedAgreementDocumentId = agreementDocId;

  // The tenant's own uploads (section 51).
  server.documents['doc_id_copy'] = Document(
    id: 'doc_id_copy',
    documentType: DocumentType.tenantId,
    fileName: 'national-id.pdf',
    mimeType: 'application/pdf',
    fileSize: 220 * 1024,
    createdAt: leaseStart,
    ownerType: 'TENANT',
    ownerId: tenantId,
  );
  server.documents['doc_biz_reg'] = Document(
    id: 'doc_biz_reg',
    documentType: DocumentType.businessRegistration,
    fileName: 'certificate-of-incorporation.pdf',
    mimeType: 'application/pdf',
    fileSize: 610 * 1024,
    createdAt: leaseStart,
    ownerType: 'TENANT',
    ownerId: tenantId,
  );

  // A settled deposit invoice and a settled rent invoice, each with the payment
  // and receipt that section 40 requires, followed by the current month's rent
  // invoice still outstanding.
  server.seedSettledInvoice(
    tenantId: tenantId,
    lease: lease,
    description: 'Security deposit — Unit SHOP-101 (5 months)',
    amount: Money.fromMajor(750000, kes),
    lineType: InvoiceLineType.deposit,
    issuedAt: leaseStart,
    dueAt: leaseStart,
  );

  final lastMonth = DateTime(now.year, now.month - 1, 1);
  server.seedSettledInvoice(
    tenantId: tenantId,
    lease: lease,
    description:
        'Rent — Unit SHOP-101 (${_month(lastMonth.month)} ${lastMonth.year})',
    amount: Money.fromMajor(150000, kes),
    lineType: InvoiceLineType.rent,
    issuedAt: DateTime(lastMonth.year, lastMonth.month, 3),
    dueAt: DateTime(lastMonth.year, lastMonth.month, config.invoiceDueDay),
    periodStart: lastMonth,
    periodEnd: DateTime(lastMonth.year, lastMonth.month + 1, 0),
  );

  // The live one. Section 34's schedule: raised on the 3rd, due on the 5th.
  server.seedOpenInvoice(
    tenantId: tenantId,
    lease: lease,
    description: 'Rent — Unit SHOP-101 (${_month(now.month)} ${now.year})',
    amount: Money.fromMajor(150000, kes),
    lineType: InvoiceLineType.rent,
    issuedAt: DateTime(now.year, now.month, config.invoiceGenerationDay),
    dueAt: DateTime(now.year, now.month, config.invoiceDueDay),
    periodStart: DateTime(now.year, now.month, 1),
    periodEnd: DateTime(now.year, now.month + 1, 0),
  );
}

String _month(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][((month - 1) % 12 + 12) % 12];
