import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
import '../../bookings/application/booking_controller.dart';
import '../../documents/application/document_controller.dart';
import '../../home/application/dashboard_controller.dart';
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
    // Kicked off rather than awaited: `build` is synchronous, and the router
    // handles the interim `unknown` stage by showing the splash screen.
    Future.microtask(restore);
    return const AuthState();
  }

  /// Section 72. Restores a stored session on launch.
  Future<void> restore() async {
    final result = await ref.read(authRepositoryProvider).restoreSession();
    if (result case Ok(:final value) when value != null) {
      final requiresBiometrics = await ref
          .read(tokenStoreProvider)
          .isBiometricEnabled();

      if (requiresBiometrics) {
        final unlock = await ref
            .read(biometricUnlockProvider)
            .authenticate(reason: 'Unlock Tenant Portal to continue');
        if (!unlock.succeeded) {
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

      state = AuthState(stage: AuthStage.authenticated, session: value);
      return;
    }

    state = switch (result) {
      Ok() => const AuthState(stage: AuthStage.unauthenticated),
      // A failure here is not worth an error screen — it just means the tenant
      // signs in again.
      Err() => const AuthState(stage: AuthStage.unauthenticated),
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
        state = state.copyWith(
          isBusy: false,
          pendingChallengeId: value,
          pendingPhone: phone,
        );
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(isBusy: false, failure: failure);
        return false;
      }(),
    };
  }

  Future<bool> verifyOtp(String code) async {
    final challengeId = state.pendingChallengeId;
    if (challengeId == null) {
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
        state = AuthState(stage: AuthStage.authenticated, session: value);
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(isBusy: false, failure: failure);
        return false;
      }(),
    };
  }

  Future<bool> loginWithPassword(String email, String password) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .loginWithPassword(email: email, password: password);

    return switch (result) {
      Ok(:final value) => () {
        state = AuthState(stage: AuthStage.authenticated, session: value);
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(isBusy: false, failure: failure);
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
        state = state.copyWith(
          isBusy: false,
          pendingChallengeId: value,
          pendingPhone: phone,
        );
        return true;
      }(),
      Err(:final failure) => () {
        state = state.copyWith(isBusy: false, failure: failure);
        return false;
      }(),
    };
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(email: email);
    state = state.copyWith(
      isBusy: false,
      failure: result.failureOrNull,
      clearFailure: result.isOk,
    );
    return result.isOk;
  }

  Future<void> logout() async {
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

  void clearFailure() => state = state.copyWith(clearFailure: true);
}
