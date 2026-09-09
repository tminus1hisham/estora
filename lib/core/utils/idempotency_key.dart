import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Idempotency keys for financial requests (section 66).
///
/// The rule is that retrying the same *user intent* must never charge twice,
/// create two payments, or create two bookings. A key generated fresh on every
/// button press would not satisfy that — the tenant taps "Pay", the request
/// times out on a flaky mobile network, they tap again, and a naive client
/// sends a new key and a second charge happens.
///
/// So keys are scoped to the intent (for example `booking-create:unit_123`) and
/// **persisted**. The key survives an app restart and is only cleared once the
/// intent reaches a terminal state.
class IdempotencyKeys {
  IdempotencyKeys(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();
  static const String _prefix = 'idempotency:';

  /// Returns the existing key for [intent], or mints and stores a new one.
  ///
  /// Call this immediately before issuing the request, and pass the same
  /// [intent] on every retry of that request.
  Future<String> forIntent(String intent) async {
    final storageKey = '$_prefix$intent';
    final existing = _prefs.getString(storageKey);
    if (existing != null) return existing;

    final key = _uuid.v4();
    await _prefs.setString(storageKey, key);
    return key;
  }

  /// Drops the stored key once the intent has completed — successfully or with
  /// a terminal failure. The next attempt at the same intent is then genuinely
  /// a new one and gets a new key.
  Future<void> release(String intent) async {
    await _prefs.remove('$_prefix$intent');
  }

  /// Intent identifier for creating a booking on a specific unit.
  static String bookingIntent(String unitId) => 'booking-create:$unitId';

  /// Intent identifier for paying a specific invoice. Keyed by invoice so that
  /// paying invoice A and invoice B are separate intents, while retrying
  /// invoice A is the same one.
  static String invoicePaymentIntent(String invoiceId) =>
      'invoice-payment:$invoiceId';

  /// Intent identifier for paying a booking fee (section 24).
  static String bookingFeePaymentIntent(String bookingId) =>
      'booking-fee-payment:$bookingId';

  /// Intent identifier for recording a payment made outside the app.
  ///
  /// Keyed on the bank's own reference, because that is what makes two
  /// submissions the same payment: the same transfer keyed twice after a
  /// timeout is one payment, and two genuine transfers never share a
  /// reference.
  static String bankPaymentIntent(String paymentReference) =>
      'bank-payment:${paymentReference.trim().toUpperCase()}';
}
