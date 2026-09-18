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

/// What the deployed route actually answers: an acknowledgement, no record.
const _acknowledged = {'message': 'Booking success.', 'success': true};

/// The bookings list read back after the acknowledgement. Amina's older one
/// on another property, one made a moment ago on a different phone by
/// whoever else holds this token, and hers.
final _listed = [
  {
    ..._created,
    'id': 7,
    'propertyId': 5,
    'bookingDate': '2026-09-16T09:00:00Z',
  },
  {
    ..._created,
    'id': 11,
    'phoneNumber': '254799000000',
    'bookingDate': '2026-09-17T09:05:00Z',
  },
  {..._created, 'phoneNumber': '254712345678'},
];

({RemoteBookingRepository bookings, List<_Sent> sent}) _repository({
  Object created = _created,
}) {
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
          Endpoints.bookUnit => (created, 200),
          Endpoints.allBookings => (_listed, 200),
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

  test(
    'a bare acknowledgement is followed by reading the booking back',
    () async {
      final (:bookings, :sent) = _repository(created: _acknowledged);

      final result = await bookings.createBooking(
        target: const SpaceTarget(propertyId: '2', blockId: '2', size: 480),
        applicant: _applicant,
        idempotencyKey: 'k1',
      );

      // Newest first, on this property, made with this phone: not the older
      // booking elsewhere, and not the one someone else just made.
      expect(result.valueOrNull!.id, '9');
      expect(sent.map((s) => s.path), [
        Endpoints.bookUnit,
        Endpoints.allBookings,
      ]);
    },
  );

  test('a refused booking under a 200 is an error, not a booking', () async {
    final (:bookings, :sent) = _repository(
      created: const {'message': 'Block is full.', 'success': false},
    );

    final result = await bookings.createBooking(
      target: const SpaceTarget(propertyId: '2', blockId: '2'),
      applicant: _applicant,
      idempotencyKey: 'k1',
    );

    expect(result, isA<Err<Booking>>());
    expect(sent.map((s) => s.path), [Endpoints.bookUnit]);
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
