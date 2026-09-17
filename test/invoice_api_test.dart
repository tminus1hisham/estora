import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/services/models/api_mappers.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// The invoices screen against the published contract.
///
/// The invoice route is keyed on the *tenant record's* id, which the account
/// never names. These pin down where the app finds it, what it does when it
/// cannot, and that the server's own spelling of a status is understood.
void main() {
  const account = {
    'id': 42,
    'userId': 'user-guid',
    'fullName': 'Wanjiru Njeri',
    'phoneNumber': '254718024761',
    'userRole': 'Tenant',
  };

  Map<String, Object?> tenant({
    required int id,
    String? userId,
    String? phone,
  }) => {
    'id': id,
    'userId': ?userId,
    'phoneNumber': ?phone,
    'fullName': 'Somebody',
  };

  Map<String, Object?> invoice(int id, {String? status, bool paid = false}) => {
    'id': id,
    'tenantId': 7,
    'type': 0,
    'invoiceStatus': ?status,
    'isPaid': paid,
    'invoiceDate': '2026-09-01T00:00:00Z',
    'dueDate': '2026-09-05T00:00:00Z',
    'subtotal': 1000,
    'taxAmount': 0,
    'discountAmount': 0,
    'totalAmount': 1000,
    'paidAmount': paid ? 1000 : 0,
    'balanceDue': paid ? 0 : 1000,
    'currencyCode': 'KES',
  };

  /// A server that answers the three routes the screen touches and records
  /// which invoice route, if any, was asked for.
  ({RemoteInvoiceRepository invoices, List<String> paths, Dio dio}) server({
    required List<Map<String, Object?>> bookings,
    List<Map<String, Object?>> invoicesFor = const [],
  }) {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          paths.add(request.path);
          final Object data;
          if (request.path == Endpoints.account) {
            data = account;
          } else if (request.path == Endpoints.allBookings) {
            data = bookings;
          } else if (request.path.startsWith('/payments/get/invoices/')) {
            data = invoicesFor;
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 404,
                data: {'message': 'Not found'},
              ),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        },
      ),
    );
    final api = ApiClient(tokenStore: _Tokens(), dio: dio);
    final identity = AccountIdentity(api);
    return (
      invoices: RemoteInvoiceRepository(api, identity),
      paths: paths,
      dio: dio,
    );
  }

  group('tenant record', () {
    test('is read off the booking whose tenant is this account', () async {
      final s = server(
        bookings: [
          {'id': 1, 'tenant': tenant(id: 9, userId: 'someone-else')},
          {'id': 2, 'tenant': tenant(id: 7, userId: 'user-guid')},
        ],
        invoicesFor: [invoice(100)],
      );
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result, isA<Ok<Page<Invoice>>>());
      expect(result.valueOrNull!.items.single.id, '100');
      // The tenant's id, not the account's row number (42).
      expect(s.paths, contains(Endpoints.tenantInvoices('7')));
      expect(s.paths, isNot(contains(Endpoints.tenantInvoices('42'))));
    });

    test(
      'falls back to the sign-in phone number when the link is missing',
      () async {
        final s = server(
          bookings: [
            {'id': 1, 'tenant': tenant(id: 11, phone: '+254 718 024 761')},
          ],
        );
        addTearDown(s.dio.close);

        await s.invoices.listInvoices();

        expect(s.paths, contains(Endpoints.tenantInvoices('11')));
      },
    );

    test('is resolved once and kept for the session', () async {
      final s = server(
        bookings: [
          {'id': 1, 'tenant': tenant(id: 7, userId: 'user-guid')},
        ],
      );
      addTearDown(s.dio.close);

      await s.invoices.listInvoices();
      await s.invoices.listInvoices();

      expect(s.paths.where((p) => p == Endpoints.allBookings), hasLength(1));
      expect(
        s.paths.where((p) => p == Endpoints.tenantInvoices('7')),
        hasLength(2),
      );
    });

    test('is not guessed from the only tenant a manager can see', () async {
      // A manager's token sees every booking on the platform. With one tenant
      // on it, "the only tenant there is" would be wrong — it is not them.
      final s = server(
        bookings: [
          {
            'id': 1,
            'tenant': tenant(
              id: 7,
              userId: 'someone-else',
              phone: '254700000001',
            ),
          },
        ],
      );
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result, isA<Ok<Page<Invoice>>>());
      expect(result.valueOrNull!.items, isEmpty);
      expect(
        s.paths.where((p) => p.startsWith('/payments/get/invoices/')),
        isEmpty,
      );
    });
  });

  group('without a tenant record', () {
    test('the statement is empty rather than an error', () async {
      final s = server(bookings: const []);
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result, isA<Ok<Page<Invoice>>>());
      expect(result.valueOrNull!.items, isEmpty);
    });

    test('a single invoice is a genuine not-found', () async {
      final s = server(bookings: const []);
      addTearDown(s.dio.close);

      final result = await s.invoices.getInvoice('100');

      expect(result, isA<Err<Invoice>>());
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  test(
    'a bookings route that refuses is still reported as a failure',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.invalid',
          validateStatus: (_) => true,
        ),
      );
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              statusCode: request.path == Endpoints.account ? 200 : 403,
              data: request.path == Endpoints.account
                  ? account
                  : {'message': 'Forbidden'},
            ),
          ),
        ),
      );
      final api = ApiClient(tokenStore: _Tokens(), dio: dio);
      final invoices = RemoteInvoiceRepository(api, AccountIdentity(api));

      final result = await invoices.listInvoices();

      expect(result, isA<Err<Page<Invoice>>>());
      expect(result.failureOrNull, isA<ForbiddenFailure>());
    },
  );

  group('invoiceStatus spelling', () {
    test('the server\'s enum names are understood', () {
      expect(
        invoiceFromJson(invoice(1, status: 'PartiallyPaid')).status,
        InvoiceStatus.partiallyPaid,
      );
      expect(
        invoiceFromJson(invoice(1, status: 'Partially paid')).status,
        InvoiceStatus.partiallyPaid,
      );
      expect(
        invoiceFromJson(invoice(1, status: 'PARTIALLY_PAID')).status,
        InvoiceStatus.partiallyPaid,
      );
      expect(
        invoiceFromJson(invoice(1, status: 'Overdue')).status,
        InvoiceStatus.overdue,
      );
    });

    test('a spelling nobody agreed on falls back to the facts', () {
      expect(
        invoiceFromJson(invoice(1, status: 'Pending', paid: true)).status,
        InvoiceStatus.paid,
      );
      expect(
        // Due 2026-09-05, so past due by the time this runs.
        invoiceFromJson(invoice(1, status: 'Pending')).status,
        InvoiceStatus.overdue,
      );
    });
  });
}

class _Tokens implements TokenStore {
  @override
  Future<AuthTokens?> read() async => AuthTokens(
    accessToken: 'test',
    refreshToken: '',
    expiresAt: DateTime(2100),
  );
  @override
  Future<void> write(AuthTokens value) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}
