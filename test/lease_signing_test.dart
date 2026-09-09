import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/services/mock/mock_repositories.dart';
import 'package:mall/services/mock/mock_server.dart';

/// Section 93's lease cases, covering sections 28 to 30.

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
  late MockLeaseRepository leases;
  late MockBookingRepository bookings;
  late MockPaymentRepository payments;

  MockServer buildServer() => MockServer(
    paymentAuthorisationDelay: const Duration(milliseconds: 1),
    paymentSettlementDelay: const Duration(milliseconds: 1),
  );

  setUp(() {
    server = buildServer();
    leases = MockLeaseRepository(server);
    bookings = MockBookingRepository(server);
    payments = MockPaymentRepository(server);
  });

  /// Walks a unit through to a lease sitting in PENDING_SIGNATURE.
  Future<String> leaseAwaitingSignature() async {
    final booking = await bookings.createBooking(
      unitId: 'unt_shop_102',
      applicant: _applicant,
      idempotencyKey: 'booking-key',
    );

    await payments.initiatePayment(
      invoiceId: booking.value.bookingFeeInvoiceId!,
      method: PaymentMethod.mpesa,
      amount: _statedAmount,
      idempotencyKey: 'fee-key',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final active = await bookings.getBooking(booking.value.id);
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

    await payments.initiatePayment(
      invoiceId: active.value.depositInvoiceId!,
      method: PaymentMethod.mpesa,
      amount: _statedAmount,
      idempotencyKey: 'deposit-key',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final withLease = await bookings.getBooking(booking.value.id);
    return withLease.value.leaseId!;
  }

  group('the agreement (sections 28 and 29)', () {
    test('is rendered with a version and a hash', () async {
      final leaseId = await leaseAwaitingSignature();
      final agreement = await leases.getAgreement(leaseId);

      expect(agreement.isOk, isTrue);
      expect(agreement.value.version, 1);
      expect(agreement.value.documentHash, isNotEmpty);
      expect(agreement.value.body, isNotNull);
    });

    test('substitutes the template variables from section 28', () async {
      final leaseId = await leaseAwaitingSignature();
      final agreement = await leases.getAgreement(leaseId);
      final body = agreement.value.body!;

      expect(body, contains('Sarit Mall'));
      expect(body, contains('SHOP-102'));
      expect(body, contains('KES 150,000'));
      expect(body, contains('KES 750,000'));
      // No placeholder should survive rendering.
      expect(body, isNot(contains('{{')));
    });

    test('the same lease yields a stable hash across reads', () async {
      final leaseId = await leaseAwaitingSignature();
      final first = await leases.getAgreement(leaseId);
      final second = await leases.getAgreement(leaseId);

      expect(second.value.documentHash, first.value.documentHash);
    });
  });

  group('signing (section 29)', () {
    test('records the signature and moves the lease to SIGNED', () async {
      final leaseId = await leaseAwaitingSignature();
      final agreement = await leases.getAgreement(leaseId);

      final signed = await leases.signLease(
        leaseId: leaseId,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: agreement.value.documentHash,
        idempotencyKey: 'sign-key',
      );

      expect(signed.isOk, isTrue);
      expect(signed.value.status, LeaseStatus.signed);
      expect(signed.value.signedAt, isNotNull);
      expect(signed.value.signatures, hasLength(1));
      expect(
        signed.value.signatures.first.signatureType,
        SignatureType.drawnSignature,
      );
      // Section 85: the signature is bound to the exact version signed.
      expect(
        signed.value.signatures.first.documentHash,
        agreement.value.documentHash,
      );
    });

    test(
      'signing does not activate the lease on its own (section 30)',
      () async {
        final leaseId = await leaseAwaitingSignature();
        final agreement = await leases.getAgreement(leaseId);

        final signed = await leases.signLease(
          leaseId: leaseId,
          signatureType: SignatureType.drawnSignature,
          signatureData: const [1, 2, 3],
          documentHash: agreement.value.documentHash,
          idempotencyKey: 'sign-key',
        );

        // The property manager's approval is still outstanding, so the lease is
        // signed but not active.
        expect(signed.value.status, isNot(LeaseStatus.active));
        expect(signed.value.activatedAt, isNull);

        final approval = signed.value.activationConditions.firstWhere(
          (c) => c.id == 'cond_approval',
        );
        expect(approval.isMet, isFalse);
      },
    );

    test('a stale document hash is rejected', () async {
      final leaseId = await leaseAwaitingSignature();

      final result = await leases.signLease(
        leaseId: leaseId,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        // A hash from a version that is not the current one.
        documentHash: 'sha256:staleversion',
        idempotencyKey: 'sign-key',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(server.leases[leaseId]!.signatures, isEmpty);
    });

    test('replaying the sign key does not add a second signature', () async {
      final leaseId = await leaseAwaitingSignature();
      final agreement = await leases.getAgreement(leaseId);

      await leases.signLease(
        leaseId: leaseId,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: agreement.value.documentHash,
        idempotencyKey: 'sign-key',
      );
      final replay = await leases.signLease(
        leaseId: leaseId,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: agreement.value.documentHash,
        idempotencyKey: 'sign-key',
      );

      expect(replay.isOk, isTrue);
      expect(server.leases[leaseId]!.signatures, hasLength(1));
    });

    test('a lease not awaiting signature cannot be signed again', () async {
      // The seeded lease is already active.
      final active = server.leases.values.firstWhere(
        (l) => l.status == LeaseStatus.active,
      );
      final agreement = await leases.getAgreement(active.id);

      final result = await leases.signLease(
        leaseId: active.id,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: agreement.value.documentHash,
        idempotencyKey: 'sign-key',
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('signing produces an immutable signed copy (section 28)', () async {
      final leaseId = await leaseAwaitingSignature();
      final agreement = await leases.getAgreement(leaseId);

      await leases.signLease(
        leaseId: leaseId,
        signatureType: SignatureType.drawnSignature,
        signatureData: const [1, 2, 3],
        documentHash: agreement.value.documentHash,
        idempotencyKey: 'sign-key',
      );

      final lease = server.leases[leaseId]!;
      expect(lease.signedAgreementDocumentId, isNotNull);

      final document = server.documents[lease.signedAgreementDocumentId!]!;
      expect(document.documentType, DocumentType.signedLease);
      // A new version, not an edit of the original.
      expect(document.version, greaterThan(agreement.value.version));
      expect(document.hash, agreement.value.documentHash);
    });
  });

  group('the activation checklist (section 30)', () {
    test('is complete only once every condition is met', () async {
      final leaseId = await leaseAwaitingSignature();

      final beforeSigning = await leases.getLease(leaseId);
      expect(beforeSigning.value.allConditionsMet, isFalse);

      final signatureCondition = beforeSigning.value.activationConditions
          .firstWhere((c) => c.id == 'cond_signature');
      expect(signatureCondition.isMet, isFalse);

      // The deposit was paid on the way here, so that one is already satisfied.
      final depositCondition = beforeSigning.value.activationConditions
          .firstWhere((c) => c.id == 'cond_deposit');
      expect(depositCondition.isMet, isTrue);
    });
  });
}
