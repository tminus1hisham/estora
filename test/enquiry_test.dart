import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/booking.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// Sending an enquiry from a property: one request to the booking route
/// carrying the property and who is asking, and the server's acknowledgement
/// read back as such. Nothing else is read, and nothing is fabricated from
/// a `{message, success}` answer.

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

const _enquiry = PropertyEnquiry(
  propertyId: '2',
  applicant: BookingApplicant(
    fullName: 'Amina Njeri',
    phoneNumber: '0712 345 678',
    email: 'amina@example.com',
    companyName: 'Wanjiru Fabrics',
    businessType: 'Fashion and apparel',
  ),
  message: 'Around 480 sq ft on the ground floor, from November.',
);

typedef _Sent = ({String method, String path, Object? body});

({RemoteBookingRepository bookings, List<_Sent> sent}) _repository({
  required Object answer,
  int status = 200,
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
        final (Object data, int code) = request.path == Endpoints.enquireUnit
            ? (answer, status)
            : ({'message': 'Unauthorized'}, 401);
        handler.resolve(
          Response(requestOptions: request, statusCode: code, data: data),
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
  test('an enquiry is one request to the booking route', () async {
    final (:bookings, :sent) = _repository(
      answer: {'message': 'Booking success.', 'success': true},
    );

    final result = await bookings.sendEnquiry(_enquiry, idempotencyKey: 'k1');

    expect(result.valueOrNull?.message, 'Booking success.');
    expect(sent.single.method, 'POST');
    expect(sent.single.path, Endpoints.enquireUnit);
    expect(sent.single.body, {
      'propertyId': 2,
      'fullName': 'Amina Njeri',
      'phoneNumber': '254712345678',
      'email': 'amina@example.com',
      'companyName': 'Wanjiru Fabrics',
      'businessType': 'Fashion and apparel',
      'description': 'Around 480 sq ft on the ground floor, from November.',
    });
  });

  test('a refusal under a 200 is a failure, not a receipt', () async {
    final (:bookings, sent: _) = _repository(
      answer: {
        'message': 'Property is not accepting enquiries.',
        'success': false,
      },
    );

    final result = await bookings.sendEnquiry(_enquiry, idempotencyKey: 'k1');

    expect(result.isOk, isFalse);
    expect(
      (result as Err<EnquiryReceipt>).failure.message,
      'Property is not accepting enquiries.',
    );
  });

  test('a 400 comes back as the server\'s own message', () async {
    final (:bookings, sent: _) = _repository(
      answer: {'message': 'Phone number is required.', 'success': false},
      status: 400,
    );

    final result = await bookings.sendEnquiry(_enquiry, idempotencyKey: 'k1');

    expect(result.isOk, isFalse);
    expect((result as Err<EnquiryReceipt>).failure, isA<Failure>());
    expect(result.failure.message, contains('Phone number is required.'));
  });
}
