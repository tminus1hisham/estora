import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/payments/presentation/widgets/mpesa_payment_sheet.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// The two STK routes and the bookings list, against the shapes the contract
/// publishes for them — and the sheet that fronts them, against a server
/// whose answers are scripted.

class _Tokens implements TokenStore {
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens tokens) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}

/// Two bookings as the live route returns them: the older one paid and
/// active, the newer one still waiting on its fee.
const _bookings = [
  {
    'id': 7,
    'propertyId': 2,
    'unitId': 11,
    'blockId': 2,
    'fullName': 'Amina Njeri',
    'phoneNumber': '254712345678',
    'email': 'amina@example.com',
    'status': 1,
    'bookingFee': 5000,
    'monthlyRent': 45000,
    'depositAmount': 90000,
    'isPaid': true,
    'bookingDate': '2026-09-01T09:00:00Z',
    'expiryDate': '2026-09-08T09:00:00Z',
    'property': {'propertyName': 'Grace Mall'},
    'unit': {'unitNumber': 'U11'},
  },
  {
    'id': 9,
    'propertyId': 2,
    'unitId': 12,
    'blockId': 2,
    'fullName': 'Amina Njeri',
    'phoneNumber': '254712345678',
    'email': 'amina@example.com',
    'status': 0,
    'bookingFee': 5000,
    'monthlyRent': 52000,
    'depositAmount': 104000,
    'isPaid': false,
    'bookingDate': '2026-09-16T09:00:00Z',
    'property': {'propertyName': 'Grace Mall'},
    'unit': {'unitNumber': 'U12'},
  },
];

typedef _Sent = ({String path, Object? body});

({
  RemoteBookingRepository bookings,
  RemotePaymentRepository payments,
  List<_Sent> sent,
})
_repositories({Object? confirmAnswer, int confirmStatus = 200}) {
  final sent = <_Sent>[];
  final dio = Dio(
    BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        sent.add((path: request.path, body: request.data));
        final (Object data, int status) = switch (request.path) {
          Endpoints.allEnquiries => (_bookings, 200),
          Endpoints.confirmBookedUnit => (
            confirmAnswer ?? {'message': 'STK push sent', 'success': true},
            confirmStatus,
          ),
          // The invoice request answers with the invoices it touched.
          Endpoints.createPaymentRequest => (
            [
              {'id': 31, 'balanceDue': 45000, 'isPaid': false},
            ],
            200,
          ),
          _ => ({'message': 'Not found'}, 404),
        };
        handler.resolve(
          Response(requestOptions: request, statusCode: status, data: data),
        );
      },
    ),
  );
  final api = ApiClient(tokenStore: _Tokens(), dio: dio);
  return (
    bookings: RemoteBookingRepository(api),
    payments: RemotePaymentRepository(api, AccountIdentity(api)),
    sent: sent,
  );
}

void main() {
  group('bookings from the API', () {
    test('the list is read off the bookings route, newest first', () async {
      final (:bookings, :sent, payments: _) = _repositories();

      final page = (await bookings.listBookings()).valueOrNull!;

      expect(sent.single.path, Endpoints.allEnquiries);
      expect(page.items.map((b) => b.id), ['9', '7']);

      final waiting = page.items.first;
      expect(waiting.status, BookingStatus.pendingPayment);
      expect(waiting.isPaid, isFalse);
      expect(waiting.canPayFee, isTrue);
      expect(waiting.bookingFee, const Money(500000, 'KES'));
      expect(waiting.phoneNumber, '254712345678');
      expect(waiting.unitNumber, 'U12');
      expect(waiting.propertyName, 'Grace Mall');

      final active = page.items.last;
      expect(active.status, BookingStatus.active);
      expect(active.canPayFee, isFalse);
      expect(active.expiresAt, isNotNull);
    });

    test('a status filter narrows the one fetch', () async {
      final (:bookings, :sent, payments: _) = _repositories();

      final page = (await bookings.listBookings(
        status: BookingStatus.active,
      )).valueOrNull!;

      expect(page.items.map((b) => b.id), ['7']);
      expect(sent.length, 1);
    });

    test('one booking is picked out of the list', () async {
      final (:bookings, sent: _, payments: _) = _repositories();

      expect((await bookings.getBooking('9')).valueOrNull!.unitId, '12');
      expect(await bookings.getBooking('99'), isA<Err<dynamic>>());
    });
  });

  group('the booking fee prompt', () {
    test('sends the booking, the handset and the captured fee', () async {
      final (:bookings, :sent, payments: _) = _repositories();

      final result = await bookings.requestBookingFeePrompt(
        bookingId: '9',
        phoneNumber: '0712 345 678',
        amount: const Money(500000, 'KES'),
        idempotencyKey: 'k1',
      );

      final prompt = result.valueOrNull!;
      expect(prompt.phoneNumber, '254712345678');
      expect(prompt.amount, const Money(500000, 'KES'));
      expect(prompt.message, 'STK push sent');

      expect(sent.single.path, Endpoints.confirmBookedUnit);
      expect(sent.single.body, {
        'bookingId': 9,
        'mpesaPhoneNumber': '254712345678',
        // The contract types the fee as a string.
        'amount': '5000',
      });
    });

    test('a 200 that says success: false is a refusal', () async {
      final (:bookings, sent: _, payments: _) = _repositories(
        confirmAnswer: {'message': 'Booking already paid', 'success': false},
      );

      final result = await bookings.requestBookingFeePrompt(
        bookingId: '9',
        phoneNumber: '0712345678',
        amount: const Money(500000, 'KES'),
        idempotencyKey: 'k1',
      );

      expect(result, isA<Err<PaymentPrompt>>());
      expect(result.failureOrNull!.message, 'Booking already paid');
    });

    test('a 400 is the server\'s message, as a failure', () async {
      final (:bookings, sent: _, payments: _) = _repositories(
        confirmAnswer: {'message': 'Invalid phone number', 'success': false},
        confirmStatus: 400,
      );

      final result = await bookings.requestBookingFeePrompt(
        bookingId: '9',
        phoneNumber: '0712345678',
        amount: const Money(500000, 'KES'),
        idempotencyKey: 'k1',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.message, 'Invalid phone number');
    });
  });

  group('the invoice prompt', () {
    test('sends the invoice, the handset and a whole-number amount', () async {
      final (:payments, :sent, bookings: _) = _repositories();

      final result = await payments.requestMpesaPrompt(
        invoiceId: '31',
        phoneNumber: '+254 712 345 678',
        amount: const Money(4500000, 'KES'),
        idempotencyKey: 'k2',
      );

      expect(result.valueOrNull!.phoneNumber, '254712345678');
      expect(sent.single.path, Endpoints.createPaymentRequest);
      expect(sent.single.body, {
        'invoiceId': 31,
        'phoneNumber': '254712345678',
        'amount': 45000,
      });
    });
  });

  group('the sheet', () {
    Widget host(MpesaPaymentRequest request) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showMpesaPaymentSheet(context, request),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets(
      'asks for the handset, waits on the phone, and only the server can '
      'call it paid',
      (tester) async {
        final sentTo = <String>[];
        var checks = 0;

        await tester.pumpWidget(
          host(
            MpesaPaymentRequest(
              title: 'Booking fee',
              subtitle: 'Unit U12 · Grace Mall',
              amount: const Money(500000, 'KES'),
              phoneNumber: '254712345678',
              send: (phone) async {
                sentTo.add(phone);
                return Ok(
                  PaymentPrompt(
                    phoneNumber: phone,
                    amount: const Money(500000, 'KES'),
                  ),
                );
              },
              // Not paid the first time it is asked, paid the second.
              confirmPaid: () async => Ok(++checks >= 2),
              restart: () async {},
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // The figure and the number the booking was made with, prefilled.
        expect(find.text('Pay with M-Pesa'), findsOneWidget);
        expect(find.text('KES 5,000'), findsOneWidget);
        expect(find.text('712345678'), findsOneWidget);

        await tester.tap(find.text('Send M-Pesa prompt'));
        await tester.pumpAndSettle();

        expect(sentTo, ['254712345678']);
        expect(find.text('Check your phone'), findsOneWidget);
        expect(
          find.textContaining('Enter your PIN to pay KES 5,000'),
          findsOneWidget,
        );
        expect(find.text('Payment received'), findsNothing);

        // The server has not seen the money yet: no success, and says so.
        await tester.tap(find.text('I have paid — check status'));
        await tester.pumpAndSettle();
        expect(find.text('Payment received'), findsNothing);
        expect(find.textContaining('Not confirmed yet'), findsOneWidget);

        await tester.tap(find.text('I have paid — check status'));
        await tester.pumpAndSettle();
        expect(checks, 2);
        expect(find.text('Payment received'), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Payment received'), findsNothing);
      },
    );

    testWidgets('a refused prompt stays on the form with the reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MpesaPaymentRequest(
            title: 'INV-31',
            amount: const Money(4500000, 'KES'),
            phoneNumber: '254712345678',
            send: (_) async =>
                const Err(ValidationFailure('Invalid phone number')),
            confirmPaid: () async => const Ok(false),
            restart: () async {},
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send M-Pesa prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid phone number'), findsOneWidget);
      expect(find.text('Pay with M-Pesa'), findsOneWidget);
      expect(find.text('Check your phone'), findsNothing);
    });

    testWidgets('an empty number cannot be sent', (tester) async {
      var sends = 0;
      await tester.pumpWidget(
        host(
          MpesaPaymentRequest(
            title: 'INV-31',
            amount: const Money(4500000, 'KES'),
            phoneNumber: '',
            send: (_) async {
              sends++;
              return const Err(UnknownFailure());
            },
            confirmPaid: () async => const Ok(false),
            restart: () async {},
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send M-Pesa prompt'));
      await tester.pumpAndSettle();

      expect(sends, 0);
      expect(find.text('Pay with M-Pesa'), findsOneWidget);
    });
  });
}
