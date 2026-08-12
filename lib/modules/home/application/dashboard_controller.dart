import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../services/providers.dart';

/// Section 44's home screen payload.
///
/// One fetch, one object. The alternative — pulling invoices and payments and
/// summing them on the handset — would get the outstanding balance wrong as
/// soon as the list was paginated, and section 71 asks for these figures to be
/// derived from transactional data, which only the server holds in full.
final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummary>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() async {
    final result = await ref.read(dashboardRepositoryProvider).getSummary();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  /// Pull to refresh, and called after any action that could change the
  /// summary — a payment settling, a booking expiring, a lease activating.
  ///
  /// Does not flip back to a bare loading state: the previous summary stays on
  /// screen while the refresh runs, so pulling to refresh does not blank the
  /// tenant's balance for half a second.
  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}
