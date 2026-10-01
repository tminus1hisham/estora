import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/entities/booking.dart';
import '../../../services/providers.dart';
import '../../owner/application/owner_controller.dart';
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
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }
}

final bookingDetailProvider = FutureProvider.autoDispose
    .family<Booking, String>((ref, bookingId) async {
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

  /// Creates a booking for [unitId] on behalf of [applicant].
  ///
  /// Two things are deliberate here. The request carries the unit and who is
  /// asking, and no amounts — the server determines rent, deposit, fee, tax
  /// and expiry (section 65). And the idempotency key is derived from the
  /// *intent* and persisted, so a retry after a dropped connection reuses it
  /// and cannot produce a second booking (section 66).
  Future<Result<Booking>> createBooking(
    BookingTarget target, {
    required BookingApplicant applicant,
  }) async {
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = IdempotencyKeys.bookingIntent(target.intent);
    final idempotencyKey = await keys.forIntent(intent);

    final result = await _ref
        .read(bookingRepositoryProvider)
        .createBooking(
          target: target,
          applicant: applicant,
          idempotencyKey: idempotencyKey,
        );

    final unitId = switch (target) {
      UnitTarget(:final unitId) => unitId,
      SpaceTarget() => null,
    };

    switch (result) {
      case Ok():
        // The intent is complete. A later booking of the same space is a new
        // intent and gets a new key.
        await keys.release(intent);
        _invalidateAfterChange(unitId: unitId);
      case Err(:final failure):
        // Keep the key for retryable failures so a second attempt is treated
        // as the same intent. A conflict is terminal — the space is gone — so
        // the key is released.
        if (failure is ConflictFailure) {
          await keys.release(intent);
          _invalidateAfterChange(unitId: unitId);
        }
    }

    return result;
  }

  /// Sends an enquiry about a property.
  ///
  /// Nothing is booked, priced or paid: the request is who is asking and
  /// what they want, and the answer is an acknowledgement. The idempotency
  /// key is derived from the intent and persisted, so a retry after a
  /// dropped connection reuses it and the landlord is not asked twice. It is
  /// released once the server has acknowledged, so a later enquiry about the
  /// same property is a new one.
  Future<Result<EnquiryReceipt>> sendEnquiry(PropertyEnquiry enquiry) async {
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = IdempotencyKeys.enquiryIntent(enquiry.intent);
    final idempotencyKey = await keys.forIntent(intent);

    final result = await _ref
        .read(bookingRepositoryProvider)
        .sendEnquiry(enquiry, idempotencyKey: idempotencyKey);

    if (result.isOk) await keys.release(intent);
    return result;
  }

  /// Section 24. Asks the server to prompt [phoneNumber] for the booking fee.
  ///
  /// The amount on the request is [Booking.bookingFee] — the figure the
  /// server captured on the booking — carried back because the contract
  /// wants it on the wire. Nothing here computes it.
  ///
  /// The idempotency key is scoped to the booking and persisted, so a retry
  /// over a dropped connection reuses it and cannot raise a second prompt
  /// (section 66). It is not released here: the prompt is live on the
  /// handset until [confirmFeePaid] sees the server record the fee, or the
  /// tenant asks for a fresh one through [restartFeePrompt].
  Future<Result<PaymentPrompt>> requestFeePrompt(
    Booking booking, {
    required String phoneNumber,
  }) async {
    final idempotencyKey = await _ref
        .read(idempotencyKeysProvider)
        .forIntent(IdempotencyKeys.bookingFeePaymentIntent(booking.id));

    return _ref
        .read(bookingRepositoryProvider)
        .requestBookingFeePrompt(
          bookingId: booking.id,
          phoneNumber: phoneNumber,
          amount: booking.bookingFee,
          idempotencyKey: idempotencyKey,
        );
  }

  /// The tenant wants the prompt sent again — to a corrected number, or
  /// after declining the first. That is a new intent by their own decision,
  /// and gets a new key.
  Future<void> restartFeePrompt(String bookingId) => _ref
      .read(idempotencyKeysProvider)
      .release(IdempotencyKeys.bookingFeePaymentIntent(bookingId));

  /// Re-reads the booking and answers whether the server now holds the fee.
  ///
  /// This is the only way the app learns the prompt was answered. The
  /// confirmation route gives back a message and nothing to poll, so the
  /// booking record is the source of truth — section 39's rule that the
  /// handset never decides a payment succeeded. A `false` is "not yet", not
  /// "failed": the prompt may still be open on the phone.
  Future<Result<bool>> confirmFeePaid(String bookingId) async {
    final result = await _ref
        .read(bookingRepositoryProvider)
        .getBooking(bookingId);

    if (result case Ok(:final value) when !value.canPayFee) {
      await _ref
          .read(idempotencyKeysProvider)
          .release(IdempotencyKeys.bookingFeePaymentIntent(bookingId));
      // A paid fee activates the booking and starts its clock server-side,
      // and can raise the deposit invoice; everything that shows any of that
      // is re-read.
      _ref.invalidate(bookingDetailProvider(bookingId));
      _invalidateAfterChange(unitId: value.unitId);
      return const Ok(true);
    }

    return result.map((booking) => !booking.canPayFee);
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
    _ref.invalidate(ownerReportProvider);
    if (unitId != null) {
      _ref.invalidate(unitDetailProvider(unitId));
      _ref.invalidate(bookingQuoteProvider(unitId));
    }
    _ref.invalidate(availabilityProvider);
    _ref.invalidate(unitListProvider);
    _ref.invalidate(bookingListProvider);
    _ref.read(dashboardControllerProvider.notifier).refresh();
  }
}
