import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../domain/entities/booking.dart';
import '../../../services/providers.dart';
import '../../home/application/dashboard_controller.dart';
import '../../units/application/unit_controller.dart';

/// The server's quote for booking a unit (section 65).
///
/// Fetched fresh each time the booking screen opens: a quote is only good as
/// long as the unit is still free, and the server re-checks availability when
/// producing one.
final bookingQuoteProvider = FutureProvider.family<BookingQuote, String>((
  ref,
  unitId,
) async {
  final result = await ref.watch(bookingRepositoryProvider).getQuote(unitId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final bookingListProvider =
    AsyncNotifierProvider<BookingListController, List<Booking>>(
      BookingListController.new,
    );

class BookingListController extends AsyncNotifier<List<Booking>> {
  @override
  Future<List<Booking>> build() async {
    final result = await ref.read(bookingRepositoryProvider).listBookings();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}

final bookingDetailProvider = FutureProvider.family<Booking, String>((
  ref,
  bookingId,
) async {
  final result = await ref
      .watch(bookingRepositoryProvider)
      .getBooking(bookingId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// Creates bookings and submits requirement documents.
final bookingActionsProvider = Provider<BookingActions>(
  (ref) => BookingActions(ref),
);

class BookingActions {
  BookingActions(this._ref);

  final Ref _ref;

  /// Creates a booking for [unitId].
  ///
  /// Two things are deliberate here. The request carries the unit id and
  /// nothing else — the server determines rent, deposit, fee, tax and expiry
  /// (section 65). And the idempotency key is derived from the *intent* and
  /// persisted, so a retry after a dropped connection reuses it and cannot
  /// produce a second booking (section 66).
  Future<Result<Booking>> createBooking(String unitId) async {
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = IdempotencyKeys.bookingIntent(unitId);
    final idempotencyKey = await keys.forIntent(intent);

    final result = await _ref
        .read(bookingRepositoryProvider)
        .createBooking(unitId: unitId, idempotencyKey: idempotencyKey);

    switch (result) {
      case Ok():
        // The intent is complete. A later booking of the same unit is a new
        // intent and gets a new key.
        await keys.release(intent);
        _invalidateAfterChange(unitId: unitId);
      case Err(:final failure):
        // Keep the key for retryable failures so a second attempt is treated
        // as the same intent. A conflict is terminal — the unit is gone — so
        // the key is released.
        if (failure is ConflictFailure) {
          await keys.release(intent);
          _invalidateAfterChange(unitId: unitId);
        }
    }

    return result;
  }

  Future<Result<Booking>> cancelBooking(String bookingId) async {
    final result = await _ref
        .read(bookingRepositoryProvider)
        .cancelBooking(bookingId);
    if (result.isOk) {
      _ref.invalidate(bookingDetailProvider(bookingId));
      _invalidateAfterChange();
    }
    return result;
  }

  /// Section 18. Uploads a document against a booking requirement.
  Future<Result<BookingRequirement>> submitRequirement({
    required String bookingId,
    required String requirementId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final result = await _ref
        .read(bookingRepositoryProvider)
        .submitRequirement(
          bookingId: bookingId,
          requirementId: requirementId,
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeType,
        );

    if (result.isOk) {
      // Satisfying the last requirement can generate the lease server-side, so
      // the dashboard and booking both need re-reading.
      _ref.invalidate(bookingDetailProvider(bookingId));
      _invalidateAfterChange();
    }
    return result;
  }

  /// Anything that changes availability or the tenant's position invalidates
  /// the browse list and the home summary.
  void _invalidateAfterChange({String? unitId}) {
    if (unitId != null) {
      _ref.invalidate(unitDetailProvider(unitId));
      _ref.invalidate(bookingQuoteProvider(unitId));
    }
    _ref.invalidate(unitListProvider);
    _ref.invalidate(bookingListProvider);
    _ref.read(dashboardControllerProvider.notifier).refresh();
  }
}
