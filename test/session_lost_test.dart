// What the app does once the transport gives up on a session.
//
// `ApiClient` clears the tokens when the server refuses to renew them; that
// alone leaves the tenant looking at a signed-in shell whose every request
// now fails. The signal it raises has to reach the auth controller, which is
// what takes the app back to sign-in — and only when someone is signed in.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/error/failure.dart';
import 'package:mall/modules/auth/application/auth_controller.dart';
import 'package:mall/services/providers.dart';
import 'package:mall/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/repository_overrides.dart';

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
  /// Waits out the mock's simulated latency until [test] holds.
  Future<void> until(
    ProviderContainer container,
    bool Function(AuthState state) test,
  ) async {
    for (var i = 0; i < 40; i++) {
      if (test(container.read(authControllerProvider))) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail(
      'The auth state never settled: '
      '${container.read(authControllerProvider).stage}',
    );
  }

  Future<ProviderContainer> signedIn() async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        tokenStoreProvider.overrideWithValue(_Tokens()),
        ...mockRepositoryOverrides,
      ],
    );
    addTearDown(container.dispose);

    // Keep the controller alive for the test, as the router would.
    container.listen(authControllerProvider, (_, _) {});
    // Let the launch-time restore settle before signing in over it.
    await until(container, (state) => state.isResolved);

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithPassword('0712345678', 'any');
    expect(ok, isTrue);
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    return container;
  }

  test('a session the server would not renew returns to sign-in', () async {
    final container = await signedIn();

    container.read(sessionLostProvider.notifier).notify();
    await until(container, (state) => !state.isAuthenticated);

    final state = container.read(authControllerProvider);
    expect(state.stage, AuthStage.unauthenticated);
    expect(state.session, isNull);
    // With a word on why, so the sign-in screen does not look like a crash.
    expect(state.failure, isA<UnauthorizedFailure>());
    expect(state.failure?.message, contains('expired'));
  });

  test('a loss reported while signed out changes nothing', () async {
    final container = await signedIn();
    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).failure, isNull);

    container.read(sessionLostProvider.notifier).notify();
    // Nothing to wait for; give a wrong reaction time to show itself.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final state = container.read(authControllerProvider);
    expect(state.stage, AuthStage.unauthenticated);
    expect(state.failure, isNull);
  });

  test('a second session lost in the same process is noticed too', () async {
    final container = await signedIn();
    container.read(sessionLostProvider.notifier).notify();
    await until(container, (state) => !state.isAuthenticated);

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithPassword('0712345678', 'any');
    expect(ok, isTrue);

    container.read(sessionLostProvider.notifier).notify();
    await until(container, (state) => !state.isAuthenticated);
    expect(container.read(authControllerProvider).session, isNull);
  });
}
