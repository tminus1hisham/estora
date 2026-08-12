import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';

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
    state = switch (result) {
      Ok(:final value) when value != null => AuthState(
        stage: AuthStage.authenticated,
        session: value,
      ),
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
    state = const AuthState(stage: AuthStage.unauthenticated);
    // Every cached tenant-scoped provider must go with the session. Leaving
    // one behind would show the previous tenant's data to the next person to
    // sign in on this device (section 74).
    ref.invalidateSelf();
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}
