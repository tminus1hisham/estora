import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/services/mock/mock_records.dart';
import 'package:mall/services/mock/mock_repositories.dart';
import 'package:mall/services/mock/mock_server.dart';

/// Section 93's booking cases.
///
/// These run against [MockServer] rather than a widget tree, because the rules
/// being checked are server rules — availability, idempotency, expiry, terms
/// capture. The mock is where they are implemented, so it is where they are
/// asserted; when the real backend lands these become its contract tests.
void main() {
  late MockServer server;
  late MockBookingRepository bookings;
  late MockUnitRepository units;

  /// Settles payments almost immediately so a test does not wait eight seconds
  /// for the simulated provider round trip.
  MockServer buildServer({DateTime Function()? clock}) => MockServer(
    paymentAuthorisationDelay: const Duration(milliseconds: 1),
    paymentSettlementDelay: const Duration(milliseconds: 1),
    clock: clock,
  );

  setUp(() {
    server = buildServer();
    bookings = MockBookingRepository(server);
    units = MockUnitRepository(server);
  });

  group('availability', () {
    test('an available unit can be booked', () async {
      final result = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );

      expect(result.isOk, isTrue);
      expect(result.value.status, BookingStatus.pendingPayment);
      expect(result.value.bookingReference, startsWith('BKG-'));
    });

    test('a leased unit cannot be booked', () async {
      // SHOP-101 is let to the seeded demo tenant.
      final result = await bookings.createBooking(
        unitId: 'unt_shop_101',
        idempotencyKey: 'key-1',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('a unit under maintenance cannot be booked', () async {
      final result = await bookings.createBooking(
        unitId: 'unt_shop_105',
        idempotencyKey: 'key-1',
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('a unit cannot be double-booked', () async {
      final first = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );
      expect(first.isOk, isTrue);

      // A different tenant intent, a different key -- so this is genuinely a
      // second booking attempt, not an idempotent replay.
      final second = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-2',
      );

      expect(second.isErr, isTrue);
      expect(second.failureOrNull, isA<ConflictFailure>());
    });

    test('a booked unit disappears from the available list', () async {
      final before = await units.listUnits();
      expect(before.value.items.map((u) => u.id), contains('unt_shop_102'));

      await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );

      final after = await units.listUnits();
      expect(
        after.value.items.map((u) => u.id),
        isNot(contains('unt_shop_102')),
      );
    });
  });

  group('idempotency (section 66)', () {
    test(
      'replaying a key returns the original booking, not a second one',
      () async {
        final first = await bookings.createBooking(
          unitId: 'unt_shop_102',
          idempotencyKey: 'same-key',
        );
        final replay = await bookings.createBooking(
          unitId: 'unt_shop_102',
          idempotencyKey: 'same-key',
        );

        expect(replay.isOk, isTrue);
        expect(replay.value.id, first.value.id);
        expect(replay.value.bookingReference, first.value.bookingReference);
        expect(server.bookings.length, 1);
      },
    );

    test('replaying a payment key does not charge twice', () async {
      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'booking-key',
      );
      final invoiceId = booking.value.bookingFeeInvoiceId!;
      final payments = MockPaymentRepository(server);

      final first = await payments.initiatePayment(
        invoiceId: invoiceId,
        method: PaymentMethod.mpesa,
        idempotencyKey: 'payment-key',
      );
      final replay = await payments.initiatePayment(
        invoiceId: invoiceId,
        method: PaymentMethod.mpesa,
        idempotencyKey: 'payment-key',
      );

      expect(replay.value.paymentId, first.value.paymentId);
      // Counted against this invoice specifically: the seeded tenant already
      // has settled payments on their existing lease.
      expect(
        server.payments.values.where((p) => p.invoiceId == invoiceId).length,
        1,
      );
    });
  });

  group('terms capture (section 21)', () {
    test('the booking stores the section 80 figures', () async {
      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );

      expect(booking.value.monthlyRent, Money.fromMajor(150000, 'KES'));
      expect(booking.value.depositAmount, Money.fromMajor(750000, 'KES'));
      expect(booking.value.bookingFee, Money.fromMajor(20000, 'KES'));
    });

    test('a later rent change does not alter an existing booking', () async {
      final booking = await bookings.createBooking(
        unitId: 'unt_shop_103',
        idempotencyKey: 'key-1',
      );
      final rentAtBooking = booking.value.monthlyRent;

      // The property manager raises the listed rent. Replacing the row rather
      // than mutating it, because the row's price is final -- which is itself
      // the point: a price is superseded, never edited in place.
      final unit = server.units['unt_shop_103']!;
      server.units['unt_shop_103'] = UnitRow(
        id: unit.id,
        propertyId: unit.propertyId,
        buildingId: unit.buildingId,
        floorId: unit.floorId,
        unitTypeId: unit.unitTypeId,
        unitNumber: unit.unitNumber,
        unitCode: unit.unitCode,
        name: unit.name,
        baseRent: Money.fromMajor(999999, 'KES'),
        depositMonths: unit.depositMonths,
        bookingFee: unit.bookingFee,
        status: unit.status,
        requirements: unit.requirements,
      );

      final reread = await bookings.getBooking(booking.value.id);
      expect(reread.value.monthlyRent, rentAtBooking);
      expect(reread.value.monthlyRent, isNot(Money.fromMajor(999999, 'KES')));
    });
  });

  group('expiry (section 23)', () {
    test(
      'the hold clock starts when the fee is paid, not at creation',
      () async {
        final booking = await bookings.createBooking(
          unitId: 'unt_shop_102',
          idempotencyKey: 'key-1',
        );

        // Nothing paid yet, so nothing is being held yet.
        expect(booking.value.expiresAt, isNull);

        await _payInvoice(server, booking.value.bookingFeeInvoiceId!);

        final active = await bookings.getBooking(booking.value.id);
        expect(active.value.status, BookingStatus.active);
        expect(active.value.expiresAt, isNotNull);

        // Section 80's configuration: 48 hours.
        final hold = active.value.expiresAt!.difference(server.now);
        expect(hold.inHours, closeTo(48, 1));
      },
    );

    test('an expired booking releases the unit but is not deleted', () async {
      var now = DateTime(2026, 9, 1, 9);
      server = buildServer(clock: () => now);
      bookings = MockBookingRepository(server);
      units = MockUnitRepository(server);

      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );
      await _payInvoice(server, booking.value.bookingFeeInvoiceId!);

      // Past the 48-hour hold.
      now = now.add(const Duration(hours: 49));

      final expired = await bookings.getBooking(booking.value.id);
      expect(expired.value.status, BookingStatus.expired);

      // Section 23: the record survives.
      expect(server.bookings.containsKey(booking.value.id), isTrue);

      // And the unit is bookable again.
      final available = await units.listUnits();
      expect(available.value.items.map((u) => u.id), contains('unt_shop_102'));
    });

    test('a booking that has not expired keeps its hold', () async {
      var now = DateTime(2026, 9, 1, 9);
      server = buildServer(clock: () => now);
      bookings = MockBookingRepository(server);

      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );
      await _payInvoice(server, booking.value.bookingFeeInvoiceId!);

      now = now.add(const Duration(hours: 47));

      final still = await bookings.getBooking(booking.value.id);
      expect(still.value.status, BookingStatus.active);
    });
  });

  group('payment activates the booking (section 22)', () {
    test(
      'paying the fee makes the booking active and raises the deposit',
      () async {
        final booking = await bookings.createBooking(
          unitId: 'unt_shop_102',
          idempotencyKey: 'key-1',
        );

        await _payInvoice(server, booking.value.bookingFeeInvoiceId!);

        final active = await bookings.getBooking(booking.value.id);
        expect(active.value.status, BookingStatus.active);

        // Section 31: the deposit arrives as an invoice, not a flag.
        expect(active.value.depositInvoiceId, isNotNull);
        final depositInvoice = server.invoices[active.value.depositInvoiceId!]!;
        expect(depositInvoice.total, Money.fromMajor(750000, 'KES'));
      },
    );

    test('the unit reads as reserved while the booking is active', () async {
      final booking = await bookings.createBooking(
        unitId: 'unt_shop_102',
        idempotencyKey: 'key-1',
      );
      await _payInvoice(server, booking.value.bookingFeeInvoiceId!);

      final unit = await units.getUnit('unt_shop_102');
      expect(unit.value.status, UnitStatus.reserved);
      expect(unit.value.isBookable, isFalse);
    });
  });

  group('quotes (section 65)', () {
    test(
      'the server supplies the total rather than the client summing it',
      () async {
        final quote = await bookings.getQuote('unt_shop_102');

        // Sarit Mall has tax disabled, so the total is the fee.
        expect(quote.value.bookingFee, Money.fromMajor(20000, 'KES'));
        expect(quote.value.total, Money.fromMajor(20000, 'KES'));
        expect(quote.value.expiryHours, 48);
        expect(quote.value.depositMonths, 5);
      },
    );

    test('a taxed property returns fee plus tax in the total', () async {
      // ABC Business Centre: 16% VAT, and a booking fee of 10% of rent.
      final quote = await bookings.getQuote('unt_abc_3a');

      expect(quote.value.bookingFee, Money.fromMajor(8500, 'KES'));
      expect(quote.value.taxAmount, Money.fromMajor(1360, 'KES'));
      expect(quote.value.total, Money.fromMajor(9860, 'KES'));
    });

    test('quoting an unavailable unit is refused', () async {
      final quote = await bookings.getQuote('unt_shop_101');
      expect(quote.failureOrNull, isA<ConflictFailure>());
    });
  });
}

/// Drives a payment through to settlement.
Future<void> _payInvoice(MockServer server, String invoiceId) async {
  final payments = MockPaymentRepository(server);
  await payments.initiatePayment(
    invoiceId: invoiceId,
    method: PaymentMethod.mpesa,
    idempotencyKey: 'pay-$invoiceId',
  );
  // The mock settles on a timer, mimicking a provider callback.
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
