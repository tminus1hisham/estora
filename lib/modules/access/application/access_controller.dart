import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/access.dart';
import '../../../services/providers.dart';

/// Every account on the platform.
final platformUsersProvider = FutureProvider<List<PlatformUser>>((ref) async {
  final result = await ref.read(accessRepositoryProvider).listUsers();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final accessRolesProvider = FutureProvider<List<AccessRole>>((ref) async {
  final result = await ref.read(accessRepositoryProvider).listRoles();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// What one account has been granted, keyed by phone number.
///
/// Phone number rather than user id because that is what the contract's role
/// and claim routes are addressed by. An account without one cannot be granted
/// anything — see [PlatformUser.isAddressable].
final userRolesProvider = FutureProvider.family<List<AccessRole>, String>((
  ref,
  phoneNumber,
) async {
  final result = await ref
      .read(accessRepositoryProvider)
      .rolesForUser(phoneNumber);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final userClaimsProvider = FutureProvider.family<List<AccessClaim>, String>((
  ref,
  phoneNumber,
) async {
  final result = await ref
      .read(accessRepositoryProvider)
      .claimsForUser(phoneNumber);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final roleClaimsProvider = FutureProvider.family<List<AccessClaim>, String>((
  ref,
  roleName,
) async {
  final result = await ref
      .read(accessRepositoryProvider)
      .claimsForRole(roleName);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final accessActionsProvider = Provider<AccessActions>(
  (ref) => AccessActions(ref),
);

/// Granting and revoking.
///
/// Nothing here decides whether an action is *allowed* — that is the server's
/// judgement, and a client that pre-empted it would be a client that disagrees
/// with the server sooner or later. These methods ask, and refresh what the
/// answer changed.
class AccessActions {
  AccessActions(this._ref);

  final Ref _ref;

  Future<Result<void>> toggleEnabled(String userId) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .toggleUserEnabled(userId);
    if (result.isOk) _ref.invalidate(platformUsersProvider);
    return result;
  }

  Future<Result<void>> deleteUser(String userId) async {
    final result = await _ref.read(accessRepositoryProvider).deleteUser(userId);
    if (result.isOk) _ref.invalidate(platformUsersProvider);
    return result;
  }

  Future<Result<void>> createRole(String roleName) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .createRole(roleName);
    if (result.isOk) _ref.invalidate(accessRolesProvider);
    return result;
  }

  Future<Result<void>> addUserToRole({
    required String phoneNumber,
    required String roleName,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .addUserToRole(phoneNumber: phoneNumber, roleName: roleName);
    if (result.isOk) _invalidateUser(phoneNumber);
    return result;
  }

  Future<Result<void>> removeUserFromRole({
    required String phoneNumber,
    required String roleName,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .removeUserFromRole(phoneNumber: phoneNumber, roleName: roleName);
    if (result.isOk) _invalidateUser(phoneNumber);
    return result;
  }

  Future<Result<void>> addClaimToUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .addClaimToUser(
          phoneNumber: phoneNumber,
          claimType: claimType,
          claimValue: claimValue,
        );
    if (result.isOk) _invalidateUser(phoneNumber);
    return result;
  }

  Future<Result<void>> removeClaimFromUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .removeClaimFromUser(
          phoneNumber: phoneNumber,
          claimType: claimType,
          claimValue: claimValue,
        );
    if (result.isOk) _invalidateUser(phoneNumber);
    return result;
  }

  Future<Result<void>> addClaimToRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .addClaimToRole(
          roleName: roleName,
          claimType: claimType,
          claimValue: claimValue,
        );
    if (result.isOk) _ref.invalidate(roleClaimsProvider(roleName));
    return result;
  }

  Future<Result<void>> removeClaimFromRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) async {
    final result = await _ref
        .read(accessRepositoryProvider)
        .removeClaimFromRole(
          roleName: roleName,
          claimType: claimType,
          claimValue: claimValue,
        );
    if (result.isOk) _ref.invalidate(roleClaimsProvider(roleName));
    return result;
  }

  /// A grant changes what one account holds *and* what the list shows against
  /// it, so both go.
  void _invalidateUser(String phoneNumber) {
    _ref.invalidate(userRolesProvider(phoneNumber));
    _ref.invalidate(userClaimsProvider(phoneNumber));
    _ref.invalidate(platformUsersProvider);
  }
}
