import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/treasury.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';
import 'demo_fixtures.dart';

/// Repositories that answer from [DemoFixtures] instead of the API.
///
/// Wired in only when `AppConfig.demoData` is set — see `providers.dart`.
/// Each one covers exactly the reads and writes its screens make, keeps any
/// write in memory so the screen reacts the way it would to a real server,
/// and takes a beat before answering so the skeletons and pull-to-refresh
/// are seen rather than skipped.

const _latency = Duration(milliseconds: 350);

Future<Result<T>> _answer<T>(T value) =>
    Future.delayed(_latency, () => Ok<T>(value));

/// Leases, the agreement text, and signing.
///
/// Fully fixture-backed: the contract publishes no lease route at all.
class DemoLeaseRepository implements LeaseRepository {
  DemoLeaseRepository(this._fixtures);

  final DemoFixtures _fixtures;

  @override
  Future<Result<Page<Lease>>> listLeases({LeaseStatus? status, int page = 1}) =>
      _answer(
        Page.single(
          _fixtures.leases.values
              .where((lease) => status == null || lease.status == status)
              .toList(growable: false),
        ),
      );

  @override
  Future<Result<Lease>> getLease(String leaseId) {
    final lease = _fixtures.leases[leaseId];
    return lease == null
        ? _notFound('We could not find that lease.')
        : _answer(lease);
  }

  @override
  Future<Result<LeaseAgreement>> getAgreement(String leaseId) {
    final agreement = _fixtures.agreements[leaseId];
    return agreement == null
        ? _notFound('The agreement for that lease is not available.')
        : _answer(agreement);
  }

  /// Moves the lease to SIGNED and no further, the way the server would: the
  /// deposit, the documents and the manager's approval are still theirs to
  /// confirm (section 30).
  @override
  Future<Result<Lease>> signLease({
    required String leaseId,
    required SignatureType signatureType,
    required List<int> signatureData,
    required String documentHash,
    required String idempotencyKey,
  }) {
    final lease = _fixtures.leases[leaseId];
    if (lease == null) return _notFound('We could not find that lease.');
    if (documentHash != _fixtures.agreements[leaseId]?.documentHash) {
      return Future.value(
        const Err(
          ConflictFailure(
            'The agreement changed while you were reading it. Please review '
            'the latest version and sign again.',
          ),
        ),
      );
    }
    if (!lease.status.needsTenantSignature) return _answer(lease);

    final signedAt = DateTime.now();
    final signed = Lease(
      id: lease.id,
      leaseNumber: lease.leaseNumber,
      propertyId: lease.propertyId,
      unitId: lease.unitId,
      tenantId: lease.tenantId,
      bookingId: lease.bookingId,
      startDate: lease.startDate,
      endDate: lease.endDate,
      monthlyRent: lease.monthlyRent,
      depositAmount: lease.depositAmount,
      billingFrequency: lease.billingFrequency,
      paymentDueDay: lease.paymentDueDay,
      status: LeaseStatus.signed,
      createdAt: lease.createdAt,
      signedAt: signedAt,
      propertyName: lease.propertyName,
      unitNumber: lease.unitNumber,
      agreementDocumentId: lease.agreementDocumentId,
      signedAgreementDocumentId: '${lease.agreementDocumentId}-signed',
      terms: lease.terms,
      activationConditions: [
        for (final condition in lease.activationConditions)
          condition.id.endsWith('signed')
              ? LeaseActivationCondition(
                  id: condition.id,
                  label: condition.label,
                  detail: condition.detail,
                  isMet: true,
                  isMandatory: condition.isMandatory,
                )
              : condition,
      ],
      signatures: [
        ...lease.signatures,
        LeaseSignature(
          id: 'demo-sig-${lease.id}-${signedAt.millisecondsSinceEpoch}',
          leaseId: lease.id,
          signatureType: signatureType,
          signedAt: signedAt,
          documentHash: documentHash,
        ),
      ],
    );
    _fixtures.leases[leaseId] = signed;
    return _answer(signed);
  }
}

/// The tenant's statement, and the two things that can be done to a line of
/// it from inside the app.
class DemoInvoiceRepository implements InvoiceRepository {
  DemoInvoiceRepository(this._fixtures);

  final DemoFixtures _fixtures;

  @override
  Future<Result<Page<Invoice>>> listInvoices({
    InvoiceStatus? status,
    String? leaseId,
    int page = 1,
  }) => _answer(
    Page.single(
      _fixtures.invoices.values
          .where(
            (invoice) =>
                (status == null || invoice.status == status) &&
                (leaseId == null || invoice.leaseId == leaseId),
          )
          .toList(growable: false),
    ),
  );

  /// There is one tenant in the fixtures, so every tenant's statement is
  /// theirs. Enough for the owner's tenant-invoices screen to have rows on it.
  @override
  Future<Result<Page<Invoice>>> listInvoicesForTenant(String tenantId) =>
      listInvoices();

  @override
  Future<Result<Invoice>> getInvoice(String invoiceId) {
    final invoice = _fixtures.invoices[invoiceId];
    return invoice == null
        ? _notFound('We could not find that invoice.')
        : _answer(invoice);
  }

  @override
  Future<Result<void>> deferInvoice({
    required String invoiceId,
    required String reason,
  }) {
    final invoice = _fixtures.invoices[invoiceId];
    if (invoice == null) return _notFound('We could not find that invoice.');
    if (!invoice.canRequestDeferral) {
      return Future.value(
        const Err(ConflictFailure('That invoice cannot be deferred.')),
      );
    }
    _fixtures.invoices[invoiceId] = _copy(
      invoice,
      isDeferred: true,
      deferReason: reason.trim(),
    );
    return _answer(null);
  }

  @override
  Future<Result<void>> settleInvoice(String invoiceId) {
    final invoice = _fixtures.invoices[invoiceId];
    if (invoice == null) return _notFound('We could not find that invoice.');
    _fixtures.invoices[invoiceId] = _copy(
      invoice,
      status: InvoiceStatus.paid,
      amountPaid: invoice.total,
      amountDue: Money.zero(invoice.currency),
      settledOn: DateTime.now(),
    );
    return _answer(null);
  }

  static Invoice _copy(
    Invoice invoice, {
    InvoiceStatus? status,
    Money? amountPaid,
    Money? amountDue,
    bool? isDeferred,
    String? deferReason,
    DateTime? settledOn,
  }) => Invoice(
    id: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    tenantId: invoice.tenantId,
    leaseId: invoice.leaseId,
    propertyId: invoice.propertyId,
    unitId: invoice.unitId,
    propertyName: invoice.propertyName,
    unitNumber: invoice.unitNumber,
    tenantName: invoice.tenantName,
    status: status ?? invoice.status,
    invoiceDate: invoice.invoiceDate,
    dueDate: invoice.dueDate,
    billingPeriodStart: invoice.billingPeriodStart,
    billingPeriodEnd: invoice.billingPeriodEnd,
    subtotal: invoice.subtotal,
    tax: invoice.tax,
    discount: invoice.discount,
    total: invoice.total,
    amountPaid: amountPaid ?? invoice.amountPaid,
    amountDue: amountDue ?? invoice.amountDue,
    currency: invoice.currency,
    lines: invoice.lines,
    documentId: invoice.documentId,
    isDeferred: isDeferred ?? invoice.isDeferred,
    deferReason: deferReason ?? invoice.deferReason,
    settledOn: settledOn ?? invoice.settledOn,
    paymentReceipt: invoice.paymentReceipt,
    payments: invoice.payments,
  );
}

/// The owner's ledger from the fixtures; everything else from the API.
///
/// A decorator rather than a replacement, so the Money screen fills in
/// without taking the property, unit and repricing writes off the server.
class DemoOwnerRepository implements OwnerRepository {
  DemoOwnerRepository(this._fixtures, this._inner);

  final DemoFixtures _fixtures;
  final OwnerRepository _inner;

  @override
  Future<Result<OwnerLedger>> getLedger() => _answer(_fixtures.ledger);

  @override
  Future<Result<CollectionSeries>> getCollections(CollectionWindow window) =>
      _answer(_fixtures.collectionsOver(window));

  /// The till and the statement, cut to one property when asked — the same
  /// two lists the live server serves, from the fixtures' side.
  @override
  Future<Result<OwnerReport>> getReport({String? propertyId}) => _answer(
    OwnerReport(
      propertyId: propertyId,
      received: _fixtures.mpesa
          .where((row) => propertyId == null || row.propertyId == propertyId)
          .toList(growable: false),
      invoices: _fixtures.invoices.values
          .where(
            (invoice) => propertyId == null || invoice.propertyId == propertyId,
          )
          .toList(growable: false),
      banked: _fixtures.bankPayments
          .where((row) => propertyId == null || row.propertyId == propertyId)
          .toList(growable: false),
    ),
  );

  @override
  Future<Result<PropertyOwner>> getOwner() => _inner.getOwner();

  @override
  Future<Result<OwnerPortfolio>> getPortfolio() => _inner.getPortfolio();

  @override
  Future<Result<PropertyPerformance>> getPropertyPerformance(
    String propertyId,
  ) => _inner.getPropertyPerformance(propertyId);

  @override
  Future<Result<RepricingImpact>> getRepricingImpact(String propertyId) =>
      _inner.getRepricingImpact(propertyId);

  @override
  Future<Result<List<RentRollEntry>>> getRentRoll(String propertyId) =>
      _inner.getRentRoll(propertyId);

  @override
  Future<Result<List<OwnerTenancy>>> getTenancies({String? propertyId}) =>
      _inner.getTenancies(propertyId: propertyId);

  @override
  Future<Result<OwnerTenancy>> getTenancy(String leaseId) =>
      _inner.getTenancy(leaseId);

  @override
  Future<Result<Property>> createProperty({
    required PropertyDraft draft,
    required String idempotencyKey,
  }) => _inner.createProperty(draft: draft, idempotencyKey: idempotencyKey);

  @override
  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  }) => _inner.createUnits(
    propertyId: propertyId,
    draft: draft,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<Property>> setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  }) => _inner.setRatePerSqm(
    propertyId: propertyId,
    rate: rate,
    repriceExistingUnits: repriceExistingUnits,
  );

  @override
  Future<Result<Unit>> setUnitRent({required String unitId, Money? override}) =>
      _inner.setUnitRent(unitId: unitId, override: override);
}

Future<Result<T>> _notFound<T>(String message) =>
    Future.value(Err<T>(NotFoundFailure(message)));

/// The till and the bank, from the fixtures.
///
/// Fully fixture-backed so the two screens stay consistent with the ledger
/// they sit under. The writes are kept in memory: correcting an orphan's
/// account number reconciles it, and a bank payment recorded by hand shows up
/// under "Awaiting review" the way it would from the server.
class DemoTreasuryRepository implements TreasuryRepository {
  DemoTreasuryRepository(this._fixtures);

  final DemoFixtures _fixtures;

  @override
  Future<Result<List<MpesaTransaction>>> listMpesaTransactions({
    String? propertyId,
  }) => _answer(
    _fixtures.mpesa
        .where((row) => propertyId == null || row.propertyId == propertyId)
        .toList(growable: false),
  );

  @override
  Future<Result<List<MpesaTransaction>>> findMpesaTransactions(
    String transactionId,
  ) {
    final needle = transactionId.trim().toUpperCase();
    return _answer(
      _fixtures.mpesa
          .where(
            (row) =>
                row.transactionId.toUpperCase().contains(needle) ||
                (row.payerName?.toUpperCase().contains(needle) ?? false),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<void>> setMpesaAccountNumber({
    required String transactionId,
    required String accountNumber,
  }) {
    final index = _fixtures.mpesa.indexWhere((row) => row.id == transactionId);
    if (index < 0) return _notFound('We could not find that transaction.');
    final row = _fixtures.mpesa[index];
    _fixtures.mpesa[index] = MpesaTransaction(
      id: row.id,
      transactionId: row.transactionId,
      amount: row.amount,
      // A corrected account is what lets the platform place the money.
      processed: true,
      transactionType: row.transactionType,
      transactedAt: row.transactedAt,
      businessShortCode: row.businessShortCode,
      accountNumber: accountNumber.trim(),
      invoiceNumber: row.invoiceNumber,
      payerPhone: row.payerPhone,
      payerName: row.payerName,
      propertyId: row.propertyId,
      propertyName: row.propertyName,
      blockId: row.blockId,
      unitNumber: row.unitNumber,
      thirdPartyTransactionId: row.thirdPartyTransactionId,
      organisationBalance: row.organisationBalance,
      isReissued: row.isReissued,
      isEdited: true,
      isSplit: row.isSplit,
      createdAt: row.createdAt,
    );
    return _answer(null);
  }

  @override
  Future<Result<List<BankPayment>>> listBankPayments() =>
      _answer(List.unmodifiable(_fixtures.bankPayments));

  @override
  Future<Result<void>> recordBankPayment({
    required BankPaymentDraft draft,
    required String idempotencyKey,
  }) {
    // Idempotent on the reference: the same transfer keyed twice is one
    // payment (section 66).
    if (_fixtures.bankPayments.any(
      (row) => row.paymentReference == draft.paymentReference.trim(),
    )) {
      return _answer(null);
    }
    _fixtures.bankPayments.insert(
      0,
      BankPayment(
        id: 'demo-bank-${DateTime.now().millisecondsSinceEpoch}',
        amount: draft.amount,
        paidAt: draft.paidAt,
        paymentMethod: draft.paymentMethod,
        paymentReference: draft.paymentReference.trim(),
        invoiceId: draft.invoiceId,
        tenantId: draft.tenantId,
        purpose: draft.purpose,
        paidByName: draft.paidByName,
        bankAccountNumber: draft.bankAccountNumber,
        bankName: draft.bankName,
        branchName: draft.branchName,
        proofOfPaymentUrl: draft.proofOfPaymentUrl,
        status: 'Pending review',
        createdAt: DateTime.now(),
      ),
    );
    return _answer(null);
  }

  @override
  Future<Result<void>> updateBankPayment(BankPayment payment) {
    final index = _fixtures.bankPayments.indexWhere(
      (row) => row.id == payment.id,
    );
    if (index < 0) return _notFound('We could not find that payment.');
    _fixtures.bankPayments[index] = payment;
    return _answer(null);
  }

  @override
  Future<Result<void>> deleteBankPayment(String bankPaymentId) {
    final removed = _fixtures.bankPayments.length;
    _fixtures.bankPayments.removeWhere((row) => row.id == bankPaymentId);
    return removed == _fixtures.bankPayments.length
        ? _notFound('We could not find that payment.')
        : _answer(null);
  }
}
