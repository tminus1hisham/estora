import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/error/failure.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/billing.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/domain/repositories/repositories.dart';
import 'package:estora/services/models/api_mappers.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/services/remote/remote_repositories.dart';
import 'package:estora/storage/token_store.dart';

/// The invoices screen against the published contract.
///
/// The invoice route (`Payments_getInvoices`) is keyed on the tenant
/// record's id — `Tenant.id`, joined to the account on `userId` — and not on
/// the account's own. These pin down which id is sent, where it is looked
/// up, what the app does for an account with no tenancy, and that the
/// server's own spelling of a status is understood.
void main() {
  // Account 42 signs in; the tenancy it is billed as is tenant record 13.
  const account = {
    'id': 42,
    'userId': 'user-guid',
    'fullName': 'Wanjiru Njeri',
    'phoneNumber': '254718024761',
    'userRole': 'Tenant',
  };

  /// The tenant directory, as the live server serves it.
  const directory = [
    {
      'id': 9,
      'userId': 'another-guid',
      'fullName': 'Peter Kimani',
      'phoneNumber': '254700000000',
    },
    {
      'id': 13,
      'userId': 'user-guid',
      'fullName': 'Wanjiru Njeri',
      'phoneNumber': '254718024761',
      'isDeleted': false,
    },
  ];

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

  /// A server that answers the routes the screen touches and records which
  /// invoice route, if any, was asked for.
  ({RemoteInvoiceRepository invoices, List<String> paths, Dio dio}) server({
    Map<String, Object?> account = account,
    List<Map<String, Object?>> invoicesFor = const [],
    List<Map<String, Object?>> tenants = directory,
    List<Map<String, Object?>> bookings = const [],
    int tenantsStatus = 200,
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
          } else if (request.path == Endpoints.tenants) {
            if (tenantsStatus != 200) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: tenantsStatus,
                  data: {'message': 'Not yours to read'},
                ),
              );
              return;
            }
            data = tenants;
          } else if (request.path == Endpoints.allEnquiries) {
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

  group('the tenant record id', () {
    test('is asked for, and not the account id', () async {
      final s = server(invoicesFor: [invoice(100)]);
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result, isA<Ok<Page<Invoice>>>());
      expect(result.valueOrNull!.items.single.id, '100');
      expect(s.paths, [
        Endpoints.account,
        Endpoints.tenants,
        Endpoints.tenantInvoices('13'),
      ]);
      expect(s.paths, isNot(contains(Endpoints.tenantInvoices('42'))));
    });

    test('is resolved once and kept for the session', () async {
      final s = server();
      addTearDown(s.dio.close);

      await s.invoices.listInvoices();
      await s.invoices.listInvoices();

      expect(s.paths.where((p) => p == Endpoints.account), hasLength(1));
      expect(s.paths.where((p) => p == Endpoints.tenants), hasLength(1));
      expect(
        s.paths.where((p) => p == Endpoints.tenantInvoices('13')),
        hasLength(2),
      );
    });

    test('yields to a tenantId the account names outright', () async {
      final s = server(account: {...account, 'tenantId': 7});
      addTearDown(s.dio.close);

      await s.invoices.listInvoices();

      expect(s.paths, contains(Endpoints.tenantInvoices('7')));
      expect(s.paths, isNot(contains(Endpoints.tenants)));
    });

    test('is matched on the number where the userId is blank', () async {
      final s = server(
        tenants: const [
          {'id': 13, 'userId': '', 'phoneNumber': '0718024761'},
        ],
      );
      addTearDown(s.dio.close);

      await s.invoices.listInvoices();

      expect(s.paths, contains(Endpoints.tenantInvoices('13')));
    });
  });

  group('when the directory is not theirs to read', () {
    test('the id comes off a booking of their own', () async {
      final s = server(
        tenantsStatus: 403,
        bookings: const [
          {'id': 1, 'tenantId': 8, 'phoneNumber': '254700000000'},
          {'id': 2, 'tenantId': 13, 'phoneNumber': '254718024761'},
        ],
      );
      addTearDown(s.dio.close);

      await s.invoices.listInvoices();

      expect(s.paths, contains(Endpoints.allEnquiries));
      expect(s.paths, contains(Endpoints.tenantInvoices('13')));
    });

    test('a booking of somebody else is not inherited', () async {
      final s = server(
        tenantsStatus: 403,
        bookings: const [
          {'id': 1, 'tenantId': 8, 'phoneNumber': '254700000000'},
        ],
      );
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result.valueOrNull!.items, isEmpty);
      expect(
        s.paths.where((p) => p.startsWith('/payments/get/invoices/')),
        isEmpty,
      );
    });
  });

  group('an account with no tenancy', () {
    const unnamed = {'userId': 'nobody-guid', 'fullName': 'Wanjiru Njeri'};

    test('gets an empty statement rather than an error', () async {
      final s = server(account: unnamed);
      addTearDown(s.dio.close);

      final result = await s.invoices.listInvoices();

      expect(result, isA<Ok<Page<Invoice>>>());
      expect(result.valueOrNull!.items, isEmpty);
      expect(
        s.paths.where((p) => p.startsWith('/payments/get/invoices/')),
        isEmpty,
      );
    });

    test('a single invoice is a genuine not-found', () async {
      final s = server(account: unnamed);
      addTearDown(s.dio.close);

      final result = await s.invoices.getInvoice('100');

      expect(result, isA<Err<Invoice>>());
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  test(
    'an invoice route that refuses is still reported as a failure',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.invalid',
          validateStatus: (_) => true,
        ),
      );
      addTearDown(dio.close);
      // The tenancy resolves; it is the statement itself that is refused.
      const resolved = {
        Endpoints.account: account,
        Endpoints.tenants: directory,
      };
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              statusCode: resolved.containsKey(request.path) ? 200 : 403,
              data: resolved[request.path] ?? {'message': 'Forbidden'},
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

  group('what can be paid', () {
    test('an unpaid invoice without a stated balance is still payable', () {
      // Seen on manager-raised invoices: `balanceDue` absent, or zero, while
      // the total stands. The owed figure is the server's own total less
      // what it says was paid.
      final absent = invoiceFromJson({...invoice(1)}..remove('balanceDue'));
      expect(absent.isPayable, isTrue);
      expect(absent.amountDue, Money.fromMajor(1000, 'KES'));

      final zeroed = invoiceFromJson({...invoice(1), 'balanceDue': 0});
      expect(zeroed.isPayable, isTrue);
      expect(zeroed.amountDue, Money.fromMajor(1000, 'KES'));

      final partly = invoiceFromJson({
        ...invoice(1),
        'balanceDue': 0,
        'paidAmount': 400,
      });
      expect(partly.amountDue, Money.fromMajor(600, 'KES'));
    });

    test('a balance the server states is never overridden', () {
      final stated = invoiceFromJson({...invoice(1), 'balanceDue': 250});
      expect(stated.amountDue, Money.fromMajor(250, 'KES'));
    });

    test('isPaid outranks a status label that lags behind it', () {
      final paid = invoiceFromJson({
        ...invoice(1, status: 'Issued'),
        'isPaid': true,
        'balanceDue': 0,
      });
      expect(paid.status, InvoiceStatus.paid);
      expect(paid.isPayable, isFalse);
      expect(paid.amountDue.isZero, isTrue);
    });

    test('a spelling nobody agreed on is still payable while owed', () {
      final pending = invoiceFromJson(invoice(1, status: 'Pending'));
      expect(pending.isPayable, isTrue);
    });
  });

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

  group('where an invoice bills for', () {
    test('the live flat propertyName and unitNumber are read', () {
      final parsed = invoiceFromJson({
        ...invoice(1),
        'propertyId': 2,
        'propertyName': 'Grace Mall',
        'unitNumber': 'G-04',
      });
      expect(parsed.propertyName, 'Grace Mall');
      expect(parsed.unitNumber, 'G-04');
    });

    test('an embedded property and unit still name it', () {
      final parsed = invoiceFromJson({
        ...invoice(1),
        'property': {'propertyName': 'Sarit Mall'},
        'unit': {'unitNumber': 'A-12'},
      });
      expect(parsed.propertyName, 'Sarit Mall');
      expect(parsed.unitNumber, 'A-12');
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
