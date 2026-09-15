import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/result.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/domain/entities/tenant.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/services/providers.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

class _Tokens implements TokenStore {
  AuthTokens? tokens;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}

void main() {
  test('every production repository uses the API implementation', () {
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(_Tokens())],
    );
    addTearDown(container.dispose);
    final providers = [
      authRepositoryProvider,
      propertyRepositoryProvider,
      unitRepositoryProvider,
      bookingRepositoryProvider,
      leaseRepositoryProvider,
      invoiceRepositoryProvider,
      paymentRepositoryProvider,
      receiptRepositoryProvider,
      documentRepositoryProvider,
      notificationRepositoryProvider,
      tenantRepositoryProvider,
      dashboardRepositoryProvider,
      ownerRepositoryProvider,
      propertyStructureRepositoryProvider,
      treasuryRepositoryProvider,
      accessRepositoryProvider,
      accountRepositoryProvider,
    ];
    for (final provider in providers) {
      expect(
        container.read(provider).runtimeType.toString(),
        startsWith('Remote'),
      );
    }
  });

  for (final role in [
    'Tenant',
    'Owner',
    'Manager',
    'Admin',
    'SuperAdmin',
    'super_admin',
  ]) {
    test(
      'API $role account selects the correct view and respects restoration permissions',
      () async {
        final tokens = _Tokens();
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://test.invalid',
            validateStatus: (_) => true,
          ),
        );
        final account = {
          'id': 42,
          'userId': 'account-id',
          'fullName': 'Test Account',
          'userRole': role,
        };
        final paths = <String>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              paths.add(request.path);
              final restricted =
                  request.path == Endpoints.account && role == 'Tenant';
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: restricted ? 403 : 200,
                  data: restricted
                      ? {'message': 'Forbidden'}
                      : request.path == Endpoints.account
                      ? account
                      : {
                          'token': 'test-token',
                          'refreshToken': 'test-refresh',
                          'user': account,
                        },
                ),
              );
            },
          ),
        );
        final api = ApiClient(tokenStore: tokens, dio: dio);
        final identity = AccountIdentity(api);
        final auth = RemoteAuthRepository(api, tokens, identity);
        final login = await auth.loginWithPassword(
          identifier: '254700000000',
          password: 'test',
        );
        expect(login, isA<Ok<AuthSession>>());
        expect(login.valueOrNull!.user.role.isManager, role != 'Tenant');
        expect((await identity.load()).isOk, isTrue);
        expect(paths, [Endpoints.login]);
        identity.forget();
        final restored = await auth.restoreSession();
        if (role == 'Tenant') {
          expect(restored.isOk, isFalse);
        } else {
          expect(restored.isOk, isTrue);
          expect(restored.valueOrNull!.user.role, AccountRole.fromApi(role));
        }
        dio.close();
      },
    );
  }

  test('failed account lookup never constructs a made-up session', () async {
    final tokens = _Tokens();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: request.path == Endpoints.login ? 200 : 503,
              data: request.path == Endpoints.login
                  ? {'token': 'test-token', 'refreshToken': 'test-refresh'}
                  : {'message': 'Unavailable'},
            ),
          );
        },
      ),
    );
    final api = ApiClient(tokenStore: tokens, dio: dio);
    final auth = RemoteAuthRepository(api, tokens, AccountIdentity(api));
    expect(
      (await auth.loginWithPassword(
        identifier: '254700000000',
        password: 'test',
      )).isOk,
      isFalse,
    );
    expect(tokens.tokens, isNull);
    dio.close();
  });

  test(
    'unsupported reports and quotes return errors without HTTP requests',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.invalid',
          validateStatus: (_) => true,
        ),
      );
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            paths.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 404,
                data: {'message': 'Not available'},
              ),
            );
          },
        ),
      );
      final api = ApiClient(tokenStore: _Tokens(), dio: dio);
      expect((await RemoteDashboardRepository(api).getSummary()).isOk, isFalse);
      expect((await RemoteOwnerRepository(api).getPortfolio()).isOk, isFalse);
      expect(
        (await RemoteBookingRepository(api).getQuote('unit-id')).isOk,
        isFalse,
      );
      final unsupported = [
        await RemoteLeaseRepository(api).listLeases(),
        await RemoteLeaseRepository(api).getAgreement('lease-id'),
        await RemoteBookingRepository(api).cancelBooking('booking-id'),
        await RemotePaymentRepository(api).listPayments(),
        await RemotePaymentRepository(api).getPayment('payment-id'),
        await RemoteReceiptRepository(api).listReceipts(),
        await RemoteDocumentRepository(api).listDocuments(),
        await RemoteDocumentRepository(api).upload(
          fileName: 'test.pdf',
          bytes: [1],
          mimeType: 'application/pdf',
          type: DocumentType.other,
        ),
        await RemoteNotificationRepository(api).unreadCount(),
        await RemoteNotificationRepository(api).markAllRead(),
        await RemoteTenantRepository(api).getCurrentTenant(),
        await RemoteOwnerRepository(api).getOwner(),
        await RemoteOwnerRepository(api).getLedger(),
        await RemoteOwnerRepository(api).setUnitRent(unitId: 'unit-id'),
      ];
      for (final result in unsupported) {
        expect(result.failureOrNull, isA<UnsupportedFeatureFailure>());
      }
      expect(paths, isEmpty);
      dio.close();
    },
  );
}
