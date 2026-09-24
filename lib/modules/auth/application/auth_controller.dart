import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/debug/debug_log.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
import '../../owner/application/owner_controller.dart';
import '../../access/application/access_controller.dart';
import '../../treasury/application/treasury_controller.dart';
import '../../structure/application/structure_controller.dart';
import '../../account/application/account_controller.dart';
import '../../bookings/application/booking_controller.dart';
import '../../documents/application/document_controller.dart';
import '../../home/application/dashboard_controller.dart';
import '../../invoices/application/billing_property_filter.dart';
import '../../invoices/application/invoice_controller.dart';
import '../../leases/application/lease_controller.dart';
import '../../notifications/application/notification_controller.dart';
import '../../payments/application/payment_controller.dart';
import '../../properties/application/property_controller.dart';
import '../../units/application/unit_controller.dart';

class BiometricUnlockResult {
  const BiometricUnlockResult._({required this.succeeded, this.message});

  const BiometricUnlockResult.success() : this._(succeeded: true);

  const BiometricUnlockResult.failure(String message)
    : this._(succeeded: false, message: message);

  final bool succeeded;
  final String? message;
}

/// Shared boundary around the platform biometric prompt.
///
/// Both session restoration and Settings use this service, so opting in is
/// backed by a real authentication challenge rather than a stored toggle alone.
class BiometricUnlockService {
  BiometricUnlockService([LocalAuthentication? authentication])
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<bool> isAvailable() async {
    try {
      if (!await _authentication.canCheckBiometrics) return false;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricUnlockResult> authenticate({required String reason}) async {
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? const BiometricUnlockResult.success()
          : const BiometricUnlockResult.failure(
              'Biometric authentication was not completed.',
            );
    } on LocalAuthException catch (error) {
      return BiometricUnlockResult.failure(switch (error.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          'Set up fingerprint or face recognition in your device settings '
              'first.',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Biometrics are locked. Unlock your device normally, then try '
              'again.',
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          'Biometric authentication was cancelled.',
        _ => 'Biometric authentication is unavailable right now.',
      });
    } catch (_) {
      return const BiometricUnlockResult.failure(
        'Biometric authentication is unavailable right now.',
      );
    }
  }
}

final biometricUnlockProvider = Provider<BiometricUnlockService>(
  (ref) => BiometricUnlockService(),
);

/// Where the app is in the sign-in lifecycle.
///
/// The router watches this to decide whether to show the auth screens or the
/// main shell, which is why [unknown] exists as a distinct state: during
/// startup we do not yet know, and redirecting to login before the stored
/// session has been read would flash the login screen at a signed-in tenant.
enum AuthStage { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.stage = AuthStage.unknown,
    this.session,
    this.failure,
    this.isBusy = false,
    this.pendingChallengeId,
    this.pendingPhone,
  });

  final AuthStage stage;
  final AuthSession? session;
  final Failure? failure;
  final bool isBusy;

  /// Set between requesting an OTP and verifying it.
  final String? pendingChallengeId;
  final String? pendingPhone;

  bool get isAuthenticated => stage == AuthStage.authenticated;
  bool get isResolved => stage != AuthStage.unknown;

  AppUser? get user => session?.user;
  Tenant? get tenant => session?.tenant;

  /// Set only on an owner account.
  PropertyOwner? get owner => session?.owner;

  /// Which shell this account belongs in. Read by the router's redirect, which
  /// is the only place the distinction is enforced.
  bool get isOwner => user?.role.isOwner ?? false;
  bool get isManager => user?.role.isManager ?? false;

  AuthState copyWith({
    AuthStage? stage,
    AuthSession? session,
    Failure? failure,
    bool? isBusy,
    String? pendingChallengeId,
    String? pendingPhone,
    bool clearFailure = false,
    bool clearChallenge = false,
    bool clearSession = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      session: clearSession ? null : (session ?? this.session),
      failure: clearFailure ? null : (failure ?? this.failure),
      isBusy: isBusy ?? this.isBusy,
      pendingChallengeId: clearChallenge
          ? null
          : (pendingChallengeId ?? this.pendingChallengeId),
      pendingPhone: clearChallenge ? null : (pendingPhone ?? this.pendingPhone),
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // The transport's word that the server would not renew the token. Reacted
    // to here rather than in `ApiClient`, which knows nothing of screens.
    ref.listen(sessionLostProvider, (_, _) => _sessionLost());

    // Kicked off rather than awaited: `build` is synchronous, and the router
    // handles the interim `unknown` stage by showing the splash screen.
    Future.microtask(restore);
    return const AuthState();
  }

  /// The server refused to renew the session, and `ApiClient` has already
  /// cleared the tokens. What is left is to take the app back to sign-in,
  /// with a word on why, and to drop the caches the way sign-out does.
  ///
  /// Nothing to do unless someone is signed in: a loss during `restore` is
  /// already answered by `restore` itself, and one after sign-out is stale.
  /// The idempotency keys are kept — they exist so a payment retried after
  /// signing back in cannot charge twice, which is exactly when a session
  /// tends to expire.
  Future<void> _sessionLost() async {
    if (!state.isAuthenticated) return;
    DebugLog.write(
      'auth',
      'The server would not renew the session; signing out',
    );
    await ref.read(authRepositoryProvider).logout();
    if (!ref.mounted) return;
    state = const AuthState(
      stage: AuthStage.unauthenticated,
      failure: UnauthorizedFailure(
        'Your session has expired. Please sign in again.',
      ),
    );
    _invalidateTenantState();
  }

  /// Section 72. Restores a stored session on launch.
  Future<void> restore() async {
    final result = await ref.read(authRepositoryProvider).restoreSession();
    if (result case Ok(:final value) when value != null) {
      final requiresBiometrics = await ref
          .read(tokenStoreProvider)
          .isBiometricEnabled();

      if (requiresBiometrics) {
        DebugLog.write('auth', 'Stored session found; unlocking biometrically');
        final unlock = await ref
            .read(biometricUnlockProvider)
            .authenticate(reason: 'Unlock Estora to continue');
        if (!unlock.succeeded) {
          // Invisible to the HTTP log, because nothing was ever sent. Without
          // this line, a handset that keeps landing on the sign-in screen with
          // a perfectly good stored session looks like a server problem.
          DebugLog.write(
            'auth',
            'Biometric unlock refused '
                '(${unlock.message ?? 'no reason given'}); staying signed out',
          );
          state = AuthState(
            stage: AuthStage.unauthenticated,
            failure: ValidationFailure(
              '${unlock.message ?? 'Biometric unlock was not completed.'} '
              'Sign in to continue.',
            ),
          );
          return;
        }
      }

      DebugLog.write('auth', 'Session restored: ${_describeSession(value)}');
      state = AuthState(stage: AuthStage.authenticated, session: value);
      return;
    }

    state = switch (result) {
      Ok() => () {
        DebugLog.write('auth', 'Nothing stored; starting signed out');
        return const AuthState(stage: AuthStage.unauthenticated);
      }(),
      Err(:final failure) => () {
        // A failure here is not worth an error screen — it just means the
        // tenant signs in again — but it is worth a line, because a rejected
        // refresh token and an unreachable server look identical on screen.
        DebugLog.write('auth', 'Could not restore a session: $failure');
        return const AuthState(stage: AuthStage.unauthenticated);
      }(),
    };
  }

  /// Section 72's primary flow: phone, then OTP.
  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .requestOtp(phone: phone);

    return switch (result) {
      Ok(:final value) => () {
        DebugLog.write(
          'auth',
          'OTP challenge $value issued; awaiting the code',
        );
        state = state.copyWith(
          isBusy: false,
          pendingChallengeId: value,
          pendingPhone: phone,
        );
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(
          isBusy: false,
          failure: _logFailure('OTP request', failure),
        );
        return false;
      }(),
    };
  }

  Future<bool> verifyOtp(String code) async {
    final challengeId = state.pendingChallengeId;
    if (challengeId == null) {
      DebugLog.write('auth', 'Code submitted with no challenge outstanding');
      state = state.copyWith(
        failure: const ValidationFailure('Request a new code to continue.'),
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(challengeId: challengeId, code: code);

    return switch (result) {
      Ok(:final value) => () {
        DebugLog.write(
          'auth',
          'Code accepted; signed in as ${_describeSession(value)}',
        );
        state = AuthState(stage: AuthStage.authenticated, session: value);
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(
          isBusy: false,
          failure: _logFailure('Code verification', failure),
        );
        return false;
      }(),
    };
  }

  /// [identifier] is whatever was typed into the sign-in field — a phone
  /// number against the published API, an email address against the mock's
  /// demo accounts. It is passed through untouched; the server decides.
  Future<bool> loginWithPassword(String identifier, String password) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .loginWithPassword(identifier: identifier, password: password);

    return switch (result) {
      Ok(:final value) => () {
        DebugLog.write(
          'auth',
          'Signed in with a password as ${_describeSession(value)}',
        );
        state = AuthState(stage: AuthStage.authenticated, session: value);
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(
          isBusy: false,
          failure: _logFailure('Password sign-in', failure),
        );
        return false;
      }(),
    };
  }

  /// Registration always finishes through phone verification, so this leaves
  /// the tenant on the OTP screen rather than signing them straight in.
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required TenantType tenantType,
  }) async {
    DebugLog.write('auth', 'Creating a ${tenantType.name} tenant account');
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .register(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          password: password,
          tenantType: tenantType,
        );

    return switch (result) {
      Ok(:final value) => () {
        DebugLog.write(
          'auth',
          'Registered a ${tenantType.name} tenant; OTP challenge $value issued',
        );
        state = state.copyWith(
          isBusy: false,
          pendingChallengeId: value,
          pendingPhone: phone,
        );
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(
          isBusy: false,
          failure: _logFailure('Registration', failure),
        );
        return false;
      }(),
    };
  }

  Future<bool> requestPasswordReset(String identifier) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(identifier: identifier);
    state = state.copyWith(
      isBusy: false,
      failure: result.failureOrNull,
      clearFailure: result.isOk,
    );
    return result.isOk;
  }

  Future<void> logout() async {
    DebugLog.write('auth', 'Signing out; clearing tokens and tenant caches');
    await ref.read(authRepositoryProvider).logout();
    // The remote repository clears this too. Repeating the clear covers demo
    // sessions and ensures biometric opt-in cannot outlive its tokens.
    await ref.read(tokenStoreProvider).clear();
    await _clearPersistedTenantIntents();

    state = const AuthState(stage: AuthStage.unauthenticated);
    // Every cached tenant-scoped provider must go with the session. Leaving
    // one behind would show the previous tenant's data to the next person to
    // sign in on this device (section 74).
    _invalidateTenantState();
  }

  /// What a session amounts to, in one line.
  ///
  /// The role and the two records decide which shell the account lands in, so
  /// they are the first thing to check when someone is signed in and looking
  /// at the wrong side of the platform. The id identifies the account without
  /// putting a name, an email or a phone number in the log.
  String _describeSession(AuthSession session) =>
      'user ${session.user.id} (${session.user.role.name}, '
      'tenant record: ${session.tenant != null}, '
      'owner record: ${session.owner != null})';

  /// Records a refused step and hands the failure straight back, so a call
  /// site can log it and assign it in one breath.
  ///
  /// The tenant only ever sees `failure.message`. Kept here are the code and
  /// the field errors, which are what separate a wrong password from a rate
  /// limit from a handset with no signal.
  Failure _logFailure(String step, Failure failure) {
    DebugLog.write('auth', '$step refused: $failure');
    if (failure case ValidationFailure(
      :final fieldErrors,
    ) when fieldErrors.isNotEmpty) {
      DebugLog.write('auth', '$step field errors', detail: fieldErrors);
    }
    return failure;
  }

  Future<void> _clearPersistedTenantIntents() async {
    final preferences = ref.read(sharedPreferencesProvider);
    final keys = preferences.getKeys().where(
      (key) => key.startsWith('idempotency:'),
    );
    for (final key in keys.toList(growable: false)) {
      await preferences.remove(key);
    }
  }

  void _invalidateTenantState() {
    ref.invalidate(ownerPortfolioProvider);
    ref.invalidate(propertyPerformanceProvider);
    ref.invalidate(repricingImpactProvider);
    ref.invalidate(rentRollProvider);
    ref.invalidate(ownerTenanciesProvider);
    ref.invalidate(ownerTenancyProvider);
    ref.invalidate(ownerLedgerProvider);
    ref.invalidate(reportPropertyProvider);
    ref.invalidate(ownerReportProvider);
    ref.invalidate(platformUsersProvider);
    ref.invalidate(accessRolesProvider);
    ref.invalidate(userRolesProvider);
    ref.invalidate(userClaimsProvider);
    ref.invalidate(roleClaimsProvider);
    ref.invalidate(mpesaTransactionsProvider);
    ref.invalidate(mpesaSearchProvider);
    ref.invalidate(mpesaSearchResultProvider);
    ref.invalidate(bankPaymentsProvider);
    ref.invalidate(propertyBlocksProvider);
    ref.invalidate(blockProvider);
    ref.invalidate(blockUnitsProvider);
    ref.invalidate(myAccountProvider);

    ref.invalidate(dashboardControllerProvider);

    ref.invalidate(propertyListProvider);
    ref.invalidate(propertyDetailProvider);
    ref.invalidate(unitFilterProvider);
    ref.invalidate(unitListProvider);
    ref.invalidate(unitDetailProvider);
    ref.invalidate(unitPricingProvider);
    ref.invalidate(unitTypesProvider);

    ref.invalidate(bookingQuoteProvider);
    ref.invalidate(bookingListProvider);
    ref.invalidate(bookingDetailProvider);
    ref.invalidate(leaseListProvider);
    ref.invalidate(leaseDetailProvider);
    ref.invalidate(leaseAgreementProvider);

    ref.invalidate(invoiceTabProvider);
    // The chosen property is an id, and the next account may lease at the
    // same one; a stale choice would open their statement already narrowed.
    ref.invalidate(billingPropertyFilterProvider);
    ref.invalidate(invoiceListProvider);
    ref.invalidate(filteredInvoicesProvider);
    ref.invalidate(invoiceDetailProvider);
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(paymentStatusProvider);
    ref.invalidate(receiptForPaymentProvider);
    ref.invalidate(receiptProvider);

    ref.invalidate(documentFilterProvider);
    ref.invalidate(documentListProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(notificationListProvider);
    ref.invalidate(notificationChannelsProvider);
  }

  /// Reload account details without re-running biometric unlock or signing out
  /// on a transient failure. Ignore a response if the session changed meanwhile.
  Future<void> refreshProfile() async {
    final session = state.session;
    if (session == null) return;
    final result = await ref.read(authRepositoryProvider).restoreSession();
    if (!ref.mounted || !identical(state.session, session)) return;
    switch (result) {
      case Ok(:final value) when value != null:
        state = state.copyWith(session: value);
      case Err(:final failure):
        throw failure;
      case Ok():
        throw const UnauthorizedFailure('Please sign in again.');
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}
