import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// Booking a space the way Browse offers it: a property and a block off the
/// availability engine, posted straight to the booking route. Nothing else
/// is read on the way — a tenant's token cannot read unit records, and the
/// published request has no unit on it anyway.

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

const _applicant = BookingApplicant(
  fullName: 'Amina Njeri',
  phoneNumber: '0712 345 678',
  email: 'amina@example.com',
  companyName: 'Wanjiru Fabrics',
  businessType: 'Fashion and apparel',
);

/// The booking record the live route answers with.
const _created = {
  'id': 9,
  'propertyId': 2,
  'unitId': 12,
  'blockId': 2,
  'status': 0,
  'bookingFee': 5000,
  'monthlyRent': 52000,
  'depositAmount': 104000,
  'isPaid': false,
  'bookingDate': '2026-09-17T09:00:00Z',
};

typedef _Sent = ({String method, String path, Object? body});

({RemoteBookingRepository bookings, List<_Sent> sent}) _repository() {
  final sent = <_Sent>[];
  final dio = Dio(
    BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        sent.add((
          method: request.method,
          path: request.path,
          body: request.data,
        ));
        final (Object data, int status) = switch (request.path) {
          Endpoints.bookUnit => (_created, 200),
          // Every unit route is what a tenant sees: refused.
          _ => ({'message': 'Unauthorized'}, 401),
        };
        handler.resolve(
          Response(requestOptions: request, statusCode: status, data: data),
        );
      },
    ),
  );
  return (
    bookings: RemoteBookingRepository(
      ApiClient(tokenStore: _Tokens(), dio: dio),
    ),
    sent: sent,
  );
}

void main() {
  test('a space is booked with one request, and no unit lookup', () async {
    final (:bookings, :sent) = _repository();

    final result = await bookings.createBooking(
      target: const SpaceTarget(propertyId: '2', blockId: '2', size: 480),
      applicant: _applicant,
      idempotencyKey: 'k1',
    );

    final booking = result.valueOrNull!;
    expect(booking.id, '9');
    expect(booking.unitId, '12'); // the server's allocation, read back

    expect(sent.single.method, 'POST');
    expect(sent.single.path, Endpoints.bookUnit);
    expect(sent.single.body, {
      'propertyId': 2,
      'blockId': 2,
      'fullName': 'Amina Njeri',
      'phoneNumber': '254712345678',
      'email': 'amina@example.com',
      'companyName': 'Wanjiru Fabrics',
      'businessType': 'Fashion and apparel',
      // The one thing the tenant chose that the request has no field for.
      'description': '480 sq ft unit',
    });
  });

  test('the same block without a size asks for any unit in it', () async {
    final (:bookings, :sent) = _repository();

    await bookings.createBooking(
      target: const SpaceTarget(propertyId: '2', blockId: '3'),
      applicant: _applicant,
      idempotencyKey: 'k2',
    );

    expect((sent.single.body as Map)['description'], 'Any available unit');
    expect((sent.single.body as Map).containsKey('unitId'), isFalse);
  });

  test('a unit named outright is the one case that reads the unit', () async {
    final (:bookings, :sent) = _repository();

    final result = await bookings.createBooking(
      target: const UnitTarget('12'),
      applicant: _applicant,
      idempotencyKey: 'k3',
    );

    // The unit route refused, so nothing was booked — and Browse never sends
    // this shape; it is here for callers that already hold a unit record.
    expect(result, isA<Err<Booking>>());
    expect(sent.map((s) => s.path), [Endpoints.unit('12')]);
  });
}
