import '../../core/utils/date_format.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/treasury.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';

/// Figures for the three screens the API cannot yet put figures on.
///
/// One tenant and one owner, told consistently: Bahari Coffee lets SHOP-101 at
/// Sarit Mall from Karuna Holdings, and the same rent, deposit and dates
/// appear on the lease, on the invoices raised against it, and in the owner's
/// ledger. Nothing here is summed on the client — every total, balance and
/// fee is written out as the server would have sent it, so the screens are
/// exercised exactly as they are in production.
///
/// Dates are relative to [now] so the Money screen always reads as "this
/// month", the ageing bands stay in their bands, and the focus invoice stays
/// due in a few days, whichever day the app is run.
class DemoFixtures {
  DemoFixtures({DateTime? now}) : now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime now;

  static const currency = 'KES';
  static const tenantId = 'demo-tenant-bahari';
  static const propertyId = 'demo-property-sarit';
  static const propertyName = 'Sarit Mall';
  static const unitId = 'demo-unit-shop-101';
  static const unitNumber = 'SHOP-101';

  final leases = <String, Lease>{};
  final agreements = <String, LeaseAgreement>{};
  final invoices = <String, Invoice>{};
  late OwnerLedger ledger;

  /// The till and the bank, as the back office sees them. Newest first.
  final mpesa = <MpesaTransaction>[];
  final bankPayments = <BankPayment>[];

  static Money _kes(num major) => Money.fromMajor(major, currency);

  /// The first of the month [monthsAgo] months back.
  DateTime _month(int monthsAgo) => DateTime(now.year, now.month - monthsAgo);

  /// A day in the month [monthsAgo] months back.
  DateTime _on(int monthsAgo, int day, [int hour = 10]) =>
      DateTime(now.year, now.month - monthsAgo, day, hour);

  DateTime _daysFromNow(int days) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: days));

  void _seed() {
    _seedLeases();
    _seedInvoices();
    _seedLedger();
    _seedTreasury();
  }

  // ---------------------------------------------------------------------------
  // Leases: the live agreement, the one it renewed, and an earlier kiosk.
  // ---------------------------------------------------------------------------

  void _seedLeases() {
    // Live: month 7 of a 24-month term, so the term bar is visibly part-way.
    final liveStart = _month(6);
    final liveEnd = DateTime(liveStart.year + 2, liveStart.month, 0);
    final signedAt = liveStart.subtract(const Duration(days: 12, hours: 3));
    const liveId = 'demo-lease-00214';

    _addLease(
      Lease(
        id: liveId,
        leaseNumber: 'LSE-00214',
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        bookingId: 'demo-booking-0472',
        startDate: liveStart,
        endDate: liveEnd,
        monthlyRent: _kes(150000),
        depositAmount: _kes(450000),
        billingFrequency: BillingFrequency.monthly,
        paymentDueDay: 5,
        status: LeaseStatus.active,
        createdAt: signedAt.subtract(const Duration(days: 3)),
        signedAt: signedAt,
        activatedAt: liveStart,
        propertyName: propertyName,
        unitNumber: unitNumber,
        agreementDocumentId: 'demo-doc-lse-00214',
        signedAgreementDocumentId: 'demo-doc-lse-00214-signed',
        terms: [
          _term('rent', 'Monthly rent', _kes(150000).format(), 'Financial'),
          _term(
            'deposit',
            'Security deposit',
            '${_kes(450000).format()} (three months)',
            'Financial',
          ),
          _term(
            'escalation',
            'Annual escalation',
            '5% on each anniversary',
            'Financial',
          ),
          _term('due-day', 'Rent due', '5th of every month', 'Financial'),
          _term(
            'use',
            'Permitted use',
            'Café and packaged food retail',
            'Use of premises',
          ),
          _term(
            'hours',
            'Trading hours',
            '07:00 – 21:00, seven days',
            'Use of premises',
          ),
          _term(
            'utilities',
            'Utilities',
            'Metered and billed monthly to the tenant',
            'Use of premises',
          ),
          _term(
            'notice',
            'Notice period',
            'Three months, in writing',
            'Notice and renewal',
          ),
          _term(
            'renewal',
            'Renewal',
            'First option to renew for a further 24 months',
            'Notice and renewal',
          ),
        ],
        activationConditions: [
          _condition('signed', 'Agreement signed by tenant', true),
          _condition('deposit', 'Deposit received', true),
          _condition('kyc', 'Business documents verified', true),
          _condition('approved', 'Approved by property manager', true),
        ],
        signatures: [
          LeaseSignature(
            id: 'demo-sig-00214',
            leaseId: liveId,
            userId: 'demo-user-bahari',
            signerName: 'Amina Bahari',
            signatureType: SignatureType.drawnSignature,
            signedAt: signedAt,
            documentHash: _hash('LSE-00214'),
          ),
        ],
      ),
      body: _agreementBody,
    );

    // The lease this one renewed: same unit, the old rent. Section 55 —
    // historical pricing is kept, not rewritten.
    final previousStart = DateTime(liveStart.year - 2, liveStart.month);
    final previousEnd = liveStart.subtract(const Duration(days: 1));
    const previousId = 'demo-lease-00093';
    _addLease(
      Lease(
        id: previousId,
        leaseNumber: 'LSE-00093',
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        startDate: previousStart,
        endDate: previousEnd,
        monthlyRent: _kes(135000),
        depositAmount: _kes(405000),
        billingFrequency: BillingFrequency.monthly,
        paymentDueDay: 5,
        status: LeaseStatus.expired,
        createdAt: previousStart.subtract(const Duration(days: 20)),
        signedAt: previousStart.subtract(const Duration(days: 9)),
        activatedAt: previousStart,
        propertyName: propertyName,
        unitNumber: unitNumber,
        agreementDocumentId: 'demo-doc-lse-00093',
        signedAgreementDocumentId: 'demo-doc-lse-00093-signed',
        signatures: [
          LeaseSignature(
            id: 'demo-sig-00093',
            leaseId: previousId,
            userId: 'demo-user-bahari',
            signerName: 'Amina Bahari',
            signatureType: SignatureType.drawnSignature,
            signedAt: previousStart.subtract(const Duration(days: 9)),
            documentHash: _hash('LSE-00093'),
          ),
        ],
      ),
      body: _agreementBody,
    );

    // Where the business started: a kiosk, given up early when the shop
    // came free.
    final kioskStart = DateTime(previousStart.year - 1, previousStart.month);
    final kioskEnd = DateTime(kioskStart.year + 1, kioskStart.month, 0);
    const kioskId = 'demo-lease-00041';
    _addLease(
      Lease(
        id: kioskId,
        leaseNumber: 'LSE-00041',
        propertyId: propertyId,
        unitId: 'demo-unit-kiosk-01',
        tenantId: tenantId,
        startDate: kioskStart,
        endDate: kioskEnd,
        monthlyRent: _kes(45000),
        depositAmount: _kes(90000),
        billingFrequency: BillingFrequency.monthly,
        paymentDueDay: 1,
        status: LeaseStatus.terminated,
        createdAt: kioskStart.subtract(const Duration(days: 14)),
        signedAt: kioskStart.subtract(const Duration(days: 5)),
        activatedAt: kioskStart,
        terminatedAt: previousStart.subtract(const Duration(days: 1)),
        propertyName: propertyName,
        unitNumber: 'KIOSK-01',
        agreementDocumentId: 'demo-doc-lse-00041',
        signedAgreementDocumentId: 'demo-doc-lse-00041-signed',
      ),
      body: _agreementBody,
    );
  }

  void _addLease(Lease lease, {required String Function(Lease) body}) {
    leases[lease.id] = lease;
    agreements[lease.id] = LeaseAgreement(
      leaseId: lease.id,
      documentHash: _hash(lease.leaseNumber),
      version: 1,
      generatedAt: lease.createdAt,
      body: body(lease),
      documentId: lease.agreementDocumentId,
    );
  }

  static LeaseTerm _term(String id, String label, String value, String group) =>
      LeaseTerm(id: 'demo-term-$id', label: label, value: value, group: group);

  static LeaseActivationCondition _condition(
    String id,
    String label,
    bool met,
  ) => LeaseActivationCondition(
    id: 'demo-cond-$id',
    label: label,
    isMet: met,
    isMandatory: true,
  );

  /// A stable, hash-shaped string. Not a real digest — nothing here is
  /// signed against a server — but long enough to read as one on screen.
  static String _hash(String seed) {
    final codes = seed.codeUnits.fold<int>(
      7,
      (h, c) => (h * 31 + c) & 0xffffffff,
    );
    return List.generate(
      64,
      (i) => ((codes >> (i % 28)) * (i + 3) % 16).toRadixString(16),
    ).join();
  }

  static String _agreementBody(Lease lease) =>
      '''
COMMERCIAL LEASE AGREEMENT
${lease.leaseNumber}

This agreement is made between Karuna Holdings Limited (the Landlord) and Bahari Coffee Limited (the Tenant) in respect of unit ${lease.unitNumber} at ${lease.propertyName}, Karuna Road, Westlands.

1. TERM
The Landlord lets the premises to the Tenant for a term beginning on ${AppDate.full(lease.startDate)} and ending on ${AppDate.full(lease.endDate)}.

2. RENT
The Tenant shall pay rent of ${lease.monthlyRent.format()} per month, payable in advance on or before the ${_ordinal(lease.paymentDueDay)} day of each month, through the payment methods offered on the platform. Rent shall rise by five per cent on each anniversary of the commencement date.

3. DEPOSIT
A security deposit of ${lease.depositAmount.format()} is held by the Landlord for the term and returned within thirty days of the Tenant vacating, less any sums properly owed.

4. USE OF PREMISES
The premises shall be used as a café and for the retail of packaged food, and for no other purpose without the Landlord's written consent.

5. SERVICES AND UTILITIES
Electricity and water are metered and invoiced to the Tenant monthly. A service charge covering common-area cleaning, security and waste is invoiced with the rent.

6. NOTICE AND RENEWAL
Either party may end this agreement by giving three months' notice in writing. The Tenant holds a first option to renew for a further twenty-four months on terms to be agreed.

7. SIGNATURE
By signing below, the Tenant confirms that they have read and accept these terms.
''';

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  // ---------------------------------------------------------------------------
  // Invoices: the tenant's statement over the live lease so far.
  // ---------------------------------------------------------------------------

  void _seedInvoices() {
    const leaseId = 'demo-lease-00214';
    var sequence = 1180;
    String nextNumber() => 'INV-${(sequence++).toString().padLeft(5, '0')}';

    // The deposit and first month, raised together when the lease was signed.
    _addInvoice(
      number: nextNumber(),
      leaseId: leaseId,
      issuedOn: _on(6, 1),
      dueOn: _on(6, 5),
      period: (start: _month(6), end: _on(6, 0)),
      lines: [
        (InvoiceLineType.deposit, 'Security deposit — three months', 1, 450000),
        (
          InvoiceLineType.rent,
          'Rent — ${AppDate.monthYear(_month(6))}',
          1,
          150000,
        ),
      ],
      subtotal: 600000,
      status: InvoiceStatus.paid,
      amountPaid: 600000,
      paidOn: _on(6, 3, 14),
      receipt: 'RCT-04471',
    );

    // Five settled months of rent and service charges, then this month.
    for (var monthsAgo = 5; monthsAgo >= 1; monthsAgo--) {
      final month = _month(monthsAgo);
      _addInvoice(
        number: nextNumber(),
        leaseId: leaseId,
        issuedOn: _on(monthsAgo, 1),
        dueOn: _on(monthsAgo, 5),
        period: (start: month, end: _on(monthsAgo - 1, 0)),
        lines: [
          (
            InvoiceLineType.rent,
            'Rent — ${AppDate.monthYear(month)}',
            1,
            150000,
          ),
        ],
        subtotal: 150000,
        status: InvoiceStatus.paid,
        amountPaid: 150000,
        paidOn: _on(monthsAgo, 3 + (monthsAgo % 3), 9),
        receipt: 'RCT-0${4490 + monthsAgo * 7}',
      );

      // Utilities move month to month; the service charge does not.
      final water = 1800 + (monthsAgo * 137) % 900;
      final power = 4200 + (monthsAgo * 311) % 1700;
      _addInvoice(
        number: nextNumber(),
        leaseId: leaseId,
        issuedOn: _on(monthsAgo, 8),
        dueOn: _on(monthsAgo, 20),
        period: (start: month, end: _on(monthsAgo - 1, 0)),
        lines: [
          (InvoiceLineType.serviceCharge, 'Service charge', 1, 12500),
          (InvoiceLineType.electricity, 'Electricity — metered', 1, power),
          (InvoiceLineType.water, 'Water — metered', 1, water),
        ],
        subtotal: 12500 + power + water,
        tax: ((power + water) * 0.16).round(),
        status: InvoiceStatus.paid,
        amountPaid: 12500 + power + water + ((power + water) * 0.16).round(),
        paidOn: _on(monthsAgo, 14 + (monthsAgo % 4), 16),
        receipt: 'RCT-0${4494 + monthsAgo * 7}',
      );
    }

    // This month's rent, part-paid and now past its due day.
    _addInvoice(
      number: nextNumber(),
      leaseId: leaseId,
      issuedOn: _on(0, 1),
      dueOn: _on(0, 5),
      period: (start: _month(0), end: _on(-1, 0)),
      lines: [
        (
          InvoiceLineType.rent,
          'Rent — ${AppDate.monthYear(_month(0))}',
          1,
          150000,
        ),
      ],
      subtotal: 150000,
      status: InvoiceStatus.partiallyPaid,
      amountPaid: 100000,
    );

    // This month's services, due in a few days: the invoice the screen leads
    // with.
    _addInvoice(
      number: nextNumber(),
      leaseId: leaseId,
      issuedOn: _daysFromNow(-8),
      dueOn: _daysFromNow(4),
      period: (start: _month(0), end: _on(-1, 0)),
      lines: [
        (InvoiceLineType.serviceCharge, 'Service charge', 1, 12500),
        (InvoiceLineType.electricity, 'Electricity — metered', 1, 4870),
        (InvoiceLineType.water, 'Water — metered', 1, 2140),
      ],
      subtotal: 19510,
      tax: 1122,
      status: InvoiceStatus.issued,
    );

    // A penalty the tenant has asked to have looked at. Still owed — deferral
    // moves the conversation, not the debt — but due late enough that it is
    // not the line the statement leads with.
    _addInvoice(
      number: nextNumber(),
      leaseId: leaseId,
      issuedOn: _daysFromNow(-4),
      dueOn: _daysFromNow(24),
      lines: [
        (
          InvoiceLineType.lateFee,
          'Late payment penalty — ${AppDate.monthYear(_month(2))} rent',
          1,
          7500,
        ),
      ],
      subtotal: 7500,
      status: InvoiceStatus.issued,
      deferred:
          'M-Pesa confirmation for ${AppDate.monthYear(_month(2))} rent '
          'arrived two days late; awaiting the landlord\'s review.',
    );
  }

  void _addInvoice({
    required String number,
    required String leaseId,
    required DateTime issuedOn,
    required DateTime dueOn,
    required List<(InvoiceLineType, String, num, num)> lines,
    required num subtotal,
    required InvoiceStatus status,
    ({DateTime start, DateTime end})? period,
    num tax = 0,
    num amountPaid = 0,
    DateTime? paidOn,
    String? receipt,
    String? deferred,
  }) {
    final id = 'demo-invoice-${number.toLowerCase()}';
    final total = subtotal + tax;
    invoices[id] = Invoice(
      id: id,
      invoiceNumber: number,
      tenantId: tenantId,
      leaseId: leaseId,
      propertyId: propertyId,
      unitId: unitId,
      propertyName: propertyName,
      unitNumber: unitNumber,
      status: status,
      invoiceDate: issuedOn,
      dueDate: dueOn,
      billingPeriodStart: period?.start,
      billingPeriodEnd: period?.end,
      subtotal: _kes(subtotal),
      tax: _kes(tax),
      discount: _kes(0),
      total: _kes(total),
      amountPaid: _kes(amountPaid),
      amountDue: _kes(total - amountPaid),
      currency: currency,
      lines: [
        for (final (index, line) in lines.indexed)
          InvoiceLine(
            id: '$id-line-${index + 1}',
            invoiceId: id,
            description: line.$2,
            quantity: line.$3,
            unitPrice: _kes(line.$4),
            amount: _kes(line.$4 * line.$3),
            lineType: line.$1,
            taxRate: switch (line.$1) {
              InvoiceLineType.electricity || InvoiceLineType.water => 16,
              _ => null,
            },
          ),
      ],
      documentId: status == InvoiceStatus.paid ? '$id-pdf' : null,
      isDeferred: deferred != null,
      deferReason: deferred,
      settledOn: status == InvoiceStatus.paid ? paidOn : null,
      paymentReceipt: receipt,
    );
  }

  // ---------------------------------------------------------------------------
  // The owner's ledger: Karuna Holdings, across both properties.
  // ---------------------------------------------------------------------------

  void _seedLedger() {
    // Sarit Mall and ABC Business Centre together bill 800,000 a month once
    // fully let. Two months ago a new tenancy's deposit was invoiced; it was
    // paid the month after, so collected legitimately exceeds billed there.
    final history = <MonthlyCollection>[
      for (final (monthsAgo, billed, collected) in <(int, num, num)>[
        (5, 715000, 640000),
        (4, 715000, 715000),
        (3, 715000, 790000),
        (2, 1550000, 800000),
        (1, 800000, 1550000),
        (0, 826000, 715000),
      ])
        MonthlyCollection(
          month: _month(monthsAgo),
          billed: _kes(billed),
          collected: _kes(collected),
        ),
    ];

    final collections = <OwnerCollection>[
      _collection(
        'p-0931',
        _daysFromNow(-1).add(const Duration(hours: 11)),
        100000,
        'Bahari Coffee',
        'SHOP-101',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0928',
        _on(0, 6, 15),
        180000,
        'Tembo Electronics',
        'SHOP-104',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0926',
        _on(0, 5, 9),
        135000,
        'Rafiki Pharmacy',
        'SHOP-108',
        PaymentMethod.bankTransfer,
      ),
      _collection(
        'p-0925',
        _on(0, 4, 17),
        120000,
        'Anga Analytics',
        'OFFICE-2B',
        PaymentMethod.bankTransfer,
        property: 'ABC Business Centre',
      ),
      _collection(
        'p-0922',
        _on(0, 3, 12),
        85000,
        'Sifa Legal',
        'OFFICE-3A',
        PaymentMethod.mpesa,
        property: 'ABC Business Centre',
      ),
      _collection(
        'p-0919',
        _on(0, 2, 8),
        45000,
        'Nuru Fashions',
        'KIOSK-01',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0917',
        _on(0, 1, 10),
        50000,
        'Bahari Coffee',
        'SHOP-101',
        PaymentMethod.mpesa,
      ),
      // Last month, including the deposit that straddled the month end.
      _collection(
        'p-0904',
        _on(1, 22, 16),
        750000,
        'Tembo Electronics',
        'SHOP-104',
        PaymentMethod.bankTransfer,
      ),
      _collection(
        'p-0898',
        _on(1, 6, 13),
        150000,
        'Bahari Coffee',
        'SHOP-101',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0896',
        _on(1, 5, 11),
        180000,
        'Tembo Electronics',
        'SHOP-104',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0895',
        _on(1, 5, 9),
        135000,
        'Rafiki Pharmacy',
        'SHOP-108',
        PaymentMethod.bankTransfer,
      ),
      _collection(
        'p-0893',
        _on(1, 4, 14),
        120000,
        'Anga Analytics',
        'OFFICE-2B',
        PaymentMethod.bankTransfer,
        property: 'ABC Business Centre',
      ),
      _collection(
        'p-0891',
        _on(1, 3, 10),
        85000,
        'Sifa Legal',
        'OFFICE-3A',
        PaymentMethod.mpesa,
        property: 'ABC Business Centre',
      ),
      _collection(
        'p-0889',
        _on(1, 2, 8),
        45000,
        'Nuru Fashions',
        'KIOSK-01',
        PaymentMethod.mpesa,
      ),
      _collection(
        'p-0887',
        _on(1, 1, 15),
        85000,
        'Sifa Legal',
        'OFFICE-3A',
        PaymentMethod.mpesa,
        property: 'ABC Business Centre',
      ),
    ];

    // This month: 715,000 in, a 2% platform fee (section 41) off the top.
    final collectedThisMonth = _kes(715000);
    final feeThisMonth = _kes(14300);

    ledger = OwnerLedger(
      currency: currency,
      collectedThisMonth: collectedThisMonth,
      platformFeeThisMonth: feeThisMonth,
      netThisMonth: _kes(700700),
      // Bahari's part-paid rent and services, Nuru's two months, and a
      // service invoice ABC's small tenant has let slide since June.
      totalOutstanding: _kes(391632),
      ageing: [
        ArrearsBucket(
          label: 'Not yet due',
          amount: _kes(20632),
          invoiceCount: 1,
        ),
        ArrearsBucket(
          label: '1–30 days',
          amount: _kes(161000),
          invoiceCount: 3,
        ),
        ArrearsBucket(
          label: '31–60 days',
          amount: _kes(135000),
          invoiceCount: 2,
        ),
        ArrearsBucket(
          label: 'Over 60 days',
          amount: _kes(75000),
          invoiceCount: 1,
        ),
      ],
      collections: collections,
      history: history,
      payouts: [
        for (final (monthsAgo, gross) in <(int, num)>[
          (5, 640000),
          (4, 715000),
          (3, 790000),
          (2, 800000),
          (1, 1550000),
          (0, 715000),
        ])
          OwnerPayout(
            month: _month(monthsAgo),
            grossCollected: _kes(gross),
            platformFee: _kes(gross * 0.02),
            net: _kes(gross * 0.98),
          ),
      ],
    );
  }

  /// The ledger's arrivals, cut to a [CollectionWindow].
  ///
  /// This is the fixture playing the server for a query the ledger itself
  /// does not answer, so it is the one place in the demo layer that adds
  /// money up — as the server would, from the payments it holds. The month
  /// views answer from the same figures the ledger already states, so the two
  /// can never disagree about what a month collected.
  CollectionSeries collectionsOver(CollectionWindow window) {
    final bounds = window.resolve(now);
    final byMonth = {for (final month in ledger.history) month.month: month};

    Money collectedIn(CollectionBucket bucket) {
      final month = bucket.isBillingPeriod ? byMonth[bucket.start] : null;
      if (month != null) return month.collected;
      var total = Money.zero(currency);
      for (final collection in ledger.collections) {
        if (bucket.contains(collection.paidAt)) total += collection.amount;
      }
      return total;
    }

    final points = [
      for (final bucket in bounds.buckets)
        CollectionPoint(
          at: bucket.start,
          label: bucket.label,
          name: bucket.name,
          collected: collectedIn(bucket),
          billed: bucket.isBillingPeriod
              ? byMonth[bucket.start]?.billed ?? Money.zero(currency)
              : null,
        ),
    ];

    final inWindow = ledger.collections.where(
      (c) => !c.paidAt.isBefore(bounds.from) && c.paidAt.isBefore(bounds.to),
    );

    if (window.period == CollectionPeriod.month) {
      return CollectionSeries(
        window: window,
        from: bounds.from,
        to: bounds.to,
        collected: ledger.collectedThisMonth,
        platformFee: ledger.platformFeeThisMonth,
        net: ledger.netThisMonth,
        paymentCount: inWindow.length,
        points: points,
      );
    }

    var collected = Money.zero(currency);
    if (window.period == CollectionPeriod.threeMonths) {
      // Whole months, so the figure is the columns added up.
      for (final point in points) {
        collected += point.collected;
      }
    } else {
      for (final collection in inWindow) {
        collected += collection.amount;
      }
    }
    // The 2% platform fee of section 41, off the top.
    final fee = collected.percentage(2);
    return CollectionSeries(
      window: window,
      from: bounds.from,
      to: bounds.to,
      collected: collected,
      platformFee: fee,
      net: collected - fee,
      paymentCount: inWindow.length,
      points: points,
    );
  }

  OwnerCollection _collection(
    String id,
    DateTime paidAt,
    num amount,
    String tenant,
    String unit,
    PaymentMethod method, {
    String property = propertyName,
  }) => OwnerCollection(
    paymentId: 'demo-$id',
    paidAt: paidAt,
    amount: _kes(amount),
    tenantName: tenant,
    propertyName: property,
    unitNumber: unit,
    method: method,
    receiptId: 'demo-rct-$id',
  );

  // ---------------------------------------------------------------------------
  // The till and the bank: the same arrivals the ledger lists, from the other
  // side of the counter.
  // ---------------------------------------------------------------------------

  void _seedTreasury() {
    // Every M-Pesa collection in the ledger arrived through the till, so each
    // one has a transaction here, reconciled against its invoice.
    const references = {
      'demo-p-0931': 'TIG4QX7MZK',
      'demo-p-0928': 'TIF9HL2BNW',
      'demo-p-0922': 'TIC3RM8VQA',
      'demo-p-0919': 'TIB7WN5KTE',
      'demo-p-0917': 'TIA2PD9HXC',
      'demo-p-0898': 'THF6KQ3JLR',
      'demo-p-0896': 'THE1MV7GZP',
      'demo-p-0891': 'THC8XB4RNT',
      'demo-p-0889': 'THB5NZ2WQY',
      'demo-p-0887': 'THA9RK6DVM',
    };
    const phones = {
      'Bahari Coffee': '254722104871',
      'Tembo Electronics': '254733560219',
      'Sifa Legal': '254711398450',
      'Nuru Fashions': '254720847315',
    };
    const accounts = {
      'Bahari Coffee': 'SHOP-101',
      'Tembo Electronics': 'SHOP-104',
      'Sifa Legal': 'OFFICE-3A',
      'Nuru Fashions': 'KIOSK-01',
    };

    for (final collection in ledger.collections) {
      final reference = references[collection.paymentId];
      if (reference == null) continue;
      mpesa.add(
        MpesaTransaction(
          id: 'demo-mpesa-${collection.paymentId}',
          transactionId: reference,
          amount: collection.amount,
          processed: true,
          transactionType: 'Pay Bill',
          transactedAt: collection.paidAt,
          businessShortCode: '400200',
          accountNumber: accounts[collection.tenantName],
          invoiceNumber: 'INV-0${1190 + mpesa.length}',
          payerPhone: phones[collection.tenantName],
          payerName: collection.tenantName.toUpperCase(),
          propertyId: collection.propertyName == propertyName
              ? propertyId
              : 'demo-property-abc',
          createdAt: collection.paidAt,
        ),
      );
    }

    // Two the till could not place. The first typed the unit without its
    // dash; the second is a number nobody in the rent roll recognises. Both
    // sort above the reconciled rows, because they are the reason the screen
    // exists.
    mpesa.insertAll(0, [
      MpesaTransaction(
        id: 'demo-mpesa-orphan-1',
        transactionId: 'TIG8FN3QRD',
        amount: _kes(135000),
        processed: false,
        transactionType: 'Pay Bill',
        transactedAt: _daysFromNow(-1).add(const Duration(hours: 16)),
        businessShortCode: '400200',
        accountNumber: 'SHOP108',
        payerPhone: '254724615082',
        payerName: 'RAFIKI PHARMACY',
        createdAt: _daysFromNow(-1).add(const Duration(hours: 16)),
      ),
      MpesaTransaction(
        id: 'demo-mpesa-orphan-2',
        transactionId: 'TIG2LW9VBS',
        amount: _kes(30000),
        processed: false,
        transactionType: 'Pay Bill',
        transactedAt: _daysFromNow(-3).add(const Duration(hours: 12)),
        businessShortCode: '400200',
        accountNumber: 'RENT',
        payerPhone: '254798443127',
        payerName: 'JOSEPH OTIENO',
        createdAt: _daysFromNow(-3).add(const Duration(hours: 12)),
      ),
    ]);

    // The bank side. The reconciled rows are the ledger's bank transfers;
    // the two awaiting review are a transfer that landed this morning and a
    // cheque somebody keyed in by hand.
    bankPayments.addAll([
      BankPayment(
        id: 'demo-bank-0112',
        amount: _kes(150000),
        paidAt: _daysFromNow(0).add(const Duration(hours: 8, minutes: 40)),
        paymentMethod: 'RTGS',
        paymentReference: 'FT26259Q8K2M',
        purpose: '${AppDate.monthYear(_month(0))} rent — SHOP-102',
        paidByName: 'Wanjiru Retail Ltd',
        bankName: 'Equity Bank',
        branchName: 'Westlands',
        bankAccountNumber: '0170294857361',
        status: 'Pending review',
        createdByName: 'Wanjiru Kamau',
        createdAt: _daysFromNow(0).add(const Duration(hours: 9)),
      ),
      BankPayment(
        id: 'demo-bank-0111',
        amount: _kes(85000),
        paidAt: _daysFromNow(-2),
        paymentMethod: 'Cheque',
        paymentReference: 'CHQ 004417',
        purpose: 'Service charge arrears — OFFICE-1C',
        paidByName: 'Mwangi & Daughters Advocates',
        bankName: 'KCB',
        branchName: 'Moi Avenue',
        status: 'Pending review',
        createdByName: 'Wanjiru Kamau',
        createdAt: _daysFromNow(-2).add(const Duration(hours: 15)),
      ),
      _reconciledBank(
        'demo-bank-0110',
        'demo-p-0926',
        'FT26248R3T7L',
        'Rafiki Pharmacy',
        'Co-operative Bank',
        'Sarit Centre',
        '01129384756100',
        'SHOP-108',
      ),
      _reconciledBank(
        'demo-bank-0109',
        'demo-p-0925',
        'FT26247M9V4N',
        'Anga Analytics Ltd',
        'Stanbic Bank',
        'Chiromo',
        '0100015678234',
        'OFFICE-2B',
      ),
      _reconciledBank(
        'demo-bank-0106',
        'demo-p-0904',
        'FT26234K1P8W',
        'Tembo Electronics Ltd',
        'NCBA',
        'Westlands',
        '7789034512001',
        'SHOP-104 deposit',
      ),
      _reconciledBank(
        'demo-bank-0104',
        'demo-p-0895',
        'FT26218R3T7L',
        'Rafiki Pharmacy',
        'Co-operative Bank',
        'Sarit Centre',
        '01129384756100',
        'SHOP-108',
      ),
      _reconciledBank(
        'demo-bank-0103',
        'demo-p-0893',
        'FT26217M9V4N',
        'Anga Analytics Ltd',
        'Stanbic Bank',
        'Chiromo',
        '0100015678234',
        'OFFICE-2B',
      ),
    ]);
  }

  /// A bank payment already matched to one of the ledger's collections.
  BankPayment _reconciledBank(
    String id,
    String paymentId,
    String reference,
    String paidBy,
    String bank,
    String branch,
    String account,
    String unit,
  ) {
    final collection = ledger.collections.firstWhere(
      (c) => c.paymentId == paymentId,
    );
    return BankPayment(
      id: id,
      amount: collection.amount,
      paidAt: collection.paidAt,
      paymentMethod: 'RTGS',
      paymentReference: reference,
      purpose: '${AppDate.monthYear(collection.paidAt)} rent — $unit',
      paidByName: paidBy,
      bankName: bank,
      branchName: branch,
      bankAccountNumber: account,
      status: 'Reconciled',
      isProcessed: true,
      createdByName: 'Wanjiru Kamau',
      createdAt: collection.paidAt.add(const Duration(hours: 3)),
      proofOfPaymentUrl: 'https://demo.invalid/proof/$reference.pdf',
    );
  }
}
