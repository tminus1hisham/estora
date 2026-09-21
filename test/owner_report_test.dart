import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/billing.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/services/models/api_mappers.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// The Revenue screen and the tenant's payment history against the published
/// contract.
///
/// Neither has a route of its own. The owner's report is the owner-report
/// route (every M-Pesa arrival, scoped by the server to the bearer) joined to
/// the per-property invoice route for each property the owner holds; a
/// tenant's history is the transactions their own invoices embed. These pin
/// down which routes are asked, that nothing is asked of another tenant's
/// statement, and what the report works out from what it was given.
void main() {
  const account = {
    'id': 42,
    'userId': 'user-guid',
    'fullName': 'Wanjiru Njeri',
    'phoneNumber': '254718024761',
    'userRole': 'Tenant',
  };

  Map<String, Object?> transaction(
    int id, {
    required String amount,
    required String at,
    int? propertyId,
    String? name,
  }) => {
    'id': id,
    'propertyId': ?propertyId,
    'transID': 'TX$id',
    'transTime': at,
    'transAmount': amount,
    'billRefNumber': 'SHOP-1',
    'firstName': ?name,
    'processed': true,
  };

  Map<String, Object?> invoice(
    int id, {
    required int propertyId,
    required String due,
    num total = 1000,
    num paid = 0,
    bool isPaid = false,
    List<Map<String, Object?>> payments = const [],
    String? tenantName,
  }) => {
    'id': id,
    'propertyId': propertyId,
    'tenantId': 7,
    'type': 0,
    'isPaid': isPaid,
    'invoiceDate': '2026-09-01T00:00:00Z',
    'dueDate': due,
    'subtotal': total,
    'taxAmount': 0,
    'discountAmount': 0,
    'totalAmount': total,
    'paidAmount': paid,
    'balanceDue': total - paid,
    'currencyCode': 'KES',
    'payments': payments,
    if (tenantName != null) 'tenant': {'id': 7, 'fullName': tenantName},
  };

  /// A server that answers with what it is given and records what was asked.
  ({ApiClient api, List<String> paths, Dio dio}) server(
    Object? Function(String path) answer,
  ) {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          paths.add(request.path);
          final data = answer(request.path);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: data == null ? 404 : 200,
              data: data ?? {'message': 'Not found'},
            ),
          );
        },
      ),
    );
    return (
      api: ApiClient(tokenStore: _Tokens(), dio: dio),
      paths: paths,
      dio: dio,
    );
  }

  group('the owner report', () {
    test('covers every property the owner holds', () async {
      final s = server(
        (path) => switch (path) {
          Endpoints.properties => [
            {'id': 1, 'propertyName': 'Sarit Mall'},
            {'id': 2, 'propertyName': 'ABC Business Centre'},
          ],
          Endpoints.ownerReport => [
            transaction(10, amount: '150000', at: '20260903101500'),
            transaction(11, amount: '80000', at: '20260910091000'),
          ],
          '/payments/get/invoices/property/1' => [
            invoice(100, propertyId: 1, due: '2026-09-05T00:00:00Z'),
          ],
          '/payments/get/invoices/property/2' => [
            invoice(200, propertyId: 2, due: '2026-09-20T00:00:00Z'),
          ],
          _ => null,
        },
      );
      addTearDown(s.dio.close);

      final result = await RemoteOwnerRepository(s.api).getReport();

      expect(result, isA<Ok<OwnerReport>>());
      final report = result.valueOrNull!;
      expect(report.propertyId, isNull);
      expect(report.received.map((row) => row.id), ['11', '10']);
      expect(
        report.invoices.map((row) => row.id),
        unorderedEquals(['100', '200']),
      );
      expect(s.paths, contains(Endpoints.ownerReport));
      expect(s.paths, contains(Endpoints.propertyInvoices('1')));
      expect(s.paths, contains(Endpoints.propertyInvoices('2')));
      // Nothing keyed on a tenant: the owner's report is not one tenant's
      // statement read sideways.
      expect(s.paths.where((p) => p.startsWith('/payments/get/invoices/')), [
        Endpoints.propertyInvoices('1'),
        Endpoints.propertyInvoices('2'),
      ]);
    });

    test('is cut to one property by the server, not the app', () async {
      final s = server(
        (path) => switch (path) {
          '/payments/get/mpesa/payment/by/property/2' => [
            transaction(11, amount: '80000', at: '20260910091000'),
          ],
          '/payments/get/invoices/property/2' => [
            invoice(200, propertyId: 2, due: '2026-09-20T00:00:00Z'),
          ],
          _ => null,
        },
      );
      addTearDown(s.dio.close);

      final result = await RemoteOwnerRepository(
        s.api,
      ).getReport(propertyId: '2');

      final report = result.valueOrNull!;
      expect(report.propertyId, '2');
      expect(report.received.single.id, '11');
      expect(report.invoices.single.id, '200');
      expect(s.paths, isNot(contains(Endpoints.ownerReport)));
      expect(s.paths, isNot(contains(Endpoints.properties)));
      expect(s.paths, [
        Endpoints.mpesaPaymentsByProperty('2'),
        Endpoints.propertyInvoices('2'),
      ]);
    });

    test('fails whole rather than showing half a portfolio', () async {
      final s = server(
        (path) => switch (path) {
          Endpoints.properties => [
            {'id': 1, 'propertyName': 'Sarit Mall'},
            {'id': 2, 'propertyName': 'ABC Business Centre'},
          ],
          Endpoints.ownerReport => <Object>[],
          '/payments/get/invoices/property/1' => <Object>[],
          _ => null,
        },
      );
      addTearDown(s.dio.close);

      final result = await RemoteOwnerRepository(s.api).getReport();

      expect(result.isOk, isFalse);
    });
  });

  group('what the report works out', () {
    final now = DateTime(2026, 9, 18, 12);
    final report = OwnerReport(
      received: [
        for (final row in [
          transaction(1, amount: '150000', at: '20260903101500', propertyId: 1),
          transaction(2, amount: '80000', at: '20260917091000', propertyId: 2),
          transaction(3, amount: '20000', at: '20260817120000', propertyId: 1),
        ])
          mpesaTransactionFromJson(row),
      ],
      invoices: [
        for (final row in [
          // Owed and 13 days late.
          invoice(100, propertyId: 1, due: '2026-09-05T00:00:00Z', total: 5000),
          // Owed and not yet due.
          invoice(
            101,
            propertyId: 1,
            due: '2026-09-20T00:00:00Z',
            total: 3000,
            paid: 1000,
          ),
          // Settled: not owed at all.
          invoice(
            102,
            propertyId: 2,
            due: '2026-09-05T00:00:00Z',
            total: 9000,
            paid: 9000,
            isPaid: true,
          ),
        ])
          invoiceFromJson(row),
      ],
    );

    test('paid and unpaid split the ledger by money owed', () {
      expect(report.paidInvoices.map((i) => i.id), ['102']);
      expect(report.outstandingInvoices.map((i) => i.id), ['100', '101']);
    });

    test('outstanding is the balance still due, banded by age', () {
      expect(report.outstanding, Money.fromMajor(7000, 'KES'));
      expect(report.outstandingInvoices.map((i) => i.id), ['100', '101']);

      final ageing = report.ageingAt(now);
      expect(ageing.map((b) => b.label), [
        'Not yet due',
        '1–30 days',
        '31–60 days',
        'Over 60 days',
      ]);
      expect(ageing[0].amount, Money.fromMajor(2000, 'KES'));
      expect(ageing[0].invoiceCount, 1);
      expect(ageing[1].amount, Money.fromMajor(5000, 'KES'));
      expect(ageing[1].invoiceCount, 1);
      expect(ageing[2].isEmpty, isTrue);
      expect(ageing[3].isEmpty, isTrue);
    });

    test('a window is cut from the arrivals by when the till stamped them', () {
      final month = report.sliceOver(const CollectionWindow.month(), now: now);
      expect(month.collected, Money.fromMajor(230000, 'KES'));
      expect(month.paymentCount, 2);
      // Six columns, the current month last, billed beside collected.
      expect(month.points.length, 6);
      expect(month.points.last.collected, Money.fromMajor(230000, 'KES'));
      expect(month.points.last.billed, Money.fromMajor(17000, 'KES'));
      expect(month.points[4].collected, Money.fromMajor(20000, 'KES'));

      final yesterday = report.sliceOver(
        const CollectionWindow.yesterday(),
        now: now,
      );
      expect(yesterday.collected, Money.fromMajor(80000, 'KES'));
      expect(yesterday.paymentCount, 1);

      final today = report.sliceOver(const CollectionWindow.today(), now: now);
      expect(today.isEmpty, isTrue);
    });
  });

  group("the tenant's payment history", () {
    test('is the payments embedded in their own invoices', () async {
      final s = server(
        (path) => switch (path) {
          Endpoints.account => account,
          Endpoints.allBookings => [
            {
              'id': 1,
              'tenant': {'id': 7, 'userId': 'user-guid'},
            },
          ],
          '/payments/get/invoices/7' => [
            invoice(
              100,
              propertyId: 1,
              due: '2026-09-05T00:00:00Z',
              total: 5000,
              paid: 5000,
              isPaid: true,
              payments: [transaction(1, amount: '5000', at: '20260903101500')],
            ),
            invoice(
              101,
              propertyId: 1,
              due: '2026-09-20T00:00:00Z',
              payments: [
                transaction(2, amount: '600', at: '20260910091000'),
                transaction(3, amount: '400', at: '20260912091000'),
              ],
            ),
          ],
          _ => null,
        },
      );
      addTearDown(s.dio.close);

      final result = await RemotePaymentRepository(
        s.api,
        AccountIdentity(s.api),
      ).listPayments();

      final payments = result.valueOrNull!.items;
      // The invoice itself carries the same rows, for the owner's sheet.
      expect(
        invoiceFromJson(
          invoice(
            101,
            propertyId: 1,
            due: '2026-09-20T00:00:00Z',
            payments: [transaction(2, amount: '600', at: '20260910091000')],
          ),
        ).payments.single.transactionId,
        'TX2',
      );
      // Newest first, whichever invoice each was placed against.
      expect(payments.map((p) => p.id), ['3', '2', '1']);
      expect(payments.first.invoiceId, '101');
      expect(payments.first.invoiceNumber, 'INV-101');
      expect(payments.first.amount, Money.fromMajor(400, 'KES'));
      expect(payments.first.providerTransactionId, 'TX3');
      expect(payments.last.invoiceId, '100');
      // Their statement, and nobody else's.
      expect(s.paths, contains(Endpoints.tenantInvoices('7')));
      expect(s.paths, isNot(contains(Endpoints.tenantInvoices('42'))));
    });

    test(
      'is empty, not an error, for an account with no tenant record',
      () async {
        final s = server(
          (path) => switch (path) {
            Endpoints.account => account,
            Endpoints.allBookings => <Object>[],
            _ => null,
          },
        );
        addTearDown(s.dio.close);

        final result = await RemotePaymentRepository(
          s.api,
          AccountIdentity(s.api),
        ).listPayments();

        expect(result, isA<Ok<Page<Payment>>>());
        expect(result.valueOrNull!.items, isEmpty);
        expect(
          s.paths.where((p) => p.startsWith('/payments/get/invoices/')),
          isEmpty,
        );
      },
    );
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
