import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/lease.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/services/models/api_mappers.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

/// The lease screen against the live contract.
///
/// `Properties_GetLeaseAgreements` takes nothing and answers with the
/// caller's leases. These pin down that the route is asked once, that what
/// comes back is narrowed to the account's *tenant record* rather than to
/// the account's own id, that a lease is read as the contract carries it,
/// and that the bare acknowledgement the route is typed as is not mistaken
/// for a lease.
void main() {
  // The account signs in as user 42; the tenancy billed and leased is tenant
  // record 7. The two numbers are deliberately different — a lease narrowed
  // by the first would be the wrong tenant's.
  const account = {
    'id': 42,
    'userId': 'user-guid',
    'phoneNumber': '254710560190',
    'userRole': 'Tenant',
  };

  const directory = [
    {'id': 7, 'userId': 'user-guid', 'phoneNumber': '254710560190'},
    {'id': 9, 'userId': 'other-guid', 'phoneNumber': '254700000000'},
  ];

  Map<String, Object?> lease(
    int id, {
    Object status = 'Active',
    int tenantId = 7,
    String start = '2026-03-01T00:00:00Z',
    String end = '2028-02-29T00:00:00Z',
  }) => {
    'id': id,
    'propertyId': 3,
    'blockId': 5,
    'unitId': 11,
    'tenantId': tenantId,
    'leaseAgreementUrls': 'https://files.invalid/lease-$id.pdf',
    'status': status,
    'startDate': start,
    'endDate': end,
    'monthlyRent': 150000,
    'depositAmount': 450000,
    'serviceChargePerMonth': 12000,
    'gracePeriodDays': 5,
    'termsAndConditions': 'Rent is payable in advance.',
    'specialConditions': 'Signage on the front elevation is permitted.',
    'createdByName': 'Manager',
    'createdByUserId': 'manager-guid',
    'updatedByName': 'Manager',
    'updatedByUserId': 'manager-guid',
    'createdAt': '2026-02-20T09:00:00Z',
    'updatedAt': '2026-02-20T09:00:00Z',
  };

  /// A server that answers the lease route with [answer], and the two routes
  /// the tenancy is resolved through on the way to it.
  ({RemoteLeaseRepository leases, List<String> paths, Dio dio}) server(
    Object answer, {
    Map<String, Object?> account = account,
    List<Map<String, Object?>> tenants = directory,
  }) {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          paths.add(request.path);
          final data = switch (request.path) {
            Endpoints.account => account,
            Endpoints.tenants => tenants,
            Endpoints.allEnquiries => const <Object>[],
            _ => answer,
          };
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        },
      ),
    );
    final api = ApiClient(tokenStore: _Tokens(), dio: dio);
    return (
      leases: RemoteLeaseRepository(api, AccountIdentity(api)),
      paths: paths,
      dio: dio,
    );
  }

  test('the list is the lease agreements route, asked once', () async {
    final s = server([lease(1), lease(2, status: 'Terminated')]);
    addTearDown(s.dio.close);

    final result = await s.leases.listLeases();

    expect(result, isA<Ok<Page<Lease>>>());
    expect(result.valueOrNull!.items.map((l) => l.id), ['1', '2']);
    expect(s.paths, [
      Endpoints.account,
      Endpoints.tenants,
      Endpoints.leaseAgreements,
    ]);
  });

  test('a status filter narrows the whole set client-side', () async {
    final s = server([lease(1), lease(2, status: 'Terminated')]);
    addTearDown(s.dio.close);

    final result = await s.leases.listLeases(status: LeaseStatus.terminated);

    expect(result.valueOrNull!.items.single.id, '2');
    expect(s.paths, contains(Endpoints.leaseAgreements));
  });

  group('whose leases they are', () {
    test("is the account's tenant record, not the account's id", () async {
      final s = server([
        lease(1),
        lease(2, tenantId: 9),
        lease(3, tenantId: 42),
      ]);
      addTearDown(s.dio.close);

      final result = await s.leases.listLeases();

      // Tenant record 7 is this account's; 9 is somebody else's, and 42 is
      // the account's own id wearing a tenant's number.
      expect(result.valueOrNull!.items.map((l) => l.id), ['1']);
    });

    test("one lease of another tenant's is not found", () async {
      final s = server([lease(1), lease(2, tenantId: 9)]);
      addTearDown(s.dio.close);

      expect(
        (await s.leases.getLease('2')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('is left to the server when the account has no tenancy', () async {
      // A manager reads the same route on another footing: the directory
      // names no record of theirs, so the list stands as the server sent it.
      final s = server(
        [lease(1), lease(2, tenantId: 9)],
        account: {'id': 42, 'userId': 'manager-guid'},
      );
      addTearDown(s.dio.close);

      final result = await s.leases.listLeases();

      expect(result.valueOrNull!.items.map((l) => l.id), ['1', '2']);
    });
  });

  test('one lease is picked out of the list; a miss is not-found', () async {
    final s = server([lease(1), lease(2)]);
    addTearDown(s.dio.close);

    expect((await s.leases.getLease('2')).valueOrNull?.id, '2');
    expect(
      (await s.leases.getLease('9')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('a bare acknowledgement is an empty list, not a lease', () async {
    final s = server({'message': 'No leases', 'success': true});
    addTearDown(s.dio.close);

    final result = await s.leases.listLeases();

    expect(result.valueOrNull!.items, isEmpty);
  });

  group('a lease as the contract carries it', () {
    final parsed = leaseFromJson(lease(214));

    test('is numbered by its id and read in the platform currency', () {
      expect(parsed.leaseNumber, 'LSE-214');
      expect(parsed.propertyId, '3');
      expect(parsed.unitId, '11');
      expect(parsed.tenantId, '7');
      expect(parsed.monthlyRent.currency, 'KES');
      expect(parsed.monthlyRent.format(), contains('150,000'));
      expect(parsed.depositAmount.format(), contains('450,000'));
    });

    test('understands the status by name', () {
      expect(parsed.status, LeaseStatus.active);
      expect(
        leaseFromJson(lease(1, status: 'Terminated')).status,
        LeaseStatus.terminated,
      );
      expect(leaseFromJson(lease(1, status: 3)).status, LeaseStatus.active);
    });

    test('carries its fixed fields as terms, as written', () {
      final byLabel = {for (final t in parsed.terms) t.label: t};
      expect(byLabel['Service charge']!.value, contains('12,000'));
      expect(byLabel['Service charge']!.group, 'Financial');
      expect(byLabel['Grace period']!.value, '5 days');
      expect(
        byLabel['Terms and conditions']!.value,
        'Rent is payable in advance.',
      );
      expect(
        byLabel['Special conditions']!.value,
        'Signage on the front elevation is permitted.',
      );
      expect(byLabel['Special conditions']!.group, 'Conditions');
    });

    test('leaves what the contract does not state empty', () {
      expect(parsed.signedAt, isNull);
      expect(parsed.activatedAt, isNull);
      expect(parsed.terminatedAt, isNull);
      expect(parsed.propertyName, isNull);
      expect(parsed.unitNumber, isNull);
      expect(parsed.signatures, isEmpty);
      expect(parsed.activationConditions, isEmpty);
    });

    test('names its property and unit from the live flat fields', () {
      final named = leaseFromJson({
        ...lease(1),
        'propertyName': 'Grace Mall',
        'unitNumber': 'G-04',
      });
      expect(named.propertyName, 'Grace Mall');
      expect(named.unitNumber, 'G-04');
    });

    test('omits a condition the server left blank', () {
      final blank = leaseFromJson({
        ...lease(1),
        'specialConditions': '',
        'termsAndConditions': null,
      });
      expect(blank.terms.map((t) => t.label), [
        'Service charge',
        'Grace period',
      ]);
    });
  });
}

class _Tokens implements TokenStore {
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens value) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}
