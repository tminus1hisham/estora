import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/billing.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';
import '../../bookings/application/booking_controller.dart';
import '../../home/application/dashboard_controller.dart';
import '../../invoices/application/invoice_controller.dart';
import '../../leases/application/lease_controller.dart';

final paymentHistoryProvider =
    AsyncNotifierProvider<PaymentHistoryController, List<Payment>>(
      PaymentHistoryController.new,
    );

class PaymentHistoryController extends AsyncNotifier<List<Payment>> {
  @override
  Future<List<Payment>> build() async {
    final result = await ref.read(paymentRepositoryProvider).listPayments();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}

/// Starts payments.
final paymentActionsProvider = Provider<PaymentActions>(
  (ref) => PaymentActions(ref),
);

class PaymentActions {
  PaymentActions(this._ref);

  final Ref _ref;

  /// Section 39, steps 1 to 3.
  ///
  /// [amount] is the invoice's outstanding balance exactly as the server last
  /// stated it — read off the invoice, never derived here. The published
  /// contract requires the figure on the request; the server still charges
  /// what the invoice says, and rejects a stale figure rather than trusting
  /// it (section 65).
  ///
  /// The idempotency key is scoped to the invoice and persisted, so a retry
  /// after a timeout reuses it and cannot produce a second charge (section 66).
  ///
  /// The returned intent is *not* a result. It says a payment now exists and is
  /// in flight; the outcome comes from polling.
  Future<Result<PaymentIntent>> initiate({
    required String invoiceId,
    required PaymentMethod method,
    required Money amount,
    String? phoneNumber,
  }) {
    return _ref
        .read(idempotencyKeysProvider)
        .forIntent(IdempotencyKeys.invoicePaymentIntent(invoiceId))
        .then(
          (idempotencyKey) => _ref
              .read(paymentRepositoryProvider)
              .initiatePayment(
                invoiceId: invoiceId,
                method: method,
                amount: amount,
                idempotencyKey: idempotencyKey,
                phoneNumber: phoneNumber,
              ),
        );

    // The key is deliberately not released here. The payment is still in
    // flight, and if the tenant backs out and tries again before it settles,
    // that is the same intent and must not become a second charge. It is
    // released by [completeIntent] once the payment reaches a terminal state.
  }

  /// Called once a payment has settled, whichever way it went. A failed payment
  /// can legitimately be retried, and that retry is a new intent deserving a
  /// new key.
  Future<void> completeIntent(String invoiceId) => _ref
      .read(idempotencyKeysProvider)
      .release(IdempotencyKeys.invoicePaymentIntent(invoiceId));

  /// Asks the server to prompt [phoneNumber] for [invoice]'s balance.
  ///
  /// The published route's counterpart to [initiate]: it answers with a
  /// message rather than a payment to poll, so the outcome is read off the
  /// invoice by [confirmInvoicePaid]. The same idempotency key as [initiate],
  /// for the same reason — a retry over a bad connection is the same intent.
  Future<Result<PaymentPrompt>> requestMpesaPrompt(
    Invoice invoice, {
    required String phoneNumber,
  }) async {
    final idempotencyKey = await _ref
        .read(idempotencyKeysProvider)
        .forIntent(IdempotencyKeys.invoicePaymentIntent(invoice.id));

    return _ref
        .read(paymentRepositoryProvider)
        .requestMpesaPrompt(
          invoiceId: invoice.id,
          phoneNumber: phoneNumber,
          // The balance as the server last stated it, off the invoice as
          // displayed. Nothing is added to it here.
          amount: invoice.amountDue,
          idempotencyKey: idempotencyKey,
        );
  }

  /// The tenant wants the prompt sent again: a new intent, a new key.
  Future<void> restartPrompt(String invoiceId) => completeIntent(invoiceId);

  /// Re-reads the invoice and answers whether the server now shows it paid.
  ///
  /// A `false` means "not yet": the prompt may still be open on the handset,
  /// or the provider's callback may not have landed. It never means failed —
  /// the app cannot know that, and does not claim to (section 39).
  Future<Result<bool>> confirmInvoicePaid(String invoiceId) async {
    final result = await _ref
        .read(invoiceRepositoryProvider)
        .getInvoice(invoiceId);

    if (result case Ok(:final value) when !value.isPayable) {
      await completeIntent(invoiceId);
      // What a settled invoice cascades into — an activated booking, a
      // satisfied deposit, a changed balance — is re-read rather than
      // modelled.
      _invalidateAfterSettlement(_ref, invoiceId);
      return const Ok(true);
    }

    return result.map((invoice) => !invoice.isPayable);
  }
}

/// Everything that shows an invoice's balance, re-read after it moved.
void _invalidateAfterSettlement(Ref ref, String invoiceId) {
  ref.invalidate(invoiceListProvider);
  ref.invalidate(invoiceDetailProvider(invoiceId));
  ref.invalidate(paymentHistoryProvider);
  ref.invalidate(bookingListProvider);
  ref.invalidate(leaseListProvider);
  ref.read(dashboardControllerProvider.notifier).refresh();
}

/// A snapshot of a payment while the client is watching it.
class PaymentWatch {
  const PaymentWatch({
    required this.payment,
    required this.isPolling,
    required this.hasTimedOut,
  });

  final Payment payment;

  /// True while the client is still asking the server.
  final bool isPolling;

  /// True once polling gave up. The payment itself is unaffected — it may still
  /// complete, and the tenant is notified when it does.
  final bool hasTimedOut;

  bool get isSettled => payment.status.isTerminal;
  bool get succeeded => payment.status == PaymentStatus.success;
}

/// Watches one payment until the **server** says it has settled.
///
/// This is the client half of section 39's "never trust only the mobile
/// application's payment result". The app cannot know whether the tenant
/// entered their PIN, whether the provider accepted it, or whether the callback
/// reconciled. So it asks, repeatedly, and reports only what it is told — there
/// is no path through this file that marks a payment successful locally.
///
/// Expressed as a stream because that is exactly what it is: a sequence of
/// observations that ends when the payment reaches a terminal state or when
/// polling times out. Re-reading the provider restarts the sequence, which is
/// what the manual "check again" button does.
final paymentStatusProvider = StreamProvider.family<PaymentWatch, String>((
  ref,
  paymentId,
) async* {
  final repository = ref.watch(paymentRepositoryProvider);
  final startedAt = DateTime.now();

  var disposed = false;
  ref.onDispose(() => disposed = true);

  while (!disposed) {
    final result = await repository.getPayment(paymentId);
    if (disposed) return;

    final payment = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

    final timedOut =
        DateTime.now().difference(startedAt) > AppConfig.paymentPollTimeout;

    if (payment.status.isTerminal) {
      yield PaymentWatch(
        payment: payment,
        isPolling: false,
        hasTimedOut: false,
      );
      await _onSettled(ref, payment);
      return;
    }

    yield PaymentWatch(
      payment: payment,
      isPolling: !timedOut,
      hasTimedOut: timedOut,
    );

    if (timedOut) return;

    await Future<void>.delayed(AppConfig.paymentPollInterval);
  }
});

/// Everything downstream of a payment settling.
///
/// A settled payment cascades a long way server-side: the invoice is allocated
/// against, a booking fee activates a booking and starts its expiry clock, a
/// deposit satisfies a requirement and generates the lease. Rather than model
/// any of that on the client, every affected provider is re-read.
Future<void> _onSettled(Ref ref, Payment payment) async {
  if (payment.invoiceId != null) {
    await ref.read(paymentActionsProvider).completeIntent(payment.invoiceId!);
  }

  if (payment.status != PaymentStatus.success) return;

  if (payment.invoiceId != null) {
    _invalidateAfterSettlement(ref, payment.invoiceId!);
  } else {
    ref.invalidate(invoiceListProvider);
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(bookingListProvider);
    ref.invalidate(leaseListProvider);
    ref.read(dashboardControllerProvider.notifier).refresh();
  }
}

/// The receipt for a settled payment (section 40).
final receiptForPaymentProvider = FutureProvider.family<Receipt, String>((
  ref,
  paymentId,
) async {
  final result = await ref
      .watch(receiptRepositoryProvider)
      .getReceiptForPayment(paymentId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final receiptProvider = FutureProvider.family<Receipt, String>((
  ref,
  receiptId,
) async {
  final result = await ref
      .watch(receiptRepositoryProvider)
      .getReceipt(receiptId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});
