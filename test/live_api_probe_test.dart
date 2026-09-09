// A live, end-to-end probe of the Property Manager API.
//
// Unlike every other test in this directory, this one talks to the real
// server. It drives the *real* `ApiClient` and the *real* remote repositories
// — the same code the app runs when `AppConfig.dataSource` is `remote` — so a
// pass here means the app's own path works, not merely that the host answers.
//
//   flutter test test/live_api_probe_test.dart \
//     --dart-define=PROBE_PHONE=254... --dart-define=PROBE_PASSWORD=...
//
// Without those two defines the whole group is skipped, so a plain
// `flutter test` stays offline and deterministic.
//
// Every step is a read except the sign-in itself: the probe creates nothing,
// updates nothing and deletes nothing. Tokens live in memory only.
//
// The widget binding is deliberately never initialised. `flutter_test`
// installs an `HttpOverrides` that fails every request when it is, which would
// make this file test the mock rather than the server.

import 'package:flutter_test/flutter_test.dart';

import 'package:mall/core/error/result.dart';
import 'package:mall/domain/entities/property.dart';
import 'package:mall/domain/entities/unit.dart';
import 'package:mall/domain/repositories/repositories.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/remote_repositories.dart';
import 'package:mall/storage/token_store.dart';

const _phone = String.fromEnvironment('PROBE_PHONE');
const _password = String.fromEnvironment('PROBE_PASSWORD');

/// A real round trip over a real network, not a memory read.
const _generous = Timeout(Duration(minutes: 2));

/// A [TokenStore] that keeps the session for the life of the process.
class _MemoryTokenStore implements TokenStore {
  AuthTokens? _tokens;
  bool _biometric = false;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;

  @override
  Future<bool> isBiometricEnabled() async => _biometric;

  @override
  Future<void> setBiometricEnabled(bool enabled) async => _biometric = enabled;
}

/// Unwraps a [Result], failing the test with the server's own words.
///
/// A failed round trip should read as the failure it was — `NotFoundFailure:
/// no such unit` — rather than as a null dereference three lines later.
T expectOk<T>(Result<T> result, String what) => switch (result) {
  Ok<T>(:final value) => value,
  Err<T>(:final failure) => fail(
    '$what -> ${failure.runtimeType}: ${failure.message}',
  ),
};

void main() {
  final credentialsGiven = _phone.isNotEmpty && _password.isNotEmpty;

  group(
    'live API',
    skip: credentialsGiven
        ? null
        : 'Pass --dart-define=PROBE_PHONE and --dart-define=PROBE_PASSWORD '
              'to run this against the real server.',
    () {
      late _MemoryTokenStore tokenStore;
      late ApiClient api;
      late AccountIdentity identity;

      setUpAll(() {
        tokenStore = _MemoryTokenStore();
        api = ApiClient(tokenStore: tokenStore);
        identity = AccountIdentity(api);
      });

      test('signs in and stores a usable token', timeout: _generous, () async {
        final auth = RemoteAuthRepository(api, tokenStore, identity);
        final session = expectOk(
          await auth.loginWithPassword(identifier: _phone, password: _password),
          'login',
        );

        expect(session.user.id, isNotEmpty, reason: 'no user id came back');

        final tokens = await tokenStore.read();
        expect(tokens, isNotNull, reason: 'sign-in stored no token');
        expect(tokens!.accessToken, isNotEmpty);

        printOnFailure('signed in as ${session.user.id}');
      });

      test('reads the signed-in account', timeout: _generous, () async {
        final account = RemoteAccountRepository(api, identity);
        final user = expectOk(await account.getAccount(), 'get account');
        expect(user.fullName, isNotEmpty);
      });

      test(
        'lists properties, then follows one into its blocks and units',
        timeout: _generous,
        () async {
          final properties = RemotePropertyRepository(api);
          final page = expectOk(
            await properties.listProperties(),
            'list properties',
          );

          if (page.items.isEmpty) {
            markTestSkipped('This account can see no properties to follow.');
            return;
          }

          final Property first = page.items.first;
          final detail = expectOk(
            await properties.getProperty(first.id),
            'get property ${first.id}',
          );
          expect(detail.id, first.id);

          // A property with no blocks is a legitimate answer, not a failure —
          // what is being checked is that the route round-trips and maps.
          expectOk(
            await properties.listBuildings(first.id),
            'list blocks for ${first.id}',
          );

          final units = RemoteUnitRepository(api);
          final unitPage = expectOk(
            await units.listUnits(
              // Not just the vacant ones: the probe is checking the route, and
              // a fully let property would otherwise look like a broken call.
              filter: UnitFilter(propertyId: first.id, availableOnly: false),
            ),
            'list units in ${first.id}',
          );

          if (unitPage.items.isEmpty) {
            markTestSkipped('Property ${first.id} has no units to follow.');
            return;
          }

          final Unit unit = unitPage.items.first;
          final unitDetail = expectOk(
            await units.getUnit(unit.id),
            'get unit ${unit.id}',
          );
          expect(unitDetail.id, unit.id);
        },
      );

      test('reads this tenant\'s invoices', timeout: _generous, () async {
        final tenantId = switch (await identity.tenantId()) {
          Ok<String>(:final value) => value,
          // Only a tenant account has a tenant record; a manager or owner
          // signing in has none, and that is not a broken route.
          Err<String>() => null,
        };

        if (tenantId == null) {
          markTestSkipped('This account has no tenant record.');
          return;
        }

        final invoices = RemoteInvoiceRepository(api, identity);
        expectOk(
          await invoices.listInvoicesForTenant(tenantId),
          'list invoices for $tenantId',
        );
      });

      test(
        'reads the money that actually arrived',
        timeout: _generous,
        () async {
          final treasury = RemoteTreasuryRepository(api);
          expectOk(
            await treasury.listMpesaTransactions(),
            'list M-Pesa transactions',
          );
          expectOk(await treasury.listBankPayments(), 'list bank payments');
        },
      );

      test('reads users, roles and claims', timeout: _generous, () async {
        final access = RemoteAccessRepository(api);
        expectOk(await access.listUsers(), 'list users');
        expectOk(await access.listRoles(), 'list roles');
        expectOk(await access.rolesForUser(_phone), 'roles for $_phone');
        expectOk(await access.claimsForUser(_phone), 'claims for $_phone');
      });
    },
  );
}
