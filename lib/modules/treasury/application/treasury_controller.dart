import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../domain/entities/treasury.dart';
import '../../../services/providers.dart';
import '../../invoices/application/invoice_controller.dart';

/// Every M-Pesa transaction the till received.
final mpesaTransactionsProvider = FutureProvider<List<MpesaTransaction>>((
  ref,
) async {
  final result = await ref
      .read(treasuryRepositoryProvider)
      .listMpesaTransactions();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// What the lookup field currently holds.
///
/// Empty means the list is showing everything, which is the state the screen
/// opens in — a search that starts by hiding all the data is a search that
/// makes you type before you can look.
final mpesaSearchProvider = NotifierProvider<MpesaSearchController, String>(
  MpesaSearchController.new,
);

class MpesaSearchController extends Notifier<String> {
  @override
  String build() => '';

  void search(String query) => state = query;

  void clear() => state = '';
}

/// The result of looking a transaction up by its reference.
///
/// Null when nothing has been searched for, which is different from an empty
/// list: one means "not asked", the other means "asked, and there is nothing".
final mpesaSearchResultProvider = FutureProvider<List<MpesaTransaction>?>((
  ref,
) async {
  final query = ref.watch(mpesaSearchProvider).trim();
  if (query.isEmpty) return null;

  final result = await ref
      .read(treasuryRepositoryProvider)
      .findMpesaTransactions(query);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final bankPaymentsProvider = FutureProvider<List<BankPayment>>((ref) async {
  final result = await ref.read(treasuryRepositoryProvider).listBankPayments();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

final treasuryActionsProvider = Provider<TreasuryActions>(
  (ref) => TreasuryActions(ref),
);

class TreasuryActions {
  TreasuryActions(this._ref);

  final Ref _ref;

  /// Credits an orphaned payment to the right account.
  Future<Result<void>> setAccountNumber({
    required String transactionId,
    required String accountNumber,
  }) async {
    final result = await _ref
        .read(treasuryRepositoryProvider)
        .setMpesaAccountNumber(
          transactionId: transactionId,
          accountNumber: accountNumber,
        );
    if (result.isOk) {
      _ref.invalidate(mpesaTransactionsProvider);
      _ref.invalidate(mpesaSearchResultProvider);
      // Reconciling a payment can settle an invoice, so what the tenant owes
      // is no longer what this app last showed them.
      _ref.invalidate(invoiceListProvider);
    }
    return result;
  }

  /// Records a payment made outside the app.
  ///
  /// Idempotent on the bank reference, which is the natural intent here: the
  /// same transfer keyed twice because the first attempt timed out is one
  /// payment, not two (section 66).
  Future<Result<void>> recordBankPayment(BankPaymentDraft draft) async {
    final keys = _ref.read(idempotencyKeysProvider);
    final intent = IdempotencyKeys.bankPaymentIntent(draft.paymentReference);
    final idempotencyKey = await keys.forIntent(intent);

    final result = await _ref
        .read(treasuryRepositoryProvider)
        .recordBankPayment(draft: draft, idempotencyKey: idempotencyKey);

    if (result.isOk) {
      await keys.release(intent);
      _ref.invalidate(bankPaymentsProvider);
      _ref.invalidate(invoiceListProvider);
      if (draft.invoiceId != null) {
        _ref.invalidate(invoiceDetailProvider(draft.invoiceId!));
      }
    }
    return result;
  }

  Future<Result<void>> updateBankPayment(BankPayment payment) async {
    final result = await _ref
        .read(treasuryRepositoryProvider)
        .updateBankPayment(payment);
    if (result.isOk) _ref.invalidate(bankPaymentsProvider);
    return result;
  }

  Future<Result<void>> deleteBankPayment(String bankPaymentId) async {
    final result = await _ref
        .read(treasuryRepositoryProvider)
        .deleteBankPayment(bankPaymentId);
    if (result.isOk) _ref.invalidate(bankPaymentsProvider);
    return result;
  }
}
