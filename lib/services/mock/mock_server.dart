import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import 'agreement_template.dart';
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

  final Map<String, Property> properties = {};
  final List<Building> buildings = [];
  final List<Floor> floors = [];
  final List<UnitType> unitTypes = [];
  final Map<String, PropertyConfig> configs = {};

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
  final Map<String, String> _idempotency = {};

  /// Sequence counters behind the human-readable references in section 69.
  int _bookingSeq = 0;
  int _invoiceSeq = 0;
  int _paymentSeq = 0;
  int _receiptSeq = 0;
  int _leaseSeq = 0;

  AppUser? currentUser;
  Tenant? currentTenant;

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

  // ==========================================================================
  // Auth
  // ==========================================================================

  String requestOtp(String phone) {
    final challengeId = _id('chg');
    otpChallenges[challengeId] = phone;
    return challengeId;
  }

  /// Returns null when the challenge is unknown or the code is wrong.
  AuthSession? verifyOtp(String challengeId, String code) {
    if (!otpChallenges.containsKey(challengeId)) return null;
    if (code.trim() != demoOtp) return null;
    otpChallenges.remove(challengeId);
    return AuthSession(user: currentUser!, tenant: currentTenant);
  }

  AuthSession? loginWithPassword(String email, String password) {
    // The seeded demo account. Any non-empty password is accepted; this is a
    // mock, and the real check belongs on the server.
    if (email.trim().isEmpty || password.isEmpty) return null;
    return AuthSession(user: currentUser!, tenant: currentTenant);
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

      _ledger(
        type: 'RENT',
        referenceType: 'PAYMENT',
        referenceId: payment.id,
        amount: payment.amount,
        direction: 'IN',
      );

      // Section 41: the platform fee is recorded as its own transaction rather
      // than silently netted off, so both figures are auditable.
      final config = configs[invoice.propertyId];
      if (config != null && config.platformFeePercent > 0) {
        final fee = payment.amount.percentage(config.platformFeePercent);
        _ledger(
          type: 'SERVICE_FEE',
          referenceType: 'PAYMENT',
          referenceId: payment.id,
          amount: fee,
          direction: 'OUT',
        );
      }
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
  }) {
    ledger.add(
      FinancialTransaction(
        id: _id('ftx'),
        transactionType: type,
        referenceType: referenceType,
        referenceId: referenceId,
        amount: amount,
        direction: direction,
        createdAt: now,
      ),
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
