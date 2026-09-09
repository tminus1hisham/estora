/// Money as the back office sees it.
///
/// The tenant-facing model in `billing.dart` describes a payment as the person
/// paying experiences it: an intent, a status to poll, a receipt. These are the
/// same money from the other side of the counter — the raw M-Pesa callback the
/// till received, and the bank transfer somebody keyed in by hand — and the
/// contract exposes both as first-class records.
///
/// Neither type computes anything. An amount that arrived as a string stays a
/// string until it is parsed once, here, into [Money]; nothing is summed,
/// netted or converted on the way to a screen.
library;

import '../../core/utils/money.dart';

/// One M-Pesa transaction as the gateway reported it.
///
/// The field names are the gateway's, not the app's — `transID`, `msisdn`,
/// `billRefNumber` — and they are kept recognisable here because reconciling a
/// disputed payment means reading this record beside the till statement, and a
/// helpfully renamed field is a field nobody can find.
class MpesaTransaction {
  const MpesaTransaction({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.processed,
    this.transactionType,
    this.transactedAt,
    this.businessShortCode,
    this.accountNumber,
    this.invoiceNumber,
    this.payerPhone,
    this.payerName,
    this.propertyId,
    this.blockId,
    this.thirdPartyTransactionId,
    this.organisationBalance,
    this.isReissued = false,
    this.isEdited = false,
    this.isSplit = false,
    this.createdAt,
  });

  final String id;

  /// The gateway's own reference — the code the payer sees on their handset.
  final String transactionId;

  final Money amount;

  /// Whether the platform has reconciled this against an invoice yet. An
  /// unprocessed transaction is money that arrived without anywhere to go,
  /// which is exactly what the account-number correction exists to fix.
  final bool processed;

  final String? transactionType;
  final DateTime? transactedAt;
  final String? businessShortCode;

  /// What the payer typed as the account. A wrong one here is the single most
  /// common reason a payment does not land against the right invoice.
  final String? accountNumber;

  final String? invoiceNumber;
  final String? payerPhone;
  final String? payerName;
  final String? propertyId;
  final String? blockId;
  final String? thirdPartyTransactionId;
  final String? organisationBalance;

  final bool isReissued;
  final bool isEdited;
  final bool isSplit;
  final DateTime? createdAt;

  /// Masks all but the last three digits of the payer's number.
  ///
  /// A till list is read in public — over a counter, on a shared screen — and
  /// the last three digits are enough to match a payer to a receipt without
  /// putting a full phone number on display.
  String? get maskedPayerPhone {
    final phone = payerPhone;
    if (phone == null || phone.isEmpty) return null;
    if (phone.length <= 3) return '•' * phone.length;
    return '${'•' * (phone.length - 3)}${phone.substring(phone.length - 3)}';
  }

  bool get hasAccountNumber =>
      accountNumber != null && accountNumber!.trim().isNotEmpty;
}

/// A payment recorded by hand — a bank transfer, a cheque, cash over the
/// counter — rather than one that arrived through a gateway.
class BankPayment {
  const BankPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.paymentMethod,
    required this.paymentReference,
    this.invoiceId,
    this.tenantId,
    this.propertyId,
    this.blockId,
    this.purpose,
    this.paidByName,
    this.bankAccountNumber,
    this.bankName,
    this.branchName,
    this.status,
    this.proofOfPaymentUrl,
    this.isProcessed = false,
    this.isSplit = false,
    this.isReissued = false,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final Money amount;
  final DateTime paidAt;

  /// Free text on the wire — the contract does not constrain it to the app's
  /// [PaymentMethod] enum, and a back office that types "RTGS" means it.
  final String paymentMethod;

  /// The bank's reference. This is what reconciliation matches on, so it is
  /// required rather than optional.
  final String paymentReference;

  final String? invoiceId;
  final String? tenantId;
  final String? propertyId;
  final String? blockId;
  final String? purpose;
  final String? paidByName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? branchName;
  final String? status;

  /// Where the deposit slip or transfer confirmation lives.
  final String? proofOfPaymentUrl;

  final bool isProcessed;
  final bool isSplit;
  final bool isReissued;
  final String? createdByName;
  final DateTime? createdAt;

  bool get hasProof =>
      proofOfPaymentUrl != null && proofOfPaymentUrl!.trim().isNotEmpty;

  String get bankLabel => [
    bankName,
    branchName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
}

/// What a tenant or a back-office user submits to record a manual payment.
class BankPaymentDraft {
  const BankPaymentDraft({
    required this.amount,
    required this.paidAt,
    required this.paymentMethod,
    required this.paymentReference,
    this.invoiceId,
    this.tenantId,
    this.purpose,
    this.paidByName,
    this.bankAccountNumber,
    this.bankName,
    this.branchName,
    this.proofOfPaymentUrl,
  });

  final Money amount;
  final DateTime paidAt;
  final String paymentMethod;
  final String paymentReference;
  final String? invoiceId;
  final String? tenantId;
  final String? purpose;
  final String? paidByName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? branchName;
  final String? proofOfPaymentUrl;

  /// The methods the contract sees against manual payments. Free text on the
  /// wire, but offering a list beats asking somebody to spell "RTGS" the same
  /// way twice.
  static const List<String> methods = [
    'Bank transfer',
    'RTGS',
    'EFT',
    'Cheque',
    'Cash',
    'Card',
  ];
}
