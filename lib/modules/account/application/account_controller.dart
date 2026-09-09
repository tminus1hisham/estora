import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/access.dart';
import '../../../services/providers.dart';

/// The signed-in account as the server holds it.
///
/// Distinct from `authControllerProvider`, which holds the session. This is the
/// record: what is confirmed, what is not, whether two-factor is on. The
/// security screen reads it, and every action on that screen refreshes it,
/// because the whole point of the screen is to show state that has just
/// changed.
final myAccountProvider = FutureProvider<PlatformUser>((ref) async {
  final result = await ref.read(accountRepositoryProvider).getAccount();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final accountActionsProvider = Provider<AccountActions>(
  (ref) => AccountActions(ref),
);

class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  Future<Result<void>> changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _ref
        .read(accountRepositoryProvider)
        .changePassword(
          phoneNumber: phoneNumber,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }

  /// Finishes a reset begun on the forgot-password screen.
  ///
  /// Not authenticated: whoever is doing this could not sign in, which is why
  /// they are here. The token is what stands in for the session.
  Future<Result<void>> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) => _ref
      .read(accountRepositoryProvider)
      .resetPassword(
        phoneNumber: phoneNumber,
        resetToken: resetToken,
        newPassword: newPassword,
      );

  Future<Result<void>> enableTwoFactor() async {
    final result = await _ref.read(accountRepositoryProvider).enableTwoFactor();
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }

  Future<Result<void>> verifyTwoFactor({
    required String email,
    required String code,
  }) async {
    final result = await _ref
        .read(accountRepositoryProvider)
        .verifyTwoFactor(email: email, code: code);
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }

  Future<Result<void>> confirmEmail({
    required String email,
    required String token,
  }) async {
    final result = await _ref
        .read(accountRepositoryProvider)
        .confirmEmail(email: email, token: token);
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }

  Future<Result<void>> confirmPhoneNumber({
    required String email,
    required String phoneNumber,
    required String token,
  }) async {
    final result = await _ref
        .read(accountRepositoryProvider)
        .confirmPhoneNumber(
          email: email,
          phoneNumber: phoneNumber,
          token: token,
        );
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }

  Future<Result<void>> updateAccount({
    required String userId,
    required String fullName,
    required String emailAddress,
    required String phoneNumber,
  }) async {
    final result = await _ref
        .read(accountRepositoryProvider)
        .updateAccount(
          userId: userId,
          fullName: fullName,
          emailAddress: emailAddress,
          phoneNumber: phoneNumber,
        );
    if (result.isOk) _ref.invalidate(myAccountProvider);
    return result;
  }
}
