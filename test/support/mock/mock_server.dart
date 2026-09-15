import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:mall/core/utils/money.dart';
import 'package:mall/core/utils/phone_number.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/domain/entities/dashboard_summary.dart';
import 'package:mall/domain/entities/lease.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/domain/entities/property.dart';
import 'package:mall/domain/entities/tenant.dart';
import 'package:mall/domain/entities/unit.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'agreement_template.dart';
import 'mock_back_office.dart';
import 'mock_records.dart';
import 'seed_data.dart';

/// An in-memory stand-in for the backend described in section 89.
///
/// This class exists so the app can be built and demonstrated end to end before
/// the real server does. It is deliberately written as a *server*, not as a
/// convenience for the UI: fee calculation, reference generation, availability
/// locking, idempotency replay, invoice raising, payment allocation, receipt
/// issuing and platform fee recording all happen here.
///
/// That split matters. Section 65 forbids the client from computing
/// authoritative financial amounts and section 84 rule 7 puts totalling on the
/// server. If this logic lived in a controller or a widget, swapping in the
/// real backend later would mean deleting business rules out of the UI — and
/// any that were missed would silently disagree with the server. Keeping them
/// here means the presentation layer is already written against a server that
/// behaves like the specified one.
class MockServer {
  MockServer({
    Duration? paymentAuthorisationDelay,
    Duration? paymentSettlementDelay,
    DateTime Function()? clock,
  }) : _paymentAuthorisationDelay =
           paymentAuthorisationDelay ?? const Duration(seconds: 4),
       _paymentSettlementDelay =
           paymentSettlementDelay ?? const Duration(seconds: 4),
       _clock = clock ?? DateTime.now {
    _seed();
  }

  static const _uuid = Uuid();

  /// How long the simulated STK push waits before the tenant "enters their
  /// PIN", and then before the provider confirms. Tests shorten both so they
  /// do not have to wait in real time.
  final Duration _paymentAuthorisationDelay;
  final Duration _paymentSettlementDelay;

  /// Injectable so tests can move time forward — used for booking expiry.
  final DateTime Function() _clock;

  // -- Stored state ----------------------------------------------------------

  final Map<String, PropertyRow> properties = {};
  final List<Building> buildings = [];
  final List<Floor> floors = [];
  final List<UnitType> unitTypes = [];
  final Map<String, PropertyConfig> configs = {};

  /// Section 88. Owners, and the accounts behind them.
  final Map<String, PropertyOwner> owners = {};

  /// Every tenant the platform knows about, not just the signed-in one.
  ///
  /// The tenant app only ever needed [currentTenant]. An owner looking at a
  /// rent roll needs to know who is in each unit, so occupants are addressable
  /// by id.
  final Map<String, Tenant> tenants = {};

  final Map<String, UnitRow> units = {};
  final Map<String, BookingRow> bookings = {};
  final Map<String, LeaseRow> leases = {};
  final Map<String, InvoiceRow> invoices = {};
  final Map<String, PaymentRow> payments = {};
  final Map<String, Receipt> receipts = {};
  final Map<String, Document> documents = {};
  final List<NotificationRow> notifications = [];
  final List<FinancialTransaction> ledger = [];

  /// Section 66. Maps an idempotency key to the id of the resource the first
  /// request created, so a replay returns that resource instead of creating a
  /// second one.
  /// The treasury and identity surfaces.
  ///
  /// Lazy, because it seeds itself from the payments and accounts this server
  /// creates — asking for it in the constructor would read them before they
  /// exist.
  late final MockBackOffice backOffice = MockBackOffice(this);

  final Map<String, String> _idempotency = {};

  /// Sequence counters behind the human-readable references in section 69.
  int _bookingSeq = 0;
  int _invoiceSeq = 0;
  int _paymentSeq = 0;
  int _receiptSeq = 0;
  int _leaseSeq = 0;

  AppUser? currentUser;
  Tenant? currentTenant;

  /// Set only while an owner account is signed in.
  PropertyOwner? currentOwner;

  /// Section 88. The demo accounts a sign-in can resolve to, keyed by the
  /// phone and the email that reach them.
  ///
  /// The mock used to hold one account, because there was one audience. Now a
  /// sign-in has to decide *which* account it is. An unrecognised phone or
  /// email still resolves to [defaultSession] — the tenant — so a test or a
  /// demo that signs in with an arbitrary number keeps behaving as it did.
  final Map<String, AuthSession> accountsByPhone = {};
  final Map<String, AuthSession> accountsByEmail = {};

  /// The first account registered, which the seed makes the tenant.
  AuthSession? defaultSession;

  /// Pending OTP challenges: challenge id -> phone.
  final Map<String, String> otpChallenges = {};

  /// The mock accepts this OTP for any challenge. Surfaced in the UI as a hint
  /// so a demo does not need a real SMS gateway.
  static const String demoOtp = '123456';

  Set<NotificationChannel> channelPreferences = {
    NotificationChannel.push,
    NotificationChannel.sms,
    NotificationChannel.email,
    NotificationChannel.inApp,
  };

  DateTime get now => _clock();

  String _id(String prefix) => '${prefix}_${_uuid.v4().substring(0, 8)}';

  void _seed() => seedMockServer(this);

  // -- Pricing (section 88) --------------------------------------------------

  /// Derives a unit's asking rent from an area and a rate per square metre.
  ///
  /// The only place that multiplication happens. Section 65 keeps the client
  /// out of computing payable amounts and section 84 rule 7 puts totalling on
  /// the server; a rate is the input an owner controls, and the rent is the
  /// server's answer. A screen that wants to show a rent asks for one rather
  /// than working it out, exactly as it does for an invoice total.
  Money rentFor({required double area, required Money ratePerSqm}) =>
      ratePerSqm.scaledBy(area);

  /// The rate a unit in [propertyId] is priced at, given its unit type.
  ///
  /// A unit type may override the property's rate — a kiosk earns more per
  /// square metre than a warehouse bay in the same building. Null when the
  /// property is priced unit by unit rather than by area.
  Money? rateFor({required String propertyId, String? unitTypeId}) {
    if (unitTypeId != null) {
      for (final type in unitTypes) {
        if (type.id == unitTypeId && type.ratePerSqm != null) {
          return type.ratePerSqm;
        }
      }
    }
    return properties[propertyId]?.rentRatePerSqm;
  }

  // ==========================================================================
  // Auth
  // ==========================================================================

  /// Makes an account reachable by signing in with [phone] or [email].
  ///
  /// The first account registered becomes [defaultSession].
  void registerAccount(AuthSession session, {String? phone, String? email}) {
    if (phone != null) accountsByPhone[normalisePhone(phone)] = session;
    if (email != null) accountsByEmail[email.trim().toLowerCase()] = session;
    defaultSession ??= session;
  }

  /// Keys an account on the one form every number is sent in, so
  /// `+254 712 345678`, `0712345678` and `712345678` all reach the same
  /// account — the same rule the real API is spoken to with.
  static String normalisePhone(String value) => PhoneNumber.normalize(value);

  String requestOtp(String phone) {
    final challengeId = _id('chg');
    otpChallenges[challengeId] = phone;
    return challengeId;
  }

  /// Returns null when the challenge is unknown or the code is wrong.
  AuthSession? verifyOtp(String challengeId, String code) {
    final phone = otpChallenges[challengeId];
    if (phone == null) return null;
    if (code.trim() != demoOtp) return null;
    otpChallenges.remove(challengeId);
    return _signIn(accountsByPhone[normalisePhone(phone)] ?? defaultSession);
  }

  /// Passwords, once somebody has set one, keyed by normalised phone number.
  ///
  /// Empty to begin with, which is what lets the demo accounts sign in with
  /// anything. The moment a password is changed or reset, the new one is
  /// required — so those screens do something the next sign-in notices.
  final Map<String, String> passwords = {};

  /// Signs in with an identifier and a password.
  ///
  /// [identifier] is an email address or a phone number; both are tried,
  /// because the published contract keys on the phone number and the demo
  /// accounts are listed by email.
  AuthSession? loginWithPassword(String identifier, String password) {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty || password.isEmpty) return null;

    final session =
        accountsByEmail[trimmed.toLowerCase()] ??
        accountsByPhone[normalisePhone(trimmed)] ??
        defaultSession;

    final phone = session?.user.phone;
    final stored = phone == null ? null : passwords[normalisePhone(phone)];
    // Any password is accepted until one has been set. The real check belongs
    // on the server; this is the part of it the mock can honestly keep.
    if (stored != null && stored != password) return null;

    return _signIn(session);
  }

  /// Makes [session] the signed-in account.
  ///
  /// Everything the mock serves afterwards is scoped to whoever this is, which
  /// is what lets one process demonstrate both sides of the platform.
  AuthSession? _signIn(AuthSession? session) {
    if (session == null) return null;
    currentUser = session.user;
    currentTenant = session.tenant;
    currentOwner = session.owner;
    return session;
  }

  String register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required TenantType tenantType,
  }) {
    currentUser = AppUser(
      id: _id('usr'),
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      status: 'ACTIVE',
      phoneVerified: false,
      emailVerified: false,
    );
    currentTenant = Tenant(
      id: _id('tnt'),
      userId: currentUser!.id,
      tenantType: tenantType,
      displayName: '$firstName $lastName'.trim(),
      status: 'ACTIVE',
      profile: TenantProfile(
        tenantId: currentTenant?.id ?? 'tnt_new',
        email: email,
        phone: phone,
        legalName: '$firstName $lastName'.trim(),
      ),
    );
    // Registration is a tenant path: an owner account is created by the
    // platform, not self-served.
    currentOwner = null;
    registerAccount(
      AuthSession(user: currentUser!, tenant: currentTenant),
      phone: phone,
      email: email,
    );
    return requestOtp(phone);
  }

  // ==========================================================================
  // Units and availability (section 48)
  // ==========================================================================

  /// The availability engine.
  ///
  /// A unit is bookable only when it has no live booking and no live lease.
  /// Occupancy is *derived* rather than read off a status column, which is what
  /// section 15 recommends — a stored status and the actual booking records can
  /// drift apart, and the records are the truth.
  bool isUnitAvailable(String unitId) {
    final unit = units[unitId];
    if (unit == null) return false;

    // Physically unavailable regardless of leasing state.
    if (unit.status == UnitStatus.underMaintenance ||
        unit.status == UnitStatus.blocked ||
        unit.status == UnitStatus.unavailable) {
      return false;
    }

    expireDueBookings();

    final hasLiveBooking = bookings.values.any(
      (b) =>
          b.unitId == unitId &&
          (b.status == BookingStatus.active ||
              b.status == BookingStatus.pendingPayment ||
              b.status == BookingStatus.paymentPending),
    );
    if (hasLiveBooking) return false;

    final hasLiveLease = leases.values.any(
      (l) => l.unitId == unitId && l.status.isCurrent,
    );
    if (hasLiveLease) return false;

    return true;
  }

  /// Recomputes a unit's status from the bookings and leases that reference it.
  void _refreshUnitStatus(String unitId) {
    final unit = units[unitId];
    if (unit == null) return;

    // Never override a physical hold with a derived leasing status.
    if (unit.status == UnitStatus.underMaintenance ||
        unit.status == UnitStatus.blocked ||
        unit.status == UnitStatus.unavailable) {
      return;
    }

    final hasLease = leases.values.any(
      (l) => l.unitId == unitId && l.status.isCurrent,
    );
    if (hasLease) {
      unit.status = UnitStatus.leased;
      return;
    }

    final activeBooking = bookings.values.any(
      (b) => b.unitId == unitId && b.status == BookingStatus.active,
    );
    if (activeBooking) {
      unit.status = UnitStatus.reserved;
      return;
    }

    final pendingBooking = bookings.values.any(
      (b) =>
          b.unitId == unitId &&
          (b.status == BookingStatus.pendingPayment ||
              b.status == BookingStatus.paymentPending),
    );
    unit.status = pendingBooking ? UnitStatus.booked : UnitStatus.available;
  }

  // ==========================================================================
  // Booking (sections 21-25)
  // ==========================================================================

  /// Section 65: the server computes the commercial terms; the client asks.
  BookingQuote quoteFor(String unitId) {
    final unit = units[unitId]!;
    final config = configs[unit.propertyId]!;

    final depositMonths = unit.depositMonths ?? config.defaultDepositMonths;
    final rent = unit.baseRent;

    // Section 25: deposit = months x rent, computed here and stored on the
    // booking once created.
    final deposit = rent * depositMonths;

    // Section 24: booking fee may be fixed or a percentage of rent.
    final bookingFee = unit.bookingFee ?? config.calculateBookingFee(rent);

    // Section 57: tax is configurable per property and is not assumed.
    final tax = config.taxEnabled
        ? bookingFee.percentage(config.taxRate)
        : null;

    final total = tax == null ? bookingFee : bookingFee + tax;

    return BookingQuote(
      unitId: unitId,
      monthlyRent: rent,
      depositAmount: deposit,
      bookingFee: bookingFee,
      taxAmount: tax,
      taxLabel: config.taxEnabled ? config.taxName : null,
      total: total,
      currency: rent.currency,
      depositMonths: depositMonths,
      expiryHours: config.bookingExpiryHours,
      requirements: unit.requirements
          .map(
            (r) => UnitRequirementSummary(
              name: r.name,
              description: r.description,
              requirementType: r.requirementType,
              isMandatory: r.isMandatory,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Creates a booking, or replays the one this [idempotencyKey] already made.
  ///
  /// Section 48 requires this to be atomic so two tenants cannot take the same
  /// unit. Dart's single-threaded event loop gives that for free here: nothing
  /// awaits between the availability check and the write, so no other request
  /// can interleave. On the real server this is a `SELECT ... FOR UPDATE`
  /// inside a transaction.
  ///
  /// Throws [MockConflict] when the unit is gone, which the repository maps to
  /// a `ConflictFailure`.
  BookingRow createBooking({
    required String unitId,
    required BookingApplicant applicant,
    required String idempotencyKey,
  }) {
    // Section 66: a retry must not create a second booking.
    final replayed = _idempotency[idempotencyKey];
    if (replayed != null) return bookings[replayed]!;

    if (!isUnitAvailable(unitId)) {
      throw const MockConflict(
        'This unit has just been taken. Please choose another one.',
      );
    }

    final quote = quoteFor(unitId);
    final unit = units[unitId]!;
    final config = configs[unit.propertyId]!;

    _bookingSeq++;
    final booking = BookingRow(
      id: _id('bkg'),
      unitId: unitId,
      tenantId: currentTenant!.id,
      propertyId: unit.propertyId,
      bookingReference: 'BKG-${_bookingSeq.toString().padLeft(5, '0')}',
      // Section 21: terms are captured now and never re-derived from the unit's
      // current pricing.
      monthlyRent: quote.monthlyRent,
      depositAmount: quote.depositAmount,
      bookingFee: quote.bookingFee,
      status: BookingStatus.pendingPayment,
      createdAt: now,
      // Section 23: the countdown starts when the booking becomes ACTIVE, which
      // happens on successful payment of the fee, so no expiry is set yet.
      expiresAt: null,
      requirements: unit.requirements
          .map(
            (r) => BookingRequirementRow(
              id: _id('req'),
              requirementType: r.requirementType,
              name: r.name,
              description: r.description,
              isMandatory: r.isMandatory,
              documentType: r.documentType,
              // The deposit requirement is satisfied by paying the deposit
              // invoice, not by uploading anything.
              isSatisfied: false,
            ),
          )
          .toList(),
      applicant: applicant,
    );

    bookings[booking.id] = booking;
    _idempotency[idempotencyKey] = booking.id;

    // Section 31: the fee is raised as an invoice so there is a financial
    // trail, rather than being tracked as a boolean on the booking.
    final feeInvoice = _raiseInvoice(
      tenantId: booking.tenantId,
      propertyId: unit.propertyId,
      unitId: unitId,
      unitNumber: unit.unitNumber,
      propertyName: properties[unit.propertyId]!.name,
      dueDate: now.add(Duration(hours: config.bookingExpiryHours)),
      lines: [
        InvoiceLineDraft(
          description: 'Booking fee — Unit ${unit.unitNumber}',
          amount: quote.bookingFee,
          lineType: InvoiceLineType.bookingFee,
          referenceId: booking.id,
        ),
      ],
      config: config,
    );
    booking.bookingFeeInvoiceId = feeInvoice.id;

    _refreshUnitStatus(unitId);
    _notify(
      NotificationType.bookingCreated,
      'Booking created',
      'Your booking ${booking.bookingReference} for Unit ${unit.unitNumber} '
          'is held pending payment of the booking fee.',
      target: NotificationTarget.booking,
      targetId: booking.id,
    );

    return booking;
  }

  /// Section 23. Flips bookings whose hold has lapsed.
  ///
  /// On the real backend this is a scheduled worker (section 68). Here it runs
  /// opportunistically before any read that depends on it, which gives the same
  /// observable behaviour without a background isolate.
  ///
  /// Expired bookings are never deleted — section 23 is explicit about that —
  /// and any payment already recorded against one stays recorded.
  void expireDueBookings() {
    final current = now;
    for (final booking in bookings.values) {
      if (booking.status != BookingStatus.active) continue;
      final expiry = booking.expiresAt;
      if (expiry == null || expiry.isAfter(current)) continue;

      booking.status = BookingStatus.expired;
      _notify(
        NotificationType.bookingExpired,
        'Booking expired',
        'Booking ${booking.bookingReference} has expired and the unit has been '
            'released.',
        target: NotificationTarget.booking,
        targetId: booking.id,
      );
      // Deliberately after the status change, so the unit is recomputed against
      // the now-expired booking and returns to available.
      _refreshUnitStatus(booking.unitId);
    }
  }

  void cancelBooking(String bookingId) {
    final booking = bookings[bookingId];
    if (booking == null) throw const MockNotFound('Booking not found');
    if (booking.status.isTerminal) {
      throw const MockConflict('This booking can no longer be cancelled.');
    }
    booking.status = BookingStatus.cancelled;
    _refreshUnitStatus(booking.unitId);
  }

  // ==========================================================================
  // Invoicing (sections 32-35)
  // ==========================================================================

  /// Raises an invoice from line drafts, computing subtotal, tax and total.
  ///
  /// This is the only place invoice totals are calculated anywhere in the
  /// codebase. Section 84 rule 7 requires it to be server-side, and section 55
  /// requires the figures to be frozen once issued — so nothing recomputes an
  /// invoice after this returns.
  InvoiceRow _raiseInvoice({
    required String tenantId,
    required String propertyId,
    required String? unitId,
    required String? unitNumber,
    required String propertyName,
    required DateTime dueDate,
    required List<InvoiceLineDraft> lines,
    required PropertyConfig config,
    String? leaseId,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    InvoiceStatus status = InvoiceStatus.issued,
    DateTime? issuedAt,
    bool notify = true,
  }) {
    _invoiceSeq++;
    final invoiceId = _id('inv');
    final currency = lines.first.amount.currency;

    var subtotal = Money.zero(currency);
    var tax = Money.zero(currency);

    final invoiceLines = <InvoiceLine>[];
    for (final draft in lines) {
      final lineTax = config.taxEnabled && draft.taxable
          ? draft.amount.percentage(config.taxRate)
          : Money.zero(currency);

      subtotal += draft.amount;
      tax += lineTax;

      invoiceLines.add(
        InvoiceLine(
          id: _id('inl'),
          invoiceId: invoiceId,
          description: draft.description,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice ?? draft.amount,
          amount: draft.amount,
          taxRate: config.taxEnabled && draft.taxable
              ? config.taxRate.toDouble()
              : null,
          taxAmount: lineTax.isZero ? null : lineTax,
          lineType: draft.lineType,
          referenceId: draft.referenceId,
        ),
      );
    }

    final discount = Money.zero(currency);
    final total = subtotal + tax - discount;

    final invoice = InvoiceRow(
      id: invoiceId,
      invoiceNumber: 'INV-${_invoiceSeq.toString().padLeft(5, '0')}',
      tenantId: tenantId,
      leaseId: leaseId,
      propertyId: propertyId,
      unitId: unitId,
      propertyName: propertyName,
      unitNumber: unitNumber,
      invoiceDate: issuedAt ?? now,
      dueDate: dueDate,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      amountPaid: Money.zero(currency),
      amountDue: total,
      currency: currency,
      status: status,
      lines: invoiceLines,
    );

    invoices[invoice.id] = invoice;

    if (notify && status == InvoiceStatus.issued) {
      _notify(
        NotificationType.invoiceGenerated,
        'Invoice ${invoice.invoiceNumber}',
        'An invoice of ${total.format()} is due on '
            '${dueDate.day}/${dueDate.month}/${dueDate.year}.',
        target: NotificationTarget.invoice,
        targetId: invoice.id,
      );
    }

    return invoice;
  }

  /// Section 34. Marks issued invoices overdue once their due date passes.
  ///
  /// Idempotent: running it repeatedly cannot double-apply, because it only
  /// moves ISSUED to OVERDUE.
  void markOverdueInvoices() {
    final current = now;
    for (final invoice in invoices.values) {
      if (invoice.status != InvoiceStatus.issued) continue;
      if (invoice.dueDate.isAfter(current)) continue;
      invoice.status = InvoiceStatus.overdue;
    }
  }

  // ==========================================================================
  // Payments (sections 36-41)
  // ==========================================================================

  /// Starts a payment. Section 39's flow, steps 1 to 3.
  ///
  /// Returns immediately with a non-terminal status; the outcome arrives later
  /// via [_settlePayment], mimicking a provider callback. The client is
  /// expected to poll — it is never told the result synchronously.
  PaymentIntent initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required String idempotencyKey,
    String? phoneNumber,
  }) {
    // Section 66: replaying a key must not create a second payment or charge
    // the tenant twice.
    final replayed = _idempotency[idempotencyKey];
    if (replayed != null) {
      final existing = payments[replayed]!;
      return PaymentIntent(
        paymentId: existing.id,
        status: existing.status,
        amount: existing.amount,
        providerReference: existing.providerTransactionId,
        instruction: _instructionFor(method),
      );
    }

    final invoice = invoices[invoiceId];
    if (invoice == null) throw const MockNotFound('Invoice not found');
    if (!invoice.status.isPayable) {
      throw const MockConflict('This invoice is not payable.');
    }

    _paymentSeq++;
    final payment = PaymentRow(
      id: _id('pay'),
      paymentReference: 'PMT-${_paymentSeq.toString().padLeft(5, '0')}',
      tenantId: invoice.tenantId,
      invoiceId: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      leaseId: invoice.leaseId,
      propertyId: invoice.propertyId,
      // The server charges what the invoice says is outstanding. The client
      // never supplies an amount (section 65).
      amount: invoice.amountDue,
      currency: invoice.currency,
      paymentMethod: method,
      provider: method == PaymentMethod.mpesa ? 'MPESA' : method.api,
      providerTransactionId: _providerReference(method),
      status: PaymentStatus.pending,
      createdAt: now,
      description: 'Payment for ${invoice.invoiceNumber}',
    );

    payments[payment.id] = payment;
    _idempotency[idempotencyKey] = payment.id;

    _scheduleSettlement(payment.id, phoneNumber);

    return PaymentIntent(
      paymentId: payment.id,
      status: payment.status,
      amount: payment.amount,
      providerReference: payment.providerTransactionId,
      instruction: _instructionFor(method),
    );
  }

  String _instructionFor(PaymentMethod method) => switch (method) {
    PaymentMethod.mpesa =>
      'Check your phone for the M-Pesa prompt and enter your PIN to authorise '
          'the payment.',
    PaymentMethod.card => 'Complete the payment on the card provider page.',
    PaymentMethod.bankTransfer =>
      'Use the bank reference shown to complete your transfer.',
    _ => 'Follow the instructions from your payment provider.',
  };

  String _providerReference(PaymentMethod method) {
    final random = Random();
    final suffix = List.generate(
      8,
      (_) => '0123456789ABCDEFGHIJ'[random.nextInt(20)],
    ).join();
    return method == PaymentMethod.mpesa ? 'Q$suffix' : 'TXN$suffix';
  }

  /// Simulates the provider round trip: authorisation, then a callback.
  void _scheduleSettlement(String paymentId, String? phoneNumber) {
    Timer(_paymentAuthorisationDelay, () {
      final payment = payments[paymentId];
      if (payment == null || payment.status.isTerminal) return;
      payment.status = PaymentStatus.processing;

      Timer(_paymentSettlementDelay, () {
        // A phone number ending 0000 always fails, so the failure path is
        // reachable in a demo without having to break anything.
        final shouldFail = phoneNumber != null && phoneNumber.endsWith('0000');
        if (shouldFail) {
          _failPayment(paymentId, 'The request was cancelled by the user.');
        } else {
          _settlePayment(paymentId);
        }
      });
    });
  }

  void _failPayment(String paymentId, String reason) {
    final payment = payments[paymentId];
    if (payment == null || payment.status.isTerminal) return;
    payment.status = PaymentStatus.failed;
    payment.failureReason = reason;
    _notify(
      NotificationType.paymentFailed,
      'Payment failed',
      'Payment ${payment.paymentReference} could not be completed. $reason',
      target: NotificationTarget.payment,
      targetId: payment.id,
    );
  }

  /// Section 39 steps 5 to 10, and the reason the app polls rather than
  /// assuming: everything below happens on the server, after the provider
  /// confirms, and the handset only ever observes the result.
  void _settlePayment(String paymentId) {
    final payment = payments[paymentId];
    if (payment == null || payment.status.isTerminal) return;

    payment.status = PaymentStatus.success;
    payment.paidAt = now;

    final invoice = invoices[payment.invoiceId];
    if (invoice != null) {
      // Section 37: allocate the payment to the invoice.
      final allocation = PaymentAllocation(
        id: _id('alc'),
        paymentId: payment.id,
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        amount: payment.amount,
        allocatedAt: now,
      );
      payment.allocations.add(allocation);

      invoice.amountPaid += payment.amount;
      invoice.amountDue -= payment.amount;
      invoice.status = invoice.amountDue.isPositive
          ? InvoiceStatus.partiallyPaid
          : InvoiceStatus.paid;

      // Section 41: the platform fee is recorded as its own transaction rather
      // than silently netted off, so both figures are auditable. Shared with
      // the seeding path so a settlement leaves one shape of record, whichever
      // route produced it.
      _recordSettlement(
        payment: payment,
        propertyId: invoice.propertyId,
        at: now,
      );
    }

    // Section 40: every successful payment produces a receipt.
    _receiptSeq++;
    final receipt = Receipt(
      id: _id('rcp'),
      receiptNumber: 'RCP-${_receiptSeq.toString().padLeft(5, '0')}',
      paymentId: payment.id,
      tenantId: payment.tenantId,
      propertyId: payment.propertyId,
      propertyName: invoice?.propertyName,
      amount: payment.amount,
      currency: payment.currency,
      issuedAt: now,
      paymentMethod: payment.paymentMethod,
      paymentReference: payment.paymentReference,
      documentId: _id('doc'),
    );
    receipts[receipt.id] = receipt;
    payment.receiptId = receipt.id;

    documents[receipt.documentId!] = Document(
      id: receipt.documentId!,
      documentType: DocumentType.receipt,
      fileName: '${receipt.receiptNumber}.pdf',
      mimeType: 'application/pdf',
      fileSize: 48 * 1024,
      createdAt: now,
      ownerType: 'RECEIPT',
      ownerId: receipt.id,
      hash: _hash(receipt.receiptNumber),
    );

    _notify(
      NotificationType.paymentSuccess,
      'Payment received',
      'We have received ${payment.amount.format()}. Receipt '
          '${receipt.receiptNumber} is available to download.',
      target: NotificationTarget.payment,
      targetId: payment.id,
    );

    _advanceWorkflowAfterPayment(payment, invoice);
  }

  /// Moves the leasing workflow along once money has actually landed.
  ///
  /// This is what turns section 22's flow diagram into behaviour: the booking
  /// fee activates the booking and starts the expiry clock, and the deposit
  /// satisfies the deposit requirement and generates the lease.
  void _advanceWorkflowAfterPayment(PaymentRow payment, InvoiceRow? invoice) {
    if (invoice == null) return;

    final bookingFeeBooking = bookings.values
        .where((b) => b.bookingFeeInvoiceId == invoice.id)
        .firstOrNull;

    if (bookingFeeBooking != null) {
      final config = configs[bookingFeeBooking.propertyId]!;
      bookingFeeBooking.status = BookingStatus.active;
      // Section 23: expires_at = created_at + booking_expiry_hours. The clock
      // starts now, when the hold becomes real.
      bookingFeeBooking.expiresAt = now.add(
        Duration(hours: config.bookingExpiryHours),
      );
      _refreshUnitStatus(bookingFeeBooking.unitId);

      // Section 22: with the unit held, the deposit becomes payable.
      _raiseDepositInvoice(bookingFeeBooking);
      return;
    }

    final depositBooking = bookings.values
        .where((b) => b.depositInvoiceId == invoice.id)
        .firstOrNull;

    if (depositBooking != null) {
      for (final requirement in depositBooking.requirements) {
        if (requirement.requirementType == RequirementType.payment) {
          requirement.isSatisfied = true;
          requirement.satisfiedAt = now;
        }
      }
      _maybeGenerateLease(depositBooking);
    }
  }

  void _raiseDepositInvoice(BookingRow booking) {
    if (booking.depositInvoiceId != null) return;

    final unit = units[booking.unitId]!;
    final config = configs[booking.propertyId]!;

    // Section 31: the deposit is a charge with an invoice, not a flag.
    final invoice = _raiseInvoice(
      tenantId: booking.tenantId,
      propertyId: booking.propertyId,
      unitId: booking.unitId,
      unitNumber: unit.unitNumber,
      propertyName: properties[booking.propertyId]!.name,
      dueDate: booking.expiresAt ?? now.add(const Duration(days: 2)),
      config: config,
      lines: [
        InvoiceLineDraft(
          description:
              'Security deposit — Unit ${unit.unitNumber} '
              '(${unit.depositMonths ?? config.defaultDepositMonths} months)',
          // Section 21: the deposit captured on the booking, not one
          // recalculated from today's rent.
          amount: booking.depositAmount,
          lineType: InvoiceLineType.deposit,
          referenceId: booking.id,
          taxable: false,
        ),
      ],
    );
    booking.depositInvoiceId = invoice.id;
  }

  // ==========================================================================
  // Leases (sections 26-30)
  // ==========================================================================

  /// Section 22. Generates the lease once the booking's prerequisites are met.
  void _maybeGenerateLease(BookingRow booking) {
    if (booking.leaseId != null) return;
    if (!booking.requirements
        .where((r) => r.isMandatory)
        .every((r) => r.isSatisfied)) {
      return;
    }

    final unit = units[booking.unitId]!;
    final config = configs[booking.propertyId]!;

    _leaseSeq++;
    final start = DateTime(now.year, now.month, now.day);
    final lease = LeaseRow(
      id: _id('lse'),
      leaseNumber: 'LSE-${_leaseSeq.toString().padLeft(5, '0')}',
      propertyId: booking.propertyId,
      unitId: booking.unitId,
      tenantId: booking.tenantId,
      bookingId: booking.id,
      propertyName: properties[booking.propertyId]!.name,
      unitNumber: unit.unitNumber,
      startDate: start,
      endDate: DateTime(
        start.year + 1,
        start.month,
        start.day,
      ).subtract(const Duration(days: 1)),
      // Section 55: the lease is written at the rent captured on the booking.
      monthlyRent: booking.monthlyRent,
      depositAmount: booking.depositAmount,
      billingFrequency: BillingFrequency.monthly,
      paymentDueDay: config.invoiceDueDay,
      status: LeaseStatus.pendingSignature,
      createdAt: now,
      agreementVersion: 1,
    );

    leases[lease.id] = lease;
    booking.leaseId = lease.id;

    _notify(
      NotificationType.leaseReady,
      'Lease agreement ready',
      'Your lease ${lease.leaseNumber} for Unit ${unit.unitNumber} is ready to '
          'review and sign.',
      target: NotificationTarget.lease,
      targetId: lease.id,
    );
  }

  /// Section 29. Records the tenant's signature.
  ///
  /// The lease does not become ACTIVE here. Section 30 requires the property
  /// manager's approval as well, and that happens in the web app — so this
  /// moves the lease to SIGNED and leaves activation to the other side.
  LeaseRow signLease({
    required String leaseId,
    required SignatureType signatureType,
    required String documentHash,
    required String idempotencyKey,
  }) {
    final replayed = _idempotency[idempotencyKey];
    if (replayed != null) return leases[replayed]!;

    final lease = leases[leaseId];
    if (lease == null) throw const MockNotFound('Lease not found');
    if (!lease.status.needsTenantSignature) {
      throw const MockConflict('This lease is not awaiting your signature.');
    }
    if (documentHash != _agreementHash(lease)) {
      // The tenant signed a version of the agreement that is no longer current.
      throw const MockConflict(
        'The agreement has been updated. Please review the latest version.',
      );
    }

    lease.signatures.add(
      LeaseSignature(
        id: _id('sig'),
        leaseId: lease.id,
        userId: currentUser?.id,
        signerName: currentTenant?.displayName,
        signatureType: signatureType,
        signedAt: now,
        documentHash: documentHash,
      ),
    );
    lease.signedAt = now;
    lease.status = LeaseStatus.signed;
    _idempotency[idempotencyKey] = lease.id;

    // Section 28: the signed copy is a new, immutable document version.
    final signedDocId = _id('doc');
    documents[signedDocId] = Document(
      id: signedDocId,
      documentType: DocumentType.signedLease,
      fileName: '${lease.leaseNumber}-signed.pdf',
      mimeType: 'application/pdf',
      fileSize: 320 * 1024,
      createdAt: now,
      ownerType: 'LEASE',
      ownerId: lease.id,
      version: lease.agreementVersion + 1,
      hash: documentHash,
    );
    lease.signedAgreementDocumentId = signedDocId;

    _notify(
      NotificationType.leaseSigned,
      'Lease signed',
      'Thank you. Lease ${lease.leaseNumber} has been signed and sent to the '
          'property manager for approval.',
      target: NotificationTarget.lease,
      targetId: lease.id,
    );

    // Simulates the property manager approving in the web app, so the demo can
    // continue to the billing stage without a second application.
    Timer(const Duration(seconds: 6), () => _activateLease(lease.id));

    return lease;
  }

  /// Section 30. Activation, once every mandatory condition is met.
  void _activateLease(String leaseId) {
    final lease = leases[leaseId];
    if (lease == null || lease.status != LeaseStatus.signed) return;

    final booking = lease.bookingId == null ? null : bookings[lease.bookingId!];
    final depositInvoice = booking?.depositInvoiceId == null
        ? null
        : invoices[booking!.depositInvoiceId!];

    final depositPaid = depositInvoice?.status == InvoiceStatus.paid;
    if (!depositPaid) return;

    lease.status = LeaseStatus.active;
    lease.activatedAt = now;

    if (booking != null) {
      booking.status = BookingStatus.convertedToLease;
    }
    _refreshUnitStatus(lease.unitId);

    _notify(
      NotificationType.leaseActivated,
      'Lease active',
      'Lease ${lease.leaseNumber} is now active. Unit ${lease.unitNumber} is '
          'yours.',
      target: NotificationTarget.lease,
      targetId: lease.id,
    );

    // Section 34: with the lease live, the recurring billing engine starts
    // raising rent invoices against it.
    generateRentInvoiceIfDue(lease.id, force: true);
  }

  String _agreementHash(LeaseRow lease) => _hash(
    '${lease.id}:${lease.agreementVersion}:${lease.monthlyRent.minorUnits}',
  );

  LeaseAgreementView agreementFor(String leaseId) {
    final lease = leases[leaseId];
    if (lease == null) throw const MockNotFound('Lease not found');
    return LeaseAgreementView(
      lease: lease,
      hash: _agreementHash(lease),
      body: renderAgreement(this, lease),
    );
  }

  /// Section 30's checklist, evaluated server-side.
  ///
  /// The app renders this read-only. Deciding that a lease may activate is not
  /// the client's call — it depends on payment state and on the property
  /// manager's approval, neither of which the handset can see in full.
  List<LeaseActivationCondition> conditionsFor(LeaseRow lease) {
    final booking = lease.bookingId == null ? null : bookings[lease.bookingId!];
    final depositInvoice = booking?.depositInvoiceId == null
        ? null
        : invoices[booking!.depositInvoiceId!];

    final documentsSubmitted =
        booking?.requirements
            .where(
              (r) =>
                  r.isMandatory &&
                  r.requirementType == RequirementType.document,
            )
            .every((r) => r.isSatisfied) ??
        true;

    return [
      LeaseActivationCondition(
        id: 'cond_booking',
        label: 'Booking active',
        detail: booking?.bookingReference,
        isMet:
            booking == null ||
            !booking.status.isTerminal ||
            booking.status == BookingStatus.convertedToLease,
        isMandatory: true,
      ),
      LeaseActivationCondition(
        id: 'cond_deposit',
        label: 'Deposit paid',
        detail: lease.depositAmount.format(),
        isMet: depositInvoice == null
            ? lease.status.isCurrent
            : depositInvoice.status == InvoiceStatus.paid,
        isMandatory: true,
      ),
      LeaseActivationCondition(
        id: 'cond_documents',
        label: 'Required documents submitted',
        isMet: documentsSubmitted,
        isMandatory: true,
      ),
      LeaseActivationCondition(
        id: 'cond_signature',
        label: 'Lease signed',
        detail: lease.signedAt == null ? null : 'Signed',
        isMet: lease.signedAt != null,
        isMandatory: true,
      ),
      LeaseActivationCondition(
        id: 'cond_approval',
        label: 'Approved by the property manager',
        isMet: lease.activatedAt != null,
        isMandatory: true,
      ),
    ];
  }

  // ==========================================================================
  // Documents (sections 18 and 51)
  // ==========================================================================

  Document storeDocument({
    required DocumentType type,
    required String fileName,
    required int byteLength,
    required String mimeType,
  }) {
    final id = _id('doc');
    final document = Document(
      id: id,
      documentType: type,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: byteLength,
      createdAt: now,
      ownerType: 'TENANT',
      ownerId: currentTenant?.id,
      hash: _hash('$fileName:$byteLength'),
    );
    documents[id] = document;
    return document;
  }

  /// Attaches an uploaded document to a booking requirement (section 18) and
  /// generates the lease if that was the last thing outstanding.
  BookingRequirement submitRequirementDocument({
    required String bookingId,
    required String requirementId,
    required String fileName,
    required int byteLength,
    required String mimeType,
  }) {
    final booking = bookings[bookingId];
    if (booking == null) throw const MockNotFound('Booking not found');

    final requirement = booking.requirements
        .where((r) => r.id == requirementId)
        .firstOrNull;
    if (requirement == null) {
      throw const MockNotFound('Requirement not found');
    }
    if (booking.status.isTerminal) {
      throw const MockConflict(
        'This booking is closed, so documents can no longer be submitted.',
      );
    }

    final document = storeDocument(
      type: requirement.documentType ?? DocumentType.other,
      fileName: fileName,
      byteLength: byteLength,
      mimeType: mimeType,
    );

    requirement.isSatisfied = true;
    requirement.documentId = document.id;
    requirement.satisfiedAt = now;

    _maybeGenerateLease(booking);

    return requirement.toDomain();
  }

  // ==========================================================================
  // Recurring billing (section 34)
  // ==========================================================================

  /// Generates the next rent invoice for a lease, if one is due.
  ///
  /// Idempotency is the point of this method. Section 34 requires that running
  /// the scheduler repeatedly never produces a duplicate, so the check is on
  /// the *billing period*: if an invoice already covers that period for this
  /// lease, nothing happens.
  InvoiceRow? generateRentInvoiceIfDue(String leaseId, {bool force = false}) {
    final lease = leases[leaseId];
    if (lease == null || !lease.status.isCurrent) return null;

    final config = configs[lease.propertyId]!;
    final current = now;

    if (!force && current.day != config.invoiceGenerationDay) return null;

    final periodStart = DateTime(current.year, current.month, 1);
    final periodEnd = DateTime(current.year, current.month + 1, 0);

    // The duplicate guard.
    final alreadyBilled = invoices.values.any(
      (i) =>
          i.leaseId == lease.id &&
          i.billingPeriodStart != null &&
          i.billingPeriodStart!.year == periodStart.year &&
          i.billingPeriodStart!.month == periodStart.month &&
          i.lines.any((l) => l.lineType == InvoiceLineType.rent),
    );
    if (alreadyBilled) return null;

    return _raiseInvoice(
      tenantId: lease.tenantId,
      propertyId: lease.propertyId,
      unitId: lease.unitId,
      unitNumber: lease.unitNumber,
      propertyName: lease.propertyName ?? '',
      leaseId: lease.id,
      dueDate: DateTime(current.year, current.month, config.invoiceDueDay),
      billingPeriodStart: periodStart,
      billingPeriodEnd: periodEnd,
      config: config,
      lines: [
        InvoiceLineDraft(
          description:
              'Rent — Unit ${lease.unitNumber} '
              '(${_monthName(periodStart.month)} ${periodStart.year})',
          // Section 55: the lease's rent, never the unit's current price.
          amount: lease.monthlyRent,
          lineType: InvoiceLineType.rent,
          referenceId: lease.id,
        ),
      ],
    );
  }

  static String _monthName(int month) => const [
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
  ][month - 1];

  // ==========================================================================
  // Dashboard (sections 44 and 71)
  // ==========================================================================

  DashboardSummary dashboard() {
    expireDueBookings();
    markOverdueInvoices();

    final tenantId = currentTenant?.id;
    final currency = 'KES';

    final tenantInvoices = invoices.values
        .where((i) => i.tenantId == tenantId)
        .toList();

    // Section 71: outstanding = invoiced less allocated payments. Derived from
    // transactional data rather than stored on the tenant.
    var outstanding = Money.zero(currency);
    var overdue = Money.zero(currency);
    for (final invoice in tenantInvoices) {
      if (!invoice.status.isOutstanding) continue;
      outstanding += invoice.amountDue;
      if (invoice.status == InvoiceStatus.overdue) {
        overdue += invoice.amountDue;
      }
    }

    final currentLease = leases.values
        .where((l) => l.tenantId == tenantId && l.status.isCurrent)
        .firstOrNull;

    final pendingSignature = leases.values
        .where((l) => l.tenantId == tenantId && l.status.needsTenantSignature)
        .firstOrNull;

    final activeBooking = bookings.values
        .where(
          (b) =>
              b.tenantId == tenantId &&
              !b.status.isTerminal &&
              b.status != BookingStatus.draft,
        )
        .firstOrNull;

    final upcoming = tenantInvoices.where((i) => i.status.isPayable).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextInvoice = upcoming.firstOrNull;

    final recentPayments =
        payments.values.where((p) => p.tenantId == tenantId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DashboardSummary(
      currency: currency,
      propertyId: currentLease?.propertyId,
      propertyName: currentLease?.propertyName,
      propertyImageUrl: currentLease == null
          ? null
          : properties[currentLease.propertyId]?.imageUrl,
      unitId: currentLease?.unitId,
      unitNumber: currentLease?.unitNumber,
      leaseId: currentLease?.id,
      leaseStatus: currentLease?.status,
      leaseEndDate: currentLease?.endDate,
      outstandingBalance: outstanding,
      overdueAmount: overdue,
      nextInvoice: nextInvoice?.toDomain(),
      nextInvoiceAmount: nextInvoice?.amountDue,
      nextPaymentDueDate: nextInvoice?.dueDate,
      recentPayments: recentPayments
          .take(5)
          .map((p) => p.toDomain())
          .toList(growable: false),
      activeBookingId: activeBooking?.id,
      activeBookingReference: activeBooking?.bookingReference,
      activeBookingExpiresAt: activeBooking?.expiresAt,
      pendingSignatureLeaseId: pendingSignature?.id,
      unreadNotifications: notifications.where((n) => !n.isRead).length,
    );
  }

  // ==========================================================================
  // Owner writes (section 88)
  //
  // Creating a property, filling it with units, and moving what it asks. The
  // rule that governs all of it: a rate is a *listing* price. Section 21 has a
  // booking capture its terms at booking time and section 55 has a lease carry
  // its own rent, and neither is ever re-derived — so repricing changes what
  // the empty units ask and touches nothing that has already been agreed.
  // ==========================================================================

  /// Registers a property to [ownerId], or replays the one this
  /// [idempotencyKey] already created.
  PropertyRow createProperty({
    required String ownerId,
    required PropertyDraft draft,
    required String idempotencyKey,
  }) {
    final replayed = _idempotency[idempotencyKey];
    if (replayed != null) return properties[replayed]!;

    final id = _id('prp');
    final property = PropertyRow(
      id: id,
      name: draft.name.trim(),
      code: _propertyCode(draft.name),
      propertyType: draft.propertyType,
      status: PropertyStatus.active,
      description: draft.description,
      address: draft.address,
      city: draft.city.trim(),
      county: draft.county,
      country: draft.country.trim(),
      totalArea: draft.totalArea,
      ownerId: ownerId,
      rentRatePerSqm: draft.rentRatePerSqm,
    );

    properties[id] = property;

    // Section 12. A property without config cannot raise an invoice, so it
    // gets the platform defaults rather than nothing.
    configs[id] = PropertyConfig(
      propertyId: id,
      defaultCurrency: draft.rentRatePerSqm.currency,
      bookingExpiryHours: 48,
      invoiceGenerationDay: 3,
      invoiceDueDay: 5,
      defaultDepositMonths: 3,
      defaultBookingFee: Money.fromMajor(10000, draft.rentRatePerSqm.currency),
      paymentGracePeriodDays: 5,
      platformFeePercent: 2,
    );

    _idempotency[idempotencyKey] = id;
    return property;
  }

  /// Generates [UnitBatchDraft.quantity] units, returning how many were made.
  ///
  /// Each one's rent is derived from the batch's rate if it has one, otherwise
  /// the property's. Nothing here is a listing decision the client made — the
  /// client sent an area and a count.
  int createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  }) {
    final replayed = _idempotency[idempotencyKey];
    if (replayed != null) {
      // The replay marker holds the unit type, and the units carry its id.
      return units.values.where((u) => u.unitTypeId == replayed).length;
    }

    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    final rate = draft.ratePerSqm ?? property.rentRatePerSqm;
    if (rate == null) {
      throw const MockConflict(
        'Set a rate per square metre before adding units.',
      );
    }

    final rent = rentFor(area: draft.area, ratePerSqm: rate);
    final prefix = draft.numberPrefix.trim().toUpperCase();

    // Section 16. The type is a template; section 17 makes each unit
    // independent of it afterwards.
    final typeId = _id('utp');
    unitTypes.add(
      UnitType(
        id: typeId,
        propertyId: propertyId,
        name: draft.typeName.trim(),
        code: prefix,
        description: draft.description,
        length: draft.length,
        width: draft.width,
        area: draft.area,
        baseRent: rent,
        defaultDepositMonths: draft.depositMonths,
        defaultBookingFee: draft.bookingFee,
        ratePerSqm: draft.ratePerSqm,
      ),
    );

    String? buildingId;
    if (draft.buildingName != null && draft.buildingName!.trim().isNotEmpty) {
      buildingId = _id('bld');
      buildings.add(
        Building(
          id: buildingId,
          propertyId: propertyId,
          name: draft.buildingName!.trim(),
          code: draft.buildingName!.trim().toUpperCase(),
        ),
      );
    }

    String? floorId;
    if (buildingId != null &&
        draft.floorName != null &&
        draft.floorName!.trim().isNotEmpty) {
      floorId = _id('flr');
      floors.add(
        Floor(
          id: floorId,
          buildingId: buildingId,
          name: draft.floorName!.trim(),
          floorNumber: 0,
        ),
      );
    }

    for (var i = 0; i < draft.quantity; i++) {
      final number = '$prefix-${draft.startNumber + i}';
      final id = _id('unt');
      units[id] = UnitRow(
        id: id,
        propertyId: propertyId,
        buildingId: buildingId,
        floorId: floorId,
        unitTypeId: typeId,
        unitNumber: number,
        unitCode: '${property.code}-$number',
        name: '${draft.typeName.trim()} $number',
        description: draft.description,
        length: draft.length,
        width: draft.width,
        area: draft.area,
        baseRent: rent,
        ratePerSqm: rate,
        depositMonths: draft.depositMonths,
        bookingFee: draft.bookingFee,
        status: UnitStatus.available,
        propertyName: property.name,
        buildingName: draft.buildingName?.trim(),
        floorName: draft.floorName?.trim(),
      );
    }

    _idempotency[idempotencyKey] = typeId;
    return draft.quantity;
  }

  /// Moves what a property asks per square metre.
  ///
  /// With [repriceExistingUnits], every unit that is *free to be repriced* takes
  /// the new rate. Two are not:
  ///
  /// * a unit whose rent was overridden by hand — the corner shop deliberately
  ///   priced above the rate does not silently fall back to it;
  /// * a unit under a live lease — section 55 has the lease carry its own rent
  ///   and [Unit.baseRent]'s own contract calls itself a listing price. A let
  ///   unit takes the new rate when it next comes free, not retroactively.
  ///
  /// Returns how many units were actually repriced, so the caller can say so
  /// rather than implying it touched everything.
  ({PropertyRow property, int repriced}) setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  }) {
    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    property.rentRatePerSqm = rate;
    if (!repriceExistingUnits) return (property: property, repriced: 0);

    var repriced = 0;
    for (final unit in units.values) {
      if (unit.propertyId != propertyId) continue;
      if (unit.rentOverridden) continue;
      if (_hasLiveLease(unit.id)) continue;

      final area = unit.area;
      if (area == null) continue;

      // A unit-type rate still wins over the property's.
      final effective = rateFor(
        propertyId: propertyId,
        unitTypeId: unit.unitTypeId,
      );
      if (effective != null && effective != property.rentRatePerSqm) continue;

      unit.baseRent = rentFor(area: area, ratePerSqm: rate);
      unit.ratePerSqm = rate;
      repriced++;
    }

    return (property: property, repriced: repriced);
  }

  /// How many units a repricing would move, without moving them.
  ///
  /// The confirmation needs to name a number before the owner commits, and
  /// working it out on the client would be a second implementation of the rule
  /// above, free to disagree with it.
  ({int repriceable, int overridden, int let}) repricingImpact(
    String propertyId,
  ) {
    var repriceable = 0;
    var overridden = 0;
    var let = 0;

    for (final unit in units.values) {
      if (unit.propertyId != propertyId) continue;
      if (unit.area == null) continue;
      if (unit.rentOverridden) {
        overridden++;
      } else if (_hasLiveLease(unit.id)) {
        let++;
      } else {
        repriceable++;
      }
    }

    return (repriceable: repriceable, overridden: overridden, let: let);
  }

  /// Prices one unit by hand, or clears the override and re-derives it.
  UnitRow setUnitRent({required String unitId, Money? override}) {
    final unit = units[unitId];
    if (unit == null) throw const MockNotFound('Unit not found');

    if (override != null) {
      unit.baseRent = override;
      unit.rentOverridden = true;
      return unit;
    }

    // Clearing the override puts the unit back under the property's rate.
    unit.rentOverridden = false;
    final rate = rateFor(
      propertyId: unit.propertyId,
      unitTypeId: unit.unitTypeId,
    );
    final area = unit.area;
    if (rate != null && area != null) {
      unit.baseRent = rentFor(area: area, ratePerSqm: rate);
      unit.ratePerSqm = rate;
    }
    return unit;
  }

  bool _hasLiveLease(String unitId) =>
      leases.values.any((l) => l.unitId == unitId && l.status.isCurrent);

  /// A short code from a property's name: `Sarit Mall` becomes `SARITMALL`.
  String _propertyCode(String name) {
    final letters = name.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (letters.isEmpty) return 'PROP${properties.length + 1}';
    return letters.length <= 10 ? letters : letters.substring(0, 10);
  }

  // ==========================================================================
  // Owner reporting (section 88)
  //
  // Every figure an owner screen shows is finished here. Section 84 rule 7 puts
  // totalling on the server and section 65 keeps the client out of computing
  // payable amounts; a dashboard is not an exception to either. An occupancy
  // rate or a collection rate the app worked out for itself would be a second
  // source of truth, free to disagree with the one the accounts are kept in.
  // ==========================================================================

  List<PropertyRow> propertiesOwnedBy(String ownerId) => properties.values
      .where((property) => property.ownerId == ownerId)
      .toList(growable: false);

  /// The owner's whole position.
  OwnerPortfolio ownerPortfolio(String ownerId) {
    expireDueBookings();
    markOverdueInvoices();

    final owned = propertiesOwnedBy(ownerId);
    final currency = owned.isEmpty
        ? 'KES'
        : configs[owned.first.id]?.defaultCurrency ?? 'KES';

    final performances = owned
        .map((property) => propertyPerformance(property.id))
        .toList(growable: false);

    var mix = const UnitMix();
    var area = 0.0;
    var contracted = Money.zero(currency);
    var billed = Money.zero(currency);
    var collected = Money.zero(currency);
    var outstanding = Money.zero(currency);
    var overdue = Money.zero(currency);
    // Section 41. Each property carries its own platform rate, so the fee has
    // to be taken per property and then added up — a portfolio-level
    // percentage would silently average two different contracts.
    var platformFee = Money.zero(currency);

    for (final performance in performances) {
      mix = UnitMix(
        leased: mix.leased + performance.mix.leased,
        booked: mix.booked + performance.mix.booked,
        available: mix.available + performance.mix.available,
        unavailable: mix.unavailable + performance.mix.unavailable,
      );
      area += performance.totalArea ?? 0;
      contracted += performance.monthlyContractedRent;
      billed += performance.billedThisMonth;
      collected += performance.collectedThisMonth;
      outstanding += performance.outstanding;
      overdue += performance.overdue;

      final rate = configs[performance.propertyId]?.platformFeePercent ?? 0;
      platformFee += performance.collectedThisMonth.percentage(rate);
    }

    return OwnerPortfolio(
      ownerId: ownerId,
      currency: currency,
      mix: mix,
      occupancyRate: _rateOf(mix.leased, mix.total),
      totalArea: area == 0 ? null : area,
      monthlyContractedRent: contracted,
      billedThisMonth: billed,
      collectedThisMonth: collected,
      outstanding: outstanding,
      overdue: overdue,
      collectionRate: _moneyRate(collected, billed),
      platformFee: platformFee,
      netPayout: collected - platformFee,
      properties: performances,
      history: _collectionHistory(
        propertyIds: owned.map((property) => property.id).toSet(),
        currency: currency,
      ),
      alerts: _alertsFor(owned),
    );
  }

  /// How one property is doing.
  PropertyPerformance propertyPerformance(String propertyId) {
    markOverdueInvoices();

    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    final currency = configs[propertyId]?.defaultCurrency ?? 'KES';
    final unitsHere = units.values
        .where((unit) => unit.propertyId == propertyId)
        .toList(growable: false);
    final mix = _mixFor(unitsHere);

    final activeLeases = leases.values
        .where(
          (lease) => lease.propertyId == propertyId && lease.status.isCurrent,
        )
        .toList(growable: false);

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final invoicesHere = invoices.values.where(
      (invoice) => invoice.propertyId == propertyId,
    );

    final letArea = unitsHere
        .where((unit) => unit.status == UnitStatus.leased)
        .fold<double>(0, (sum, unit) => sum + (unit.area ?? 0));

    final billed = _sum(
      invoicesHere
          .where(
            (invoice) => _within(invoice.invoiceDate, monthStart, monthEnd),
          )
          .map((invoice) => invoice.total),
      currency,
    );
    final collected = _sum(
      payments.values
          .where(
            (payment) =>
                payment.propertyId == propertyId &&
                payment.status == PaymentStatus.success &&
                payment.paidAt != null &&
                _within(payment.paidAt!, monthStart, monthEnd),
          )
          .map((payment) => payment.amount),
      currency,
    );

    final arrears = invoicesHere
        .where((invoice) => invoice.status == InvoiceStatus.overdue)
        .toList(growable: false);

    return PropertyPerformance(
      propertyId: propertyId,
      propertyName: property.name,
      imageUrl: property.imageUrl,
      currency: currency,
      mix: mix,
      occupancyRate: _rateOf(mix.leased, mix.total),
      totalArea: property.totalArea,
      letArea: letArea == 0 ? null : letArea,
      rentRatePerSqm: property.rentRatePerSqm,
      monthlyContractedRent: _sum(
        activeLeases.map((lease) => lease.monthlyRent),
        currency,
      ),
      billedThisMonth: billed,
      collectedThisMonth: collected,
      outstanding: _sum(
        invoicesHere
            .where((invoice) => invoice.status.isOutstanding)
            .map((invoice) => invoice.amountDue),
        currency,
      ),
      overdue: _sum(arrears.map((invoice) => invoice.amountDue), currency),
      collectionRate: _moneyRate(collected, billed),
      expiringLeases: activeLeases
          .where((lease) => lease.endDate.difference(now).inDays <= 60)
          .length,
      tenantsInArrears: arrears
          .map((invoice) => invoice.tenantId)
          .toSet()
          .length,
      history: _collectionHistory(
        propertyIds: {propertyId},
        currency: currency,
      ),
    );
  }

  /// Every unit in a property, with its occupant and what they owe.
  List<RentRollEntry> rentRoll(String propertyId) {
    markOverdueInvoices();

    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');
    final currency = configs[propertyId]?.defaultCurrency ?? 'KES';

    final rows =
        units.values.where((unit) => unit.propertyId == propertyId).toList()
          ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

    return rows
        .map((unit) {
          final lease = leases.values.cast<LeaseRow?>().firstWhere(
            (l) => l!.unitId == unit.id && l.status.isCurrent,
            orElse: () => null,
          );

          return RentRollEntry(
            unitId: unit.id,
            unitNumber: unit.unitNumber,
            name: unit.name,
            status: unit.status,
            area: unit.area,
            areaUnit: unit.areaUnit,
            baseRent: unit.baseRent,
            ratePerSqm: unit.ratePerSqm,
            rentOverridden: unit.rentOverridden,
            tenantId: lease?.tenantId,
            tenantName: lease == null ? null : _tenantName(lease.tenantId),
            leaseId: lease?.id,
            leaseEndDate: lease?.endDate,
            outstanding: lease == null
                ? null
                : _outstandingForTenant(lease.tenantId, propertyId, currency),
          );
        })
        .toList(growable: false);
  }

  /// Every tenancy across the owner's buildings.
  List<OwnerTenancy> tenanciesFor(String ownerId, {String? propertyId}) {
    markOverdueInvoices();

    final owned = propertiesOwnedBy(ownerId).map((p) => p.id).toSet();
    final scoped = propertyId == null
        ? owned
        : {propertyId}.intersection(owned);

    final rows =
        leases.values
            .where((lease) => scoped.contains(lease.propertyId))
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return rows
        .map((lease) {
          final currency = configs[lease.propertyId]?.defaultCurrency ?? 'KES';
          final theirInvoices = invoices.values.where(
            (invoice) =>
                invoice.tenantId == lease.tenantId &&
                invoice.propertyId == lease.propertyId,
          );

          final settled =
              payments.values
                  .where(
                    (payment) =>
                        payment.tenantId == lease.tenantId &&
                        payment.propertyId == lease.propertyId &&
                        payment.status == PaymentStatus.success &&
                        payment.paidAt != null,
                  )
                  .toList()
                ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!));

          return OwnerTenancy(
            leaseId: lease.id,
            leaseNumber: lease.leaseNumber,
            propertyId: lease.propertyId,
            propertyName: lease.propertyName ?? '',
            unitId: lease.unitId,
            unitNumber: lease.unitNumber ?? '',
            tenantId: lease.tenantId,
            tenantName: _tenantName(lease.tenantId),
            startDate: lease.startDate,
            endDate: lease.endDate,
            monthlyRent: lease.monthlyRent,
            depositAmount: lease.depositAmount,
            status: lease.status,
            outstanding: _sum(
              theirInvoices
                  .where((invoice) => invoice.status.isOutstanding)
                  .map((invoice) => invoice.amountDue),
              currency,
            ),
            overdue: _sum(
              theirInvoices
                  .where((invoice) => invoice.status == InvoiceStatus.overdue)
                  .map((invoice) => invoice.amountDue),
              currency,
            ),
            lastPaymentAt: settled.isEmpty ? null : settled.first.paidAt,
          );
        })
        .toList(growable: false);
  }

  OwnerTenancy tenancy(String ownerId, String leaseId) {
    final match = tenanciesFor(
      ownerId,
    ).where((tenancy) => tenancy.leaseId == leaseId);
    if (match.isEmpty) throw const MockNotFound('Tenancy not found');
    return match.first;
  }

  /// The demo tenant is held on [currentTenant] rather than in [tenants], so
  /// both have to be consulted.
  String _tenantName(String tenantId) {
    if (currentTenant?.id == tenantId) return currentTenant!.displayName;
    for (final session in accountsByPhone.values) {
      if (session.tenant?.id == tenantId) return session.tenant!.displayName;
    }
    return tenants[tenantId]?.displayName ?? 'Tenant';
  }

  Money _outstandingForTenant(
    String tenantId,
    String propertyId,
    String currency,
  ) => _sum(
    invoices.values
        .where(
          (invoice) =>
              invoice.tenantId == tenantId &&
              invoice.propertyId == propertyId &&
              invoice.status.isOutstanding,
        )
        .map((invoice) => invoice.amountDue),
    currency,
  );

  /// What came in, what is owed, and what is due out.
  ///
  /// The payouts are read off the ledger rather than recomputed from payments.
  /// `_recordSettlement` writes the rent in and the platform's cut back out as
  /// separate entries on every settlement, seeded or live, and that record is
  /// the auditable one — deriving the fee a second time here would be a second
  /// answer to a question that already has one.
  OwnerLedger ownerLedger(String ownerId, {int months = 6}) {
    markOverdueInvoices();

    final owned = propertiesOwnedBy(ownerId).map((p) => p.id).toSet();
    final currency = owned.isEmpty
        ? 'KES'
        : configs[owned.first]?.defaultCurrency ?? 'KES';

    // Ledger entries carry a payment reference, not a property, so the payment
    // is what places them in a portfolio.
    bool ours(FinancialTransaction entry) {
      if (entry.referenceType != 'PAYMENT') return false;
      final payment = payments[entry.referenceId];
      return payment != null && owned.contains(payment.propertyId);
    }

    final mine = ledger.where(ours).toList(growable: false);

    final payouts = <OwnerPayout>[];
    for (var back = months - 1; back >= 0; back--) {
      final start = DateTime(now.year, now.month - back, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      final inMonth = mine.where(
        (entry) => _within(entry.createdAt, start, end),
      );

      final gross = _sum(
        inMonth
            .where((entry) => entry.direction == 'IN')
            .map((entry) => entry.amount),
        currency,
      );
      final fee = _sum(
        inMonth
            .where((entry) => entry.direction == 'OUT')
            .map((entry) => entry.amount),
        currency,
      );

      payouts.add(
        OwnerPayout(
          month: start,
          grossCollected: gross,
          platformFee: fee,
          net: gross - fee,
        ),
      );
    }

    final thisMonth = payouts.isEmpty ? null : payouts.last;

    // Outstanding money, banded by how long it has been owed.
    final outstanding = invoices.values.where(
      (invoice) =>
          owned.contains(invoice.propertyId) && invoice.status.isOutstanding,
    );

    ArrearsBucket bucket(String label, bool Function(int days) test) {
      final matching = outstanding
          .where((invoice) => test(now.difference(invoice.dueDate).inDays))
          .toList(growable: false);
      return ArrearsBucket(
        label: label,
        amount: _sum(matching.map((invoice) => invoice.amountDue), currency),
        invoiceCount: matching.length,
      );
    }

    final collections =
        payments.values
            .where(
              (payment) =>
                  owned.contains(payment.propertyId) &&
                  payment.status == PaymentStatus.success &&
                  payment.paidAt != null,
            )
            .toList()
          ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!));

    return OwnerLedger(
      currency: currency,
      collectedThisMonth: thisMonth?.grossCollected ?? Money.zero(currency),
      platformFeeThisMonth: thisMonth?.platformFee ?? Money.zero(currency),
      netThisMonth: thisMonth?.net ?? Money.zero(currency),
      totalOutstanding: _sum(
        outstanding.map((invoice) => invoice.amountDue),
        currency,
      ),
      payouts: payouts,
      ageing: [
        bucket('Not yet due', (days) => days <= 0),
        bucket('1–30 days', (days) => days > 0 && days <= 30),
        bucket('31–60 days', (days) => days > 30 && days <= 60),
        bucket('Over 60 days', (days) => days > 60),
      ],
      collections: collections
          .take(30)
          .map(
            (payment) => OwnerCollection(
              paymentId: payment.id,
              paidAt: payment.paidAt!,
              amount: payment.amount,
              tenantName: _tenantName(payment.tenantId),
              propertyName: properties[payment.propertyId]?.name ?? 'Property',
              unitNumber: payment.leaseId == null
                  ? null
                  : leases[payment.leaseId]?.unitNumber,
              method: payment.paymentMethod,
              receiptId: payment.receiptId,
            ),
          )
          .toList(growable: false),
      history: _collectionHistory(propertyIds: owned, currency: currency),
    );
  }

  UnitMix _mixFor(Iterable<UnitRow> rows) {
    var leased = 0;
    var booked = 0;
    var available = 0;
    var unavailable = 0;

    for (final row in rows) {
      switch (row.status) {
        case UnitStatus.leased:
          leased++;
        case UnitStatus.reserved || UnitStatus.booked:
          booked++;
        case UnitStatus.available:
          available++;
        case _:
          unavailable++;
      }
    }

    return UnitMix(
      leased: leased,
      booked: booked,
      available: available,
      unavailable: unavailable,
    );
  }

  /// Billed against collected, month by month, oldest first.
  List<MonthlyCollection> _collectionHistory({
    required Set<String> propertyIds,
    required String currency,
    int months = 6,
  }) {
    final result = <MonthlyCollection>[];

    for (var back = months - 1; back >= 0; back--) {
      final start = DateTime(now.year, now.month - back, 1);
      final end = DateTime(start.year, start.month + 1, 1);

      result.add(
        MonthlyCollection(
          month: start,
          billed: _sum(
            invoices.values
                .where(
                  (invoice) =>
                      propertyIds.contains(invoice.propertyId) &&
                      _within(invoice.invoiceDate, start, end),
                )
                .map((invoice) => invoice.total),
            currency,
          ),
          collected: _sum(
            payments.values
                .where(
                  (payment) =>
                      propertyIds.contains(payment.propertyId) &&
                      payment.status == PaymentStatus.success &&
                      payment.paidAt != null &&
                      _within(payment.paidAt!, start, end),
                )
                .map((payment) => payment.amount),
            currency,
          ),
        ),
      );
    }

    return result;
  }

  /// What the owner should be doing something about, most urgent first.
  List<OwnerAlert> _alertsFor(List<PropertyRow> owned) {
    final owned0 = owned.map((property) => property.id).toSet();
    final alerts = <OwnerAlert>[];

    // Arrears, one alert per tenant behind rather than one per invoice.
    final behind = <String, List<InvoiceRow>>{};
    for (final invoice in invoices.values) {
      if (!owned0.contains(invoice.propertyId)) continue;
      if (invoice.status != InvoiceStatus.overdue) continue;
      behind.putIfAbsent(invoice.tenantId, () => []).add(invoice);
    }

    for (final entry in behind.entries) {
      final name = tenants[entry.key]?.displayName ?? 'A tenant';
      final currency = entry.value.first.currency;
      final total = _sum(
        entry.value.map((invoice) => invoice.amountDue),
        currency,
      );
      alerts.add(
        OwnerAlert(
          type: OwnerAlertType.arrears,
          title: name,
          detail:
              '${total.format()} overdue across '
              '${entry.value.length} invoice'
              '${entry.value.length == 1 ? '' : 's'}',
          target: NotificationTarget.invoice,
          targetId: entry.value.first.id,
        ),
      );
    }

    // Leases running out inside the notice period.
    for (final lease in leases.values) {
      if (!owned0.contains(lease.propertyId)) continue;
      if (!lease.status.isCurrent) continue;
      final days = lease.endDate.difference(now).inDays;
      if (days > 60 || days < 0) continue;
      alerts.add(
        OwnerAlert(
          type: OwnerAlertType.leaseExpiring,
          title: tenants[lease.tenantId]?.displayName ?? 'Lease expiring',
          detail: '${lease.unitNumber ?? 'A unit'} ends in $days days',
          target: NotificationTarget.lease,
          targetId: lease.id,
        ),
      );
    }

    // Vacancy, summarised per property. One line per empty unit would bury
    // everything else on a mall with a slow quarter.
    for (final property in owned) {
      final vacant = units.values
          .where(
            (unit) =>
                unit.propertyId == property.id &&
                unit.status == UnitStatus.available,
          )
          .length;
      if (vacant == 0) continue;
      alerts.add(
        OwnerAlert(
          type: OwnerAlertType.vacancy,
          title: property.name,
          detail: '$vacant unit${vacant == 1 ? '' : 's'} available to let',
          // NotificationTarget is transcribed from the spec and has no
          // property member; inventing one would break the rule that file
          // opens with. A vacancy alert is routed by its type instead, with
          // the property in targetId.
          targetId: property.id,
        ),
      );
    }

    return alerts;
  }

  static bool _within(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && value.isBefore(end);

  static Money _sum(Iterable<Money> amounts, String currency) {
    var total = Money.zero(currency);
    for (final amount in amounts) {
      // A portfolio spanning two currencies needs an explicit conversion, and
      // silently adding them would be worse than leaving one out.
      if (amount.currency != currency) continue;
      total += amount;
    }
    return total;
  }

  static double _rateOf(int part, int whole) =>
      whole == 0 ? 0 : (part / whole).clamp(0, 1);

  /// Collected over billed. A month that billed nothing has collected all of
  /// it, which is 1 rather than a division by zero.
  static double _moneyRate(Money part, Money whole) =>
      whole.isZero ? 1 : (part.minorUnits / whole.minorUnits).clamp(0, 1);

  // ==========================================================================
  // Seeding helpers
  //
  // Used only by seed_data.dart, to build a plausible history without having to
  // drive the whole workflow at startup.
  // ==========================================================================

  /// An invoice that was raised and fully settled, with its payment and receipt.
  InvoiceRow seedSettledInvoice({
    required String tenantId,
    required LeaseRow lease,
    required String description,
    required Money amount,
    required InvoiceLineType lineType,
    required DateTime issuedAt,
    required DateTime dueAt,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    final invoice = seedOpenInvoice(
      tenantId: tenantId,
      lease: lease,
      description: description,
      amount: amount,
      lineType: lineType,
      issuedAt: issuedAt,
      dueAt: dueAt,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    _paymentSeq++;
    _receiptSeq++;
    final paidAt = dueAt.subtract(const Duration(days: 1));

    final payment = PaymentRow(
      id: _id('pay'),
      paymentReference: 'PMT-${_paymentSeq.toString().padLeft(5, '0')}',
      tenantId: tenantId,
      invoiceId: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      leaseId: lease.id,
      propertyId: lease.propertyId,
      amount: invoice.total,
      currency: invoice.currency,
      paymentMethod: PaymentMethod.mpesa,
      provider: 'MPESA',
      providerTransactionId: 'Q${invoice.invoiceNumber.replaceAll('-', '')}',
      status: PaymentStatus.success,
      createdAt: paidAt,
      paidAt: paidAt,
      description: 'Payment for ${invoice.invoiceNumber}',
    );

    payment.allocations.add(
      PaymentAllocation(
        id: _id('alc'),
        paymentId: payment.id,
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        amount: invoice.total,
        allocatedAt: paidAt,
      ),
    );

    invoice.amountPaid = invoice.total;
    invoice.amountDue = Money.zero(invoice.currency);
    invoice.status = InvoiceStatus.paid;

    final receiptDocId = _id('doc');
    final receipt = Receipt(
      id: _id('rcp'),
      receiptNumber: 'RCP-${_receiptSeq.toString().padLeft(5, '0')}',
      paymentId: payment.id,
      tenantId: tenantId,
      propertyId: lease.propertyId,
      propertyName: lease.propertyName,
      amount: invoice.total,
      currency: invoice.currency,
      issuedAt: paidAt,
      paymentMethod: PaymentMethod.mpesa,
      paymentReference: payment.paymentReference,
      documentId: receiptDocId,
    );

    documents[receiptDocId] = Document(
      id: receiptDocId,
      documentType: DocumentType.receipt,
      fileName: '${receipt.receiptNumber}.pdf',
      mimeType: 'application/pdf',
      fileSize: 48 * 1024,
      createdAt: paidAt,
      ownerType: 'RECEIPT',
      ownerId: receipt.id,
      hash: _hash(receipt.receiptNumber),
    );

    payment.receiptId = receipt.id;
    payments[payment.id] = payment;
    receipts[receipt.id] = receipt;

    // A seeded settlement leaves the same trail a real one does, so the
    // payout history is not empty for everything that happened before the app
    // was opened.
    _recordSettlement(
      payment: payment,
      propertyId: lease.propertyId,
      at: paidAt,
    );

    return invoice;
  }

  /// An invoice that has been issued but not yet paid.
  InvoiceRow seedOpenInvoice({
    required String tenantId,
    required LeaseRow lease,
    required String description,
    required Money amount,
    required InvoiceLineType lineType,
    required DateTime issuedAt,
    required DateTime dueAt,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool notifyTenant = false,
  }) {
    final config = configs[lease.propertyId]!;
    return _raiseInvoice(
      tenantId: tenantId,
      propertyId: lease.propertyId,
      unitId: lease.unitId,
      unitNumber: lease.unitNumber,
      propertyName: lease.propertyName ?? '',
      leaseId: lease.id,
      dueDate: dueAt,
      issuedAt: issuedAt,
      billingPeriodStart: periodStart,
      billingPeriodEnd: periodEnd,
      config: config,
      // Seeded history must not arrive as a burst of "new invoice" alerts on
      // first launch. Only the current outstanding invoice notifies, which
      // seed_data.dart requests explicitly.
      notify: notifyTenant,
      lines: [
        InvoiceLineDraft(
          description: description,
          amount: amount,
          lineType: lineType,
          referenceId: lease.id,
          taxable: lineType != InvoiceLineType.deposit,
        ),
      ],
    );
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  void _notify(
    NotificationType type,
    String title,
    String body, {
    NotificationTarget target = NotificationTarget.none,
    String? targetId,
  }) {
    notifications.insert(
      0,
      NotificationRow(
        id: _id('ntf'),
        type: type,
        title: title,
        body: body,
        createdAt: now,
        isRead: false,
        target: target,
        targetId: targetId,
      ),
    );
  }

  /// Section 42. A minimal financial ledger entry, so both sides of a platform
  /// fee are recorded rather than one being netted away.
  void _ledger({
    required String type,
    required String referenceType,
    required String referenceId,
    required Money amount,
    required String direction,
    DateTime? at,
  }) {
    ledger.add(
      FinancialTransaction(
        id: _id('ftx'),
        transactionType: type,
        referenceType: referenceType,
        referenceId: referenceId,
        amount: amount,
        direction: direction,
        // Seeded history needs the date the money actually moved, not the
        // moment the seed ran, or six months of payouts would all land in
        // this one.
        createdAt: at ?? now,
      ),
    );
  }

  /// Records a settlement in the ledger: the rent in, and the platform's cut
  /// back out as its own line (section 41), never netted off quietly.
  void _recordSettlement({
    required PaymentRow payment,
    required String? propertyId,
    required DateTime at,
  }) {
    _ledger(
      type: 'RENT',
      referenceType: 'PAYMENT',
      referenceId: payment.id,
      amount: payment.amount,
      direction: 'IN',
      at: at,
    );

    final config = propertyId == null ? null : configs[propertyId];
    if (config == null || config.platformFeePercent <= 0) return;

    _ledger(
      type: 'SERVICE_FEE',
      referenceType: 'PAYMENT',
      referenceId: payment.id,
      amount: payment.amount.percentage(config.platformFeePercent),
      direction: 'OUT',
      at: at,
    );
  }

  /// Deterministic stand-in for a real content hash.
  static String _hash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'sha256:${hash.toRadixString(16).padLeft(8, '0')}'
        '${input.length.toRadixString(16).padLeft(4, '0')}';
  }

  String hashOf(String input) => _hash(input);

  // -------------------------------------------------------------------------
  // Invoice deferral and settlement
  // -------------------------------------------------------------------------

  /// Records a request to postpone payment.
  ///
  /// Note what does not happen: [InvoiceRow.amountDue] is untouched and the
  /// status is left alone. Deferring an invoice changes what the landlord and
  /// the tenant have agreed about *when*, not what is owed — and an overdue
  /// invoice that has been deferred is still overdue, it is simply no longer a
  /// surprise to either party.
  InvoiceRow deferInvoice({required String invoiceId, required String reason}) {
    final invoice = invoices[invoiceId];
    if (invoice == null) throw const MockNotFound('Invoice not found');
    if (invoice.status == InvoiceStatus.paid) {
      throw const MockConflict('That invoice has already been paid.');
    }

    invoice.isDeferred = true;
    invoice.deferReason = reason;

    _notify(
      NotificationType.invoiceDue,
      'Deferral requested',
      'We have passed on your request to postpone invoice '
          '${invoice.invoiceNumber}. You will hear back shortly.',
      target: NotificationTarget.invoice,
      targetId: invoice.id,
    );

    return invoice;
  }

  /// Closes an invoice against something other than a payment through the app.
  ///
  /// The landlord's side of the same conversation. The balance goes to zero
  /// because the debt is genuinely gone — settled, offset or written off — and
  /// the invoice records when, so the write-off is auditable rather than
  /// invisible.
  InvoiceRow settleInvoice(String invoiceId) {
    final invoice = invoices[invoiceId];
    if (invoice == null) throw const MockNotFound('Invoice not found');
    if (invoice.status == InvoiceStatus.paid) {
      throw const MockConflict('That invoice has already been settled.');
    }

    invoice.settledOn = _clock();
    invoice.amountPaid = invoice.total;
    invoice.amountDue = Money.zero(invoice.currency);
    invoice.status = InvoiceStatus.paid;
    invoice.isDeferred = false;

    return invoice;
  }

  // -------------------------------------------------------------------------
  // Property structure
  // -------------------------------------------------------------------------

  Building createBlock(BuildingDraft draft) {
    final property = properties[draft.propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    final block = Building(
      id: _id('blk'),
      propertyId: draft.propertyId,
      name: draft.name,
      code: _blockCode(draft.name),
      description: draft.description,
      status: draft.status,
      totalArea: draft.totalArea,
      numberOfFloors: draft.numberOfFloors,
      totalUnits: draft.totalUnits,
      leasableUnits: draft.leasableUnits,
      propertyName: property.name,
    );
    buildings.add(block);
    return block;
  }

  Building updateBlock(String blockId, BuildingDraft draft) {
    final index = buildings.indexWhere((block) => block.id == blockId);
    if (index == -1) throw const MockNotFound('Block not found');

    final existing = buildings[index];
    final updated = Building(
      id: existing.id,
      propertyId: existing.propertyId,
      name: draft.name,
      code: existing.code,
      description: draft.description,
      status: draft.status,
      totalArea: draft.totalArea,
      numberOfFloors: draft.numberOfFloors,
      totalUnits: draft.totalUnits,
      leasableUnits: draft.leasableUnits,
      propertyName: existing.propertyName,
    );
    buildings[index] = updated;

    // A renamed wing is the same wing. Every unit that names it in a list has
    // to say the new name, or the rename only half happened.
    for (final unit in units.values) {
      if (unit.buildingId == blockId) unit.buildingName = updated.name;
    }
    return updated;
  }

  /// Removes a block, refusing while units still sit in it.
  ///
  /// Deleting the wing out from under a let shop would orphan a live tenancy.
  /// The refusal names the count, because "move these eleven units first" is
  /// an instruction and "cannot delete" is not.
  void deleteBlock(String blockId) {
    final index = buildings.indexWhere((block) => block.id == blockId);
    if (index == -1) throw const MockNotFound('Block not found');

    final occupied = units.values
        .where((unit) => unit.buildingId == blockId && !unit.isDeleted)
        .length;
    if (occupied > 0) {
      throw MockConflict(
        'This block still holds $occupied ${occupied == 1 ? 'unit' : 'units'}. '
        'Move or remove them first.',
      );
    }

    buildings.removeAt(index);
    floors.removeWhere((floor) => floor.buildingId == blockId);
  }

  static String _blockCode(String name) {
    final letters = name
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0])
        .join();
    return letters.isEmpty ? 'BLK' : letters;
  }

  UnitRow createUnit(UnitDraft draft) {
    final property = properties[draft.propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    final block = draft.blockId == null
        ? null
        : buildings.where((b) => b.id == draft.blockId).firstOrNull;

    final unit = UnitRow(
      id: _id('unit'),
      propertyId: draft.propertyId,
      buildingId: draft.blockId,
      floorId: draft.floorNumber == null
          ? null
          : '${draft.blockId}:${draft.floorNumber}',
      unitNumber: draft.unitNumber,
      unitCode: draft.unitNumber,
      description: draft.description,
      length: draft.length,
      width: draft.width,
      area: draft.area,
      baseRent: draft.monthlyRent,
      status: UnitStatus.available,
      category: draft.category,
      wing: draft.wing,
      section: draft.section,
      floorNumber: draft.floorNumber,
      depositAmount: draft.depositAmount,
      serviceCharge: draft.serviceCharge,
      depositMonths: configs[draft.propertyId]?.defaultDepositMonths,
      // Entered by hand, so a later repricing of the property leaves it alone.
      rentOverridden: true,
      propertyName: property.name,
      buildingName: block?.name,
      floorName: _floorLabel(draft.floorNumber),
    );

    units[unit.id] = unit;
    return unit;
  }

  UnitRow updateUnit(String unitId, UnitDraft draft) {
    final unit = units[unitId];
    if (unit == null) throw const MockNotFound('Unit not found');

    final block = draft.blockId == null
        ? null
        : buildings.where((b) => b.id == draft.blockId).firstOrNull;

    unit.unitNumber = draft.unitNumber;
    unit.unitCode = draft.unitNumber;
    unit.description = draft.description;
    unit.category = draft.category;
    unit.length = draft.length;
    unit.width = draft.width;
    unit.area = draft.area;
    unit.baseRent = draft.monthlyRent;
    unit.rentOverridden = true;
    unit.depositAmount = draft.depositAmount;
    unit.serviceCharge = draft.serviceCharge;
    unit.wing = draft.wing;
    unit.section = draft.section;
    unit.floorNumber = draft.floorNumber;
    unit.buildingId = draft.blockId;
    unit.buildingName = block?.name;
    unit.floorId = draft.floorNumber == null
        ? null
        : '${draft.blockId}:${draft.floorNumber}';
    unit.floorName = _floorLabel(draft.floorNumber);

    return unit;
  }

  /// Retires a unit, refusing while anyone is in it.
  ///
  /// Soft, like the contract's own delete: the row stays so that the invoices
  /// and leases pointing at it still resolve. A let unit cannot be retired at
  /// all — ending a tenancy is a different act with its own consequences, and
  /// it does not happen as a side effect of tidying a list.
  void deleteUnit(String unitId) {
    final unit = units[unitId];
    if (unit == null) throw const MockNotFound('Unit not found');

    final live = leases.values.any(
      (lease) => lease.unitId == unitId && lease.status.isCurrent,
    );
    if (live) {
      throw const MockConflict(
        'This unit is let. End the tenancy before removing it.',
      );
    }

    unit.isDeleted = true;
    unit.status = UnitStatus.unavailable;
  }

  static String? _floorLabel(int? floorNumber) => switch (floorNumber) {
    null => null,
    0 => 'Ground floor',
    final level => 'Floor $level',
  };

  void updateProperty(String propertyId, PropertyDraft draft) {
    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    property.name = draft.name;
    property.propertyType = draft.propertyType;
    property.description = draft.description;
    property.address = draft.address;
    property.city = draft.city;
    property.county = draft.county;
    property.country = draft.country;
    property.totalArea = draft.totalArea;
    property.rentRatePerSqm = draft.rentRatePerSqm;
  }

  void setPropertyArchived(String propertyId, {required bool archived}) {
    final property = properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');

    if (archived) {
      final live = leases.values.any(
        (lease) =>
            lease.status.isCurrent &&
            units[lease.unitId]?.propertyId == propertyId,
      );
      if (live) {
        throw const MockConflict(
          'This property still has live tenancies. Archiving it would strand '
          'them.',
        );
      }
    }

    property.status = archived
        ? PropertyStatus.archived
        : PropertyStatus.active;
  }
}

/// Raised when a state transition is no longer legal, e.g. two tenants racing
/// for the last unit (section 48).
class MockConflict implements Exception {
  const MockConflict(this.message);
  final String message;
}

class MockNotFound implements Exception {
  const MockNotFound(this.message);
  final String message;
}

/// A lease agreement plus the hash of the exact version rendered.
class LeaseAgreementView {
  const LeaseAgreementView({
    required this.lease,
    required this.hash,
    required this.body,
  });

  final LeaseRow lease;
  final String hash;
  final String body;
}
