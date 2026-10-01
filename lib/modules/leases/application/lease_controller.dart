import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/lease.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../services/providers.dart';
import '../../home/application/dashboard_controller.dart';

final leaseListProvider =
    AsyncNotifierProvider<LeaseListController, List<Lease>>(
      LeaseListController.new,
    );

class LeaseListController extends AsyncNotifier<List<Lease>> {
  @override
  Future<List<Lease>> build() async {
    final result = await ref.read(leaseRepositoryProvider).listLeases();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }
}

final leaseDetailProvider = FutureProvider.autoDispose.family<Lease, String>((
  ref,
  leaseId,
) async {
  final result = await ref.watch(leaseRepositoryProvider).getLease(leaseId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// The agreement as rendered for signing (section 29).
///
/// Carries a `documentHash` identifying this exact version. That hash goes back
/// with the signature, which is what binds the signature to the text the tenant
/// actually read — if the agreement were regenerated in between, the server
/// would reject the stale hash rather than record a signature against wording
/// nobody saw.
final leaseAgreementProvider = FutureProvider.autoDispose
    .family<LeaseAgreement, String>((ref, leaseId) async {
      final result = await ref
          .watch(leaseRepositoryProvider)
          .getAgreement(leaseId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

final leaseActionsProvider = Provider<LeaseActions>((ref) => LeaseActions(ref));

class LeaseActions {
  LeaseActions(this._ref);

  final Ref _ref;

  /// Section 29. Submits the tenant's drawn signature.
  ///
  /// The lease does not become ACTIVE as a result — section 30 also requires
  /// the deposit, the documents and the property manager's approval, and the
  /// server owns that decision. This moves it to SIGNED and no further.
  Future<Result<Lease>> sign({
    required String leaseId,
    required List<int> signatureData,
    required String documentHash,
  }) async {
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = 'lease-sign:$leaseId';
    final idempotencyKey = await keys.forIntent(intent);

    final result = await _ref
        .read(leaseRepositoryProvider)
        .signLease(
          leaseId: leaseId,
          signatureType: SignatureType.drawnSignature,
          signatureData: signatureData,
          documentHash: documentHash,
          idempotencyKey: idempotencyKey,
        );

    if (result.isOk) {
      await keys.release(intent);
      _ref.invalidate(leaseDetailProvider(leaseId));
      _ref.invalidate(leaseAgreementProvider(leaseId));
      _ref.invalidate(leaseListProvider);
      _ref.read(dashboardControllerProvider.notifier).refresh();
    }

    return result;
  }
}
