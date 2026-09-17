import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

/// Section 32. An invoice raised against a lease.
///
/// Every monetary field here is server-supplied and rendered verbatim. Section
/// 84 rule 4 requires historical invoices to keep their original pricing, and
/// rule 7 puts totalling on the server — so this class has no arithmetic that
/// derives [total] from [subtotal] and [tax], or [amountDue] from [total] and
/// [amountPaid]. If the server says the total is 177,000, that is the total.
class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.tenantId,
    required this.status,
    required this.invoiceDate,
    required this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.amountDue,
    required this.currency,
    required this.lines,
    this.leaseId,
    this.propertyId,
    this.unitId,
    this.propertyName,
    this.unitNumber,
    this.billingPeriodStart,
    this.billingPeriodEnd,
    this.documentId,
    this.isDeferred = false,
    this.deferReason,
    this.settledOn,
    this.paymentReceipt,
  });

  final String id;
  final String invoiceNumber;

  final String tenantId;
  final String? leaseId;
  final String? propertyId;
  final String? unitId;

  final DateTime invoiceDate;
  final DateTime dueDate;

  /// Section 35. Every invoice carries the period it bills for; this is what
  /// makes proration, termination settlement and disputes tractable.
  final DateTime? billingPeriodStart;
  final DateTime? billingPeriodEnd;

  final Money subtotal;
  final Money tax;
  final Money discount;
  final Money total;
  final Money amountPaid;
  final Money amountDue;

  final String currency;
  final InvoiceStatus status;

  /// Section 33 forbids storing only a total.
  final List<InvoiceLine> lines;

  final String? propertyName;
  final String? unitNumber;
  final String? documentId;

  /// Whether payment has been formally postponed.
  ///
  /// A deferred invoice is still owed — deferral moves the conversation, not
  /// the debt — so nothing here removes it from the balance. What it changes
  /// is the pressure: an invoice with an agreed postponement should not be
  /// shouted at the tenant as overdue.
  final bool isDeferred;

  /// Why, in the words that were agreed. Shown to both sides.
  final String? deferReason;

  /// When the landlord wrote the invoice off against something other than a
  /// payment through this app — a settlement, a credit, an offset.
  final DateTime? settledOn;

  /// The receipt reference the server attached once money landed.
  final String? paymentReceipt;

  bool get isOverdue => status == InvoiceStatus.overdue;

  bool get isPayable => status.isPayable && amountDue.isPositive;

  /// Whether a tenant may ask for this one to be deferred.
  ///
  /// Only something still owed and not already postponed. Asking twice is not
  /// a second request, it is the same conversation.
  bool get canRequestDeferral => status.isPayable && !isDeferred;

  int get daysUntilDue => DateTime(dueDate.year, dueDate.month, dueDate.day)
      .difference(
        DateTime.now().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        ),
      )
      .inDays;

  bool get isDueSoon =>
      status.isPayable && daysUntilDue >= 0 && daysUntilDue <= 7;

  bool get hasBillingPeriod =>
      billingPeriodStart != null && billingPeriodEnd != null;
}

/// Section 33.
class InvoiceLine {
  const InvoiceLine({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.lineType,
    this.taxRate,
    this.taxAmount,
    this.referenceId,
  });

  final String id;
  final String invoiceId;
  final String description;
  final num quantity;
  final Money unitPrice;

  /// Server-computed line amount. Not `unitPrice * quantity` — a line may carry
  /// a negotiated or prorated figure (section 56).
  final Money amount;

  final double? taxRate;
  final Money? taxAmount;
  final InvoiceLineType lineType;

  /// Links back to what generated the line, e.g. a meter reading or a booking.
  final String? referenceId;

  /// `1 × KES 150,000` — shown only when the quantity is meaningful.
  bool get showsQuantity => quantity != 1;
}

/// Section 36.
class Payment {
  const Payment({
    required this.id,
    required this.paymentReference,
    required this.tenantId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.invoiceId,
    this.leaseId,
    this.propertyId,
    this.provider,
    this.providerTransactionId,
    this.paidAt,
    this.failureReason,
    this.receiptId,
    this.invoiceNumber,
    this.description,
    this.allocations = const <PaymentAllocation>[],
  });

  final String id;
  final String paymentReference;

  final String tenantId;
  final String? invoiceId;
  final String? leaseId;
  final String? propertyId;

  final Money amount;
  final String currency;

  final PaymentMethod paymentMethod;

  /// e.g. `MPESA`, `STRIPE` (section 38).
  final String? provider;

  /// The provider's own reference, e.g. an M-Pesa receipt number. Section 85
  /// requires this to be answerable in a dispute.
  final String? providerTransactionId;

  final PaymentStatus status;
  final DateTime? paidAt;
  final DateTime createdAt;

  final String? failureReason;
  final String? receiptId;
  final String? invoiceNumber;
  final String? description;

  /// Section 37. One payment may settle several invoices.
  final List<PaymentAllocation> allocations;

  bool get isTerminal => status.isTerminal;
  bool get isInFlight => status.isInFlight;
  bool get hasReceipt => receiptId != null && status == PaymentStatus.success;
}

/// Section 37.
class PaymentAllocation {
  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.amount,
    required this.allocatedAt,
    this.invoiceNumber,
  });

  final String id;
  final String paymentId;
  final String invoiceId;
  final String? invoiceNumber;
  final Money amount;
  final DateTime allocatedAt;
}

/// Section 40. Issued for every successful payment.
class Receipt {
  const Receipt({
    required this.id,
    required this.receiptNumber,
    required this.paymentId,
    required this.tenantId,
    required this.amount,
    required this.currency,
    required this.issuedAt,
    this.propertyId,
    this.propertyName,
    this.documentId,
    this.paymentMethod,
    this.paymentReference,
  });

  final String id;
  final String receiptNumber;
  final String paymentId;
  final String tenantId;
  final String? propertyId;
  final String? propertyName;
  final Money amount;
  final String currency;
  final DateTime issuedAt;
  final PaymentMethod? paymentMethod;
  final String? paymentReference;

  /// The downloadable PDF (section 40, stored per section 75).
  final String? documentId;
}

/// The result of asking the server to start a payment.
///
/// For M-Pesa STK Push (section 39) the tenant now has a prompt on their
/// handset. The app's job from here is to poll [Payment] until the *server*
/// reports a terminal status — it must never conclude success on its own.
class PaymentIntent {
  const PaymentIntent({
    required this.paymentId,
    required this.status,
    required this.amount,
    this.providerReference,
    this.instruction,
    this.redirectUrl,
  });

  final String paymentId;
  final PaymentStatus status;
  final Money amount;

  /// e.g. the M-Pesa CheckoutRequestID.
  final String? providerReference;

  /// What to tell the tenant, e.g. "Enter your M-Pesa PIN on your phone".
  /// Server-supplied so the copy can change per provider without an app
  /// release.
  final String? instruction;

  /// For card or bank providers that need a hosted page.
  final String? redirectUrl;
}

/// An M-Pesa prompt the server has just sent to a handset.
///
/// This is all the contract's two STK routes give back: they answer with a
/// message, not a payment record. There is nothing here to poll. What the
/// tenant does next happens on their phone, and whether it worked is read off
/// the invoice or booking the prompt was raised against — which is also the
/// only place the app should ever read it from (section 39).
class PaymentPrompt {
  const PaymentPrompt({
    required this.phoneNumber,
    required this.amount,
    this.message,
  });

  /// The handset the prompt went to, in the `2547…` form it was sent as.
  final String phoneNumber;

  /// What the prompt asks for: the server's figure, echoed back.
  final Money amount;

  /// The server's own account of what it did, when it gave one.
  final String? message;
}
