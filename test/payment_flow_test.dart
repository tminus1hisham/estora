import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/services/mock/mock_repositories.dart';
import 'package:mall/services/mock/mock_server.dart';

/// Section 93's payment cases, plus the invoice rules from sections 32 to 35.
///
/// The recurring theme is that the client observes rather than decides.
/// Initiating a payment returns a non-terminal status; the outcome only appears
/// once the simulated provider callback has run, which is exactly the shape
/// section 39 requires of the real thing.
/// The applicant every booking in this file is made by.
///
/// The published contract wants the person on the request rather than read off
/// the session. None of these cases turn on who is asking, so one stand-in
/// serves them all and keeps the assertions about what they are about.
const _applicant = BookingApplicant(
  fullName: 'Amina Wanjiru',
  phoneNumber: '254712345678',
  email: 'amina@example.co.ke',
);

/// The amount passed to `initiatePayment`.
///
/// Deliberately not the invoice total. The contract requires a figure on the
/// request, and the mock server ignores it and charges what the invoice says —
/// which is the behaviour these tests exist to hold. If a change ever made the
/// client's figure decide the charge, the assertions below would break, and
/// that is the point.
final _statedAmount = Money.fromMajor(1, 'KES');

void main() {
  late MockServer server;
  late MockPaymentRepository payments;
  late MockInvoiceRepository invoices;
  late MockBookingRepository bookings;
  late MockReceiptRepository receipts;

  /// Authorisation is deliberately slower than the mock repository's own
  /// latency, so a fetch issued straight after initiating still lands while the
  /// payment is in flight. That is what makes the "must poll" assertion below
  /// meaningful rather than a race.
  MockServer buildServer() => MockServer(
    paymentAuthorisationDelay: const Duration(milliseconds: 1200),
    paymentSettlementDelay: const Duration(milliseconds: 200),
  );

  setUp(() {
    server = buildServer();
    payments = MockPaymentRepository(server);
    invoices = MockInvoiceRepository(server);
    bookings = MockBookingRepository(server);
    receipts = MockReceiptRepository(server);
  });

  /// The seeded outstanding rent invoice.
  String outstandingInvoiceId() =>
      server.invoices.values.firstWhere((i) => i.status.isPayable).id;

  /// Waits out the simulated provider round trip.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 2000));

  group('payment lifecycle (section 39)', () {
    test('initiating returns a non-terminal status, never success', () async {
      final intent = await payments.initiatePayment(
        invoiceId: outstandingInvoiceId(),
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
      );

      expect(intent.isOk, isTrue);
      // The handset is told a payment exists, not that it worked.
      expect(intent.value.status.isTerminal, isFalse);
      expect(intent.value.status, PaymentStatus.pending);
      expect(intent.value.instruction, isNotNull);
    });

    test('polling reaches success only after the provider settles', () async {
      final invoiceId = outstandingInvoiceId();
      final intent = await payments.initiatePayment(
        invoiceId: invoiceId,
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
      );

      final immediately = await payments.getPayment(intent.value.paymentId);
      expect(immediately.value.status.isTerminal, isFalse);

      await settle();

      final settled = await payments.getPayment(intent.value.paymentId);
      expect(settled.value.status, PaymentStatus.success);
      expect(settled.value.paidAt, isNotNull);
      expect(settled.value.providerTransactionId, isNotNull);
    });

    test('a failing handset yields FAILED, not success', () async {
      final intent = await payments.initiatePayment(
        invoiceId: outstandingInvoiceId(),
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
        // The mock fails any number ending 0000, so the unhappy path is
        // reachable without breaking anything.
        phoneNumber: '+254700000000',
      );

      await settle();

      final settled = await payments.getPayment(intent.value.paymentId);
      expect(settled.value.status, PaymentStatus.failed);
      expect(settled.value.failureReason, isNotNull);
      expect(settled.value.receiptId, isNull);
    });

    test('a failed payment leaves the invoice untouched', () async {
      final invoiceId = outstandingInvoiceId();
      final before = await invoices.getInvoice(invoiceId);

      await payments.initiatePayment(
        invoiceId: invoiceId,
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
        phoneNumber: '+254700000000',
      );
      await settle();

      final after = await invoices.getInvoice(invoiceId);
      expect(after.value.status, before.value.status);
      expect(after.value.amountDue, before.value.amountDue);
      expect(after.value.amountPaid, before.value.amountPaid);
    });
  });

  group('allocation and receipts (sections 37 and 40)', () {
    test(
      'a settled payment allocates to the invoice and marks it paid',
      () async {
        final invoiceId = outstandingInvoiceId();
        final intent = await payments.initiatePayment(
          invoiceId: invoiceId,
          method: PaymentMethod.mpesa,
          amount: _statedAmount,
          idempotencyKey: 'key-1',
        );
        await settle();

        final invoice = await invoices.getInvoice(invoiceId);
        expect(invoice.value.status, InvoiceStatus.paid);
        expect(invoice.value.amountDue.isZero, isTrue);
        expect(invoice.value.amountPaid, invoice.value.total);

        final payment = await payments.getPayment(intent.value.paymentId);
        expect(payment.value.allocations, hasLength(1));
        expect(payment.value.allocations.first.invoiceId, invoiceId);
      },
    );

    test('every successful payment produces a receipt', () async {
      final intent = await payments.initiatePayment(
        invoiceId: outstandingInvoiceId(),
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
      );
      await settle();

      final receipt = await receipts.getReceiptForPayment(
        intent.value.paymentId,
      );
      expect(receipt.isOk, isTrue);
      expect(receipt.value.receiptNumber, startsWith('RCP-'));
      // Section 40: downloadable as a PDF.
      expect(receipt.value.documentId, isNotNull);
      expect(
        server.documents[receipt.value.documentId!]!.documentType,
        DocumentType.receipt,
      );
    });

    test(
      'the platform fee is recorded as its own entry, not netted off',
      () async {
        final invoiceId = outstandingInvoiceId();
        final invoice = server.invoices[invoiceId]!;

        await payments.initiatePayment(
          invoiceId: invoiceId,
          method: PaymentMethod.mpesa,
          amount: _statedAmount,
          idempotencyKey: 'key-1',
        );
        await settle();

        // Section 41: both sides of the split exist.
        final incoming = server.ledger.where(
          (t) => t.direction == 'IN' && t.referenceType == 'PAYMENT',
        );
        final fees = server.ledger.where(
          (t) => t.transactionType == 'SERVICE_FEE',
        );

        expect(incoming, isNotEmpty);
        expect(fees, isNotEmpty);
        // Sarit Mall's configured 2%.
        expect(fees.last.amount, invoice.total.percentage(2));
        // And the gross was recorded in full, not reduced by the fee.
        expect(incoming.last.amount, invoice.total);
      },
    );
  });

  group('invoice rules', () {
    test(
      'an invoice carries its lines, not just a total (section 33)',
      () async {
        final invoice = await invoices.getInvoice(outstandingInvoiceId());
        expect(invoice.value.lines, isNotEmpty);
        expect(invoice.value.lines.first.lineType, InvoiceLineType.rent);
      },
    );

    test('a rent invoice states its billing period (section 35)', () async {
      final invoice = await invoices.getInvoice(outstandingInvoiceId());
      expect(invoice.value.hasBillingPeriod, isTrue);
      expect(
        invoice.value.billingPeriodStart!.isBefore(
          invoice.value.billingPeriodEnd!,
        ),
        isTrue,
      );
    });

    test('rent invoice generation is idempotent (section 34)', () async {
      final lease = server.leases.values.firstWhere((l) => l.status.isCurrent);
      final before = server.invoices.length;

      // The scheduler runs daily; running it repeatedly in the same period must
      // not produce a second invoice for that period.
      server.generateRentInvoiceIfDue(lease.id, force: true);
      server.generateRentInvoiceIfDue(lease.id, force: true);
      server.generateRentInvoiceIfDue(lease.id, force: true);

      expect(server.invoices.length, before);
    });

    test('an unpayable invoice cannot be paid', () async {
      final paid = server.invoices.values.firstWhere(
        (i) => i.status == InvoiceStatus.paid,
      );

      final result = await payments.initiatePayment(
        invoiceId: paid.id,
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'key-1',
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test(
      'a paid invoice keeps the figures it was issued with (section 55)',
      () async {
        final invoiceId = outstandingInvoiceId();
        final before = await invoices.getInvoice(invoiceId);
        final originalTotal = before.value.total;

        await payments.initiatePayment(
          invoiceId: invoiceId,
          method: PaymentMethod.mpesa,
          amount: _statedAmount,
          idempotencyKey: 'key-1',
        );
        await settle();

        final after = await invoices.getInvoice(invoiceId);
        expect(after.value.total, originalTotal);
        expect(after.value.subtotal, before.value.subtotal);
        expect(after.value.lines.first.amount, before.value.lines.first.amount);
      },
    );
  });

  group('the deposit path (sections 22, 30 and 31)', () {
    test('paying the deposit generates a lease awaiting signature', () async {
      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        applicant: _applicant,
        idempotencyKey: 'booking-key',
      );

      // Booking fee.
      await payments.initiatePayment(
        invoiceId: booking.value.bookingFeeInvoiceId!,
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'fee-key',
      );
      await settle();

      final active = await bookings.getBooking(booking.value.id);

      // Section 18's document requirements still have to be met.
      for (final requirement in active.value.requirements.where(
        (r) => r.requirementType == RequirementType.document && r.isMandatory,
      )) {
        server.submitRequirementDocument(
          bookingId: booking.value.id,
          requirementId: requirement.id,
          fileName: 'doc.pdf',
          byteLength: 1024,
          mimeType: 'application/pdf',
        );
      }

      // Deposit.
      await payments.initiatePayment(
        invoiceId: active.value.depositInvoiceId!,
        method: PaymentMethod.mpesa,
        amount: _statedAmount,
        idempotencyKey: 'deposit-key',
      );
      await settle();

      final withLease = await bookings.getBooking(booking.value.id);
      expect(withLease.value.leaseId, isNotNull);

      final lease = server.leases[withLease.value.leaseId!]!;
      expect(lease.status, LeaseStatus.pendingSignature);
      // Section 21 carried through into the lease.
      expect(lease.monthlyRent, Money.fromMajor(150000, 'KES'));
      expect(lease.depositAmount, Money.fromMajor(750000, 'KES'));
    });
  });
}
