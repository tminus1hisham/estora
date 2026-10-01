import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/owner.dart';
import '../../../domain/entities/property.dart';
import '../../../services/providers.dart';
import '../../properties/application/property_controller.dart';
import '../../units/application/unit_controller.dart';

/// Section 88. The owner's position, fetched in one call.
///
/// The same shape as [DashboardController]: one payload for the opening screen,
/// so the app is never stitching a headline figure together out of several
/// calls that were each true at a different moment.
final ownerPortfolioProvider =
    AsyncNotifierProvider<OwnerPortfolioController, OwnerPortfolio>(
      OwnerPortfolioController.new,
      // Keep errors stable; the screen offers an explicit refresh.
      retry: (_, _) => null,
    );

class OwnerPortfolioController extends AsyncNotifier<OwnerPortfolio> {
  @override
  Future<OwnerPortfolio> build() async {
    final result = await ref.read(ownerRepositoryProvider).getPortfolio();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }
}

/// One property's performance.
///
/// Kept separate from the portfolio rather than read out of it, so the detail
/// screen can be refreshed on its own and deep-linked into without the whole
/// portfolio having been loaded first.
final propertyPerformanceProvider = FutureProvider.autoDispose
    .family<PropertyPerformance, String>((ref, propertyId) async {
      final result = await ref
          .read(ownerRepositoryProvider)
          .getPropertyPerformance(propertyId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

/// What a repricing would move, for the confirmation to name.
final repricingImpactProvider = FutureProvider.autoDispose
    .family<RepricingImpact, String>((ref, propertyId) async {
      final result = await ref
          .read(ownerRepositoryProvider)
          .getRepricingImpact(propertyId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

/// Every unit in a property, with who is in it.
final rentRollProvider = FutureProvider.autoDispose.family<List<RentRollEntry>, String>((
  ref,
  propertyId,
) async {
  final result = await ref
      .read(ownerRepositoryProvider)
      .getRentRoll(propertyId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// Tenancies across the whole portfolio.
final ownerTenanciesProvider = FutureProvider<List<OwnerTenancy>>((ref) async {
  final result = await ref.read(ownerRepositoryProvider).getTenancies();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final ownerTenancyProvider = FutureProvider.autoDispose
    .family<OwnerTenancy, String>((ref, leaseId) async {
      final result = await ref
          .read(ownerRepositoryProvider)
          .getTenancy(leaseId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });

/// What came in, what is owed, and what is due out.
final ownerLedgerProvider = FutureProvider<OwnerLedger>((ref) async {
  final result = await ref.read(ownerRepositoryProvider).getLedger();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// Which slice of collections the Money screen is looking at.
///
/// Opens on the month, which is the figure the screen is named for; the
/// narrower windows are a question the owner asks, not the default answer.
final collectionWindowProvider =
    NotifierProvider<CollectionWindowController, CollectionWindow>(
      CollectionWindowController.new,
    );

class CollectionWindowController extends Notifier<CollectionWindow> {
  @override
  CollectionWindow build() => const CollectionWindow.month();

  void select(CollectionWindow window) => state = window;
}

/// Which property the Revenue screen is cut to; null is every property.
///
/// Opens on the whole portfolio, which is the report the screen is for. One
/// property is a question the owner asks of it, and only an owner with more
/// than one property is offered the question at all.
final reportPropertyProvider =
    NotifierProvider<ReportPropertyController, String?>(
      ReportPropertyController.new,
    );

class ReportPropertyController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? propertyId) => state = propertyId;
}

/// The owner's money as the contract serves it, cut to the chosen property.
///
/// Re-fetched per property rather than narrowed from the whole-portfolio
/// answer, because the contract keys both of its landlord-side money routes
/// on a property: the filter is the server's, not the app's. The previous
/// answer is kept while the next one loads, so the screen changes figures
/// rather than blanking between properties.
final ownerReportProvider = FutureProvider.family<OwnerReport, String?>((
  ref,
  propertyId,
) async {
  final result = await ref
      .read(ownerRepositoryProvider)
      .getReport(propertyId: propertyId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}, retry: (_, _) => null);

// Preserve the previous selection while a new property's report loads.
final selectedOwnerReportProvider = FutureProvider<OwnerReport>((ref) {
  final propertyId = ref.watch(reportPropertyProvider);
  return ref.watch(ownerReportProvider(propertyId).future);
}, retry: (_, _) => null);

final ownerActionsProvider = Provider<OwnerActions>(OwnerActions.new);

/// The owner's writes.
///
/// Separate from the read providers because these are commands, not state: a
/// screen calls one, gets a result, and decides what to do. Anything that
/// changes the portfolio invalidates it afterwards, so the next read is the
/// server's answer rather than a locally patched copy.
class OwnerActions {
  OwnerActions(this._ref);

  final Ref _ref;

  static const _uuid = Uuid();

  Future<Result<Property>> createProperty(PropertyDraft draft) async {
    // Section 66. The key is minted per draft rather than per tap, so a retry
    // after a timeout replays the first attempt instead of registering the
    // property twice.
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = 'owner-property-create:${draft.name.trim().toLowerCase()}';
    final key = await keys.forIntent(intent);

    final result = await _ref
        .read(ownerRepositoryProvider)
        .createProperty(draft: draft, idempotencyKey: key);

    if (result case Ok()) {
      await keys.release(intent);
      _invalidate();
    }
    return result;
  }

  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
  }) async {
    // A batch has no natural identity, so one is minted here and kept for the
    // life of the call.
    final result = await _ref
        .read(ownerRepositoryProvider)
        .createUnits(
          propertyId: propertyId,
          draft: draft,
          idempotencyKey: 'owner-units:${_uuid.v4()}',
        );

    if (result case Ok()) _invalidate(propertyId: propertyId);
    return result;
  }

  Future<Result<Property>> setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  }) async {
    final result = await _ref
        .read(ownerRepositoryProvider)
        .setRatePerSqm(
          propertyId: propertyId,
          rate: rate,
          repriceExistingUnits: repriceExistingUnits,
        );

    if (result case Ok()) _invalidate(propertyId: propertyId);
    return result;
  }

  Future<Result<void>> setUnitRent({
    required String unitId,
    required String propertyId,
    Money? override,
  }) async {
    final result = await _ref
        .read(ownerRepositoryProvider)
        .setUnitRent(unitId: unitId, override: override);

    if (result case Ok()) _invalidate(propertyId: propertyId);
    return result;
  }

  /// Anything that moves a rent moves the rent roll, so the portfolio and the
  /// property both have to be re-read rather than patched in place.
  void _invalidate({String? propertyId}) {
    _ref.invalidate(availabilityProvider);
    _ref.invalidate(propertyListProvider);
    _ref.invalidate(ownerPortfolioProvider);
    _ref.invalidate(ownerTenanciesProvider);
    _ref.invalidate(ownerLedgerProvider);
    _ref.invalidate(ownerReportProvider);
    if (propertyId != null) {
      _ref.invalidate(propertyPerformanceProvider(propertyId));
      _ref.invalidate(repricingImpactProvider(propertyId));
      _ref.invalidate(rentRollProvider(propertyId));
    }
  }
}

/// A user-facing message for a failed owner write.
String ownerFailureMessage(Failure failure) => switch (failure) {
  ConflictFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  NotFoundFailure() => 'That property could not be found.',
  _ => 'That did not go through. Please try again.',
};
