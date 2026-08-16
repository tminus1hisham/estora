import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/owner.dart';
import '../../../services/providers.dart';

/// Section 88. The owner's position, fetched in one call.
///
/// The same shape as [DashboardController]: one payload for the opening screen,
/// so the app is never stitching a headline figure together out of several
/// calls that were each true at a different moment.
final ownerPortfolioProvider =
    AsyncNotifierProvider<OwnerPortfolioController, OwnerPortfolio>(
      OwnerPortfolioController.new,
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
    state = await AsyncValue.guard(build);
  }
}

/// One property's performance.
///
/// Kept separate from the portfolio rather than read out of it, so the detail
/// screen can be refreshed on its own and deep-linked into without the whole
/// portfolio having been loaded first.
final propertyPerformanceProvider =
    FutureProvider.family<PropertyPerformance, String>((ref, propertyId) async {
      final result = await ref
          .read(ownerRepositoryProvider)
          .getPropertyPerformance(propertyId);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    });
