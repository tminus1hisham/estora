import 'dart:async';

import '../../core/config/app_config.dart';
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/access.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/treasury.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';
import 'mock_back_office.dart';
import 'mock_records.dart';
import 'mock_server.dart';

/// Thin adapters from the repository interfaces onto [MockServer].
///
/// There is deliberately almost no logic here. Anything that decides an amount,
/// a status or a reference belongs on the server side of the boundary, so these
/// classes only translate calls, add simulated latency, and turn the mock's
/// exceptions into [Failure] values.
mixin _MockLatency {
  /// Every call goes through here so loading and error states are actually
  /// exercised during development rather than only appearing in production.
  Future<Result<T>> guard<T>(T Function() action) async {
    await Future<void>.delayed(AppConfig.mockLatency);
    try {
      return Ok(action());
    } on MockConflict catch (e) {
      return Err(ConflictFailure(e.message));
    } on MockNotFound catch (e) {
      return Err(NotFoundFailure(e.message));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }
}

/// Pages an in-memory list the way a paginated endpoint would (section 65).
Page<T> _paginate<T>(List<T> items, int page, {int pageSize = 20}) {
  final start = (page - 1) * pageSize;
  if (start >= items.length) {
    return Page(
      items: const [],
      page: page,
      pageSize: pageSize,
      total: items.length,
    );
  }
  final end = (start + pageSize).clamp(0, items.length);
  return Page(
    items: items.sublist(start, end),
    page: page,
    pageSize: pageSize,
    total: items.length,
  );
}

// ---------------------------------------------------------------------------

class MockAuthRepository with _MockLatency implements AuthRepository {
  MockAuthRepository(this._server);

  final MockServer _server;

  /// Set once a session exists, so [restoreSession] can answer without the
  /// caller having to log in again within a run.
  bool _hasSession = false;

  @override
  Future<Result<String>> requestOtp({required String phone}) =>
      guard(() => _server.requestOtp(phone));

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String challengeId,
    required String code,
  }) => guard(() {
    final session = _server.verifyOtp(challengeId, code);
    if (session == null) {
      throw const MockConflict('That code is not correct. Please try again.');
    }
    _hasSession = true;
    return session;
  });

  @override
  Future<Result<AuthSession>> loginWithPassword({
    required String identifier,
    required String password,
  }) => guard(() {
    final session = _server.loginWithPassword(identifier, password);
    if (session == null) {
      throw const MockConflict('Those credentials were not recognised.');
    }
    _hasSession = true;
    return session;
  });

  @override
  Future<Result<String>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required TenantType tenantType,
  }) => guard(
    () => _server.register(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      tenantType: tenantType,
    ),
  );

  @override
  /// Nothing to do but succeed.
  ///
  /// A reset code is sent out of band, and the mock's code is the same one
  /// every other verification screen accepts — see
  /// `MockBackOffice.verificationCode`.
  Future<Result<void>> requestPasswordReset({required String identifier}) =>
      guard(() {});

  @override
  Future<Result<AuthSession?>> restoreSession() => guard(() {
    if (!_hasSession) return null;
    return AuthSession(
      user: _server.currentUser!,
      tenant: _server.currentTenant,
    );
  });

  @override
  Future<Result<void>> logout() => guard(() {
    _hasSession = false;
  });
}

// ---------------------------------------------------------------------------

class MockPropertyRepository with _MockLatency implements PropertyRepository {
  MockPropertyRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<Property>>> listProperties({
    String? query,
    PropertyType? type,
    int page = 1,
  }) => guard(() {
    var items = _server.properties.values.toList();

    if (type != null) {
      items = items.where((p) => p.propertyType == type).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final needle = query.toLowerCase();
      items = items
          .where(
            (p) =>
                p.name.toLowerCase().contains(needle) ||
                p.city.toLowerCase().contains(needle) ||
                p.code.toLowerCase().contains(needle),
          )
          .toList();
    }

    // Availability counts are derived, so they stay honest as bookings change.
    return _paginate(
      items.map(_withDerivedCounts).toList(growable: false),
      page,
    );
  });

  @override
  Future<Result<Property>> getProperty(String propertyId) => guard(() {
    final property = _server.properties[propertyId];
    if (property == null) throw const MockNotFound('Property not found');
    return _withDerivedCounts(property);
  });

  /// Section 15 prefers deriving occupancy over storing it, so the counts are
  /// worked out at read time from the units that exist right now.
  Property _withDerivedCounts(PropertyRow row) {
    var total = 0;
    var available = 0;
    for (final unit in _server.units.values) {
      if (unit.propertyId != row.id) continue;
      total++;
      if (_server.isUnitAvailable(unit.id)) available++;
    }
    return row.toDomain(totalUnits: total, availableUnits: available);
  }

  @override
  Future<Result<List<Building>>> listBuildings(String propertyId) => guard(
    () => _server.buildings
        .where((b) => b.propertyId == propertyId)
        .toList(growable: false),
  );

  @override
  Future<Result<List<Floor>>> listFloors(String buildingId) => guard(
    () => _server.floors
        .where((f) => f.buildingId == buildingId)
        .toList(growable: false),
  );
}

// ---------------------------------------------------------------------------

class MockUnitRepository with _MockLatency implements UnitRepository {
  MockUnitRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<Unit>>> listUnits({
    UnitFilter filter = const UnitFilter(),
    int page = 1,
  }) => guard(() {
    _server.expireDueBookings();

    var rows = _server.units.values.toList();

    if (filter.propertyId != null) {
      rows = rows.where((u) => u.propertyId == filter.propertyId).toList();
    }
    if (filter.buildingId != null) {
      rows = rows.where((u) => u.buildingId == filter.buildingId).toList();
    }
    if (filter.floorId != null) {
      rows = rows.where((u) => u.floorId == filter.floorId).toList();
    }
    if (filter.unitTypeId != null) {
      rows = rows.where((u) => u.unitTypeId == filter.unitTypeId).toList();
    }
    if (filter.minRentMinorUnits != null) {
      rows = rows
          .where((u) => u.baseRent.minorUnits >= filter.minRentMinorUnits!)
          .toList();
    }
    if (filter.maxRentMinorUnits != null) {
      rows = rows
          .where((u) => u.baseRent.minorUnits <= filter.maxRentMinorUnits!)
          .toList();
    }
    if (filter.query != null && filter.query!.trim().isNotEmpty) {
      final needle = filter.query!.toLowerCase();
      rows = rows
          .where(
            (u) =>
                u.unitNumber.toLowerCase().contains(needle) ||
                (u.name ?? '').toLowerCase().contains(needle),
          )
          .toList();
    }

    // Section 48: availability is derived from bookings and leases, not read
    // off a column, so the filter asks the engine rather than the status field.
    if (filter.availableOnly) {
      rows = rows.where((u) => _server.isUnitAvailable(u.id)).toList();
    }

    rows.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    return _paginate(
      rows.map((r) => r.toDomain()).toList(growable: false),
      page,
    );
  });

  @override
  Future<Result<Unit>> getUnit(String unitId) => guard(() {
    _server.expireDueBookings();
    final unit = _server.units[unitId];
    if (unit == null) throw const MockNotFound('Unit not found');
    return unit.toDomain();
  });

  @override
  Future<Result<List<UnitType>>> listUnitTypes(String propertyId) => guard(
    () => _server.unitTypes
        .where((t) => t.propertyId == propertyId)
        .toList(growable: false),
  );

  @override
  Future<Result<List<UnitPricing>>> listPricing(String unitId) => guard(() {
    final unit = _server.units[unitId];
    if (unit == null) throw const MockNotFound('Unit not found');
    final now = _server.now;
    // Section 19: current pricing, plus a scheduled increase, so a tenant can
    // see what happens at renewal before committing.
    return [
      UnitPricing(
        id: '${unitId}_price_current',
        unitId: unitId,
        billingFrequency: unit.billingFrequency,
        amount: unit.baseRent,
        effectiveFrom: DateTime(now.year, 1, 1),
        effectiveTo: DateTime(now.year, 12, 31),
        isActive: true,
      ),
      UnitPricing(
        id: '${unitId}_price_next',
        unitId: unitId,
        billingFrequency: unit.billingFrequency,
        amount: unit.baseRent.percentage(110),
        effectiveFrom: DateTime(now.year + 1, 1, 1),
        isActive: false,
      ),
    ];
  });
}

// ---------------------------------------------------------------------------

class MockBookingRepository with _MockLatency implements BookingRepository {
  MockBookingRepository(this._server);

  final MockServer _server;

  Booking _toDomain(BookingRow row) {
    final unit = _server.units[row.unitId];
    return row.toDomain(
      propertyName: _server.properties[row.propertyId]?.name,
      unitNumber: unit?.unitNumber,
    );
  }

  @override
  Future<Result<BookingQuote>> getQuote(String unitId) => guard(() {
    if (!_server.units.containsKey(unitId)) {
      throw const MockNotFound('Unit not found');
    }
    if (!_server.isUnitAvailable(unitId)) {
      throw const MockConflict('This unit is no longer available.');
    }
    return _server.quoteFor(unitId);
  });

  @override
  Future<Result<Booking>> createBooking({
    required String unitId,
    required BookingApplicant applicant,
    required String idempotencyKey,
  }) => guard(
    () => _toDomain(
      _server.createBooking(
        unitId: unitId,
        applicant: applicant,
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  @override
  Future<Result<Page<Booking>>> listBookings({
    BookingStatus? status,
    int page = 1,
  }) => guard(() {
    _server.expireDueBookings();
    var rows = _server.bookings.values
        .where((b) => b.tenantId == _server.currentTenant?.id)
        .toList();
    if (status != null) {
      rows = rows.where((b) => b.status == status).toList();
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _paginate(rows.map(_toDomain).toList(growable: false), page);
  });

  @override
  Future<Result<Booking>> getBooking(String bookingId) => guard(() {
    _server.expireDueBookings();
    final row = _server.bookings[bookingId];
    if (row == null) throw const MockNotFound('Booking not found');
    return _toDomain(row);
  });

  @override
  Future<Result<Booking>> cancelBooking(String bookingId) => guard(() {
    _server.cancelBooking(bookingId);
    return _toDomain(_server.bookings[bookingId]!);
  });

  @override
  Future<Result<BookingRequirement>> submitRequirement({
    required String bookingId,
    required String requirementId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) => guard(
    () => _server.submitRequirementDocument(
      bookingId: bookingId,
      requirementId: requirementId,
      fileName: fileName,
      byteLength: bytes.length,
      mimeType: mimeType,
    ),
  );
}

// ---------------------------------------------------------------------------

class MockLeaseRepository with _MockLatency implements LeaseRepository {
  MockLeaseRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<Lease>>> listLeases({LeaseStatus? status, int page = 1}) =>
      guard(() {
        var rows = _server.leases.values
            .where((l) => l.tenantId == _server.currentTenant?.id)
            .toList();
        if (status != null) {
          rows = rows.where((l) => l.status == status).toList();
        }
        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return _paginate(
          rows
              .map((r) => r.toDomain(conditions: _server.conditionsFor(r)))
              .toList(growable: false),
          page,
        );
      });

  @override
  Future<Result<Lease>> getLease(String leaseId) => guard(() {
    final row = _server.leases[leaseId];
    if (row == null) throw const MockNotFound('Lease not found');
    return row.toDomain(conditions: _server.conditionsFor(row));
  });

  @override
  Future<Result<LeaseAgreement>> getAgreement(String leaseId) => guard(() {
    final view = _server.agreementFor(leaseId);
    return LeaseAgreement(
      leaseId: leaseId,
      documentHash: view.hash,
      version: view.lease.agreementVersion,
      generatedAt: view.lease.createdAt,
      body: view.body,
      documentId: view.lease.signedAgreementDocumentId,
    );
  });

  @override
  Future<Result<Lease>> signLease({
    required String leaseId,
    required SignatureType signatureType,
    required List<int> signatureData,
    required String documentHash,
    required String idempotencyKey,
  }) => guard(() {
    final row = _server.signLease(
      leaseId: leaseId,
      signatureType: signatureType,
      documentHash: documentHash,
      idempotencyKey: idempotencyKey,
    );
    return row.toDomain(conditions: _server.conditionsFor(row));
  });
}

// ---------------------------------------------------------------------------

class MockInvoiceRepository with _MockLatency implements InvoiceRepository {
  MockInvoiceRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<Invoice>>> listInvoices({
    InvoiceStatus? status,
    String? leaseId,
    int page = 1,
  }) => guard(() {
    _server.markOverdueInvoices();
    var rows = _server.invoices.values
        .where((i) => i.tenantId == _server.currentTenant?.id)
        .toList();
    if (status != null) {
      rows = rows.where((i) => i.status == status).toList();
    }
    if (leaseId != null) {
      rows = rows.where((i) => i.leaseId == leaseId).toList();
    }
    rows.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return _paginate(
      rows.map((r) => r.toDomain()).toList(growable: false),
      page,
    );
  });

  @override
  Future<Result<Page<Invoice>>> listInvoicesForTenant(String tenantId) =>
      guard(() {
        _server.markOverdueInvoices();
        final rows =
            _server.invoices.values
                .where((invoice) => invoice.tenantId == tenantId)
                .toList()
              ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
        return Page.single(
          rows.map((row) => row.toDomain()).toList(growable: false),
        );
      });

  @override
  Future<Result<Invoice>> getInvoice(String invoiceId) => guard(() {
    _server.markOverdueInvoices();
    final row = _server.invoices[invoiceId];
    if (row == null) throw const MockNotFound('Invoice not found');
    return row.toDomain();
  });

  @override
  Future<Result<void>> deferInvoice({
    required String invoiceId,
    required String reason,
  }) => guard(() => _server.deferInvoice(invoiceId: invoiceId, reason: reason));

  @override
  Future<Result<void>> settleInvoice(String invoiceId) =>
      guard(() => _server.settleInvoice(invoiceId));
}

// ---------------------------------------------------------------------------

class MockPaymentRepository with _MockLatency implements PaymentRepository {
  MockPaymentRepository(this._server);

  final MockServer _server;

  /// [amount] is deliberately unused.
  ///
  /// It is on the interface because the published contract requires it on the
  /// wire. A server that trusted it would be a server that lets the client
  /// decide what it is owed, so this one charges what the invoice says and
  /// ignores what it was told (section 65).
  @override
  Future<Result<PaymentIntent>> initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required Money amount,
    required String idempotencyKey,
    String? phoneNumber,
  }) => guard(
    () => _server.initiatePayment(
      invoiceId: invoiceId,
      method: method,
      idempotencyKey: idempotencyKey,
      phoneNumber: phoneNumber,
    ),
  );

  @override
  Future<Result<Payment>> getPayment(String paymentId) => guard(() {
    final row = _server.payments[paymentId];
    if (row == null) throw const MockNotFound('Payment not found');
    return row.toDomain();
  });

  @override
  Future<Result<Page<Payment>>> listPayments({int page = 1}) => guard(() {
    final rows =
        _server.payments.values
            .where((p) => p.tenantId == _server.currentTenant?.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _paginate(
      rows.map((r) => r.toDomain()).toList(growable: false),
      page,
    );
  });
}

// ---------------------------------------------------------------------------

class MockReceiptRepository with _MockLatency implements ReceiptRepository {
  MockReceiptRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Receipt>> getReceipt(String receiptId) => guard(() {
    final receipt = _server.receipts[receiptId];
    if (receipt == null) throw const MockNotFound('Receipt not found');
    return receipt;
  });

  @override
  Future<Result<Receipt>> getReceiptForPayment(String paymentId) => guard(() {
    final receipt = _server.receipts.values
        .where((r) => r.paymentId == paymentId)
        .firstOrNull;
    if (receipt == null) {
      throw const MockNotFound('No receipt has been issued for this payment');
    }
    return receipt;
  });

  @override
  Future<Result<Page<Receipt>>> listReceipts({int page = 1}) => guard(() {
    final items =
        _server.receipts.values
            .where((r) => r.tenantId == _server.currentTenant?.id)
            .toList()
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return _paginate(items, page);
  });
}

// ---------------------------------------------------------------------------

class MockDocumentRepository with _MockLatency implements DocumentRepository {
  MockDocumentRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<Document>>> listDocuments({
    DocumentType? type,
    int page = 1,
  }) => guard(() {
    var items = _server.documents.values.toList();
    if (type != null) {
      items = items.where((d) => d.documentType == type).toList();
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _paginate(items, page);
  });

  @override
  Future<Result<String>> getDownloadUrl(String documentId) => guard(() {
    final document = _server.documents[documentId];
    if (document == null) throw const MockNotFound('Document not found');
    // Section 75: a signed, short-lived URL rather than a public link. There is
    // no object store behind the mock, so this is illustrative only.
    final expiry = _server.now
        .add(const Duration(minutes: 15))
        .millisecondsSinceEpoch;
    return 'https://files.example.com/${document.id}/${document.fileName}'
        '?expires=$expiry&signature=${_server.hashOf(document.id)}';
  });

  @override
  Future<Result<Document>> upload({
    required DocumentType type,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) => guard(
    () => _server.storeDocument(
      type: type,
      fileName: fileName,
      byteLength: bytes.length,
      mimeType: mimeType,
    ),
  );
}

// ---------------------------------------------------------------------------

class MockNotificationRepository
    with _MockLatency
    implements NotificationRepository {
  MockNotificationRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Page<NotificationItem>>> listNotifications({int page = 1}) =>
      guard(
        () => _paginate(
          _server.notifications
              .map((n) => n.toDomain())
              .toList(growable: false),
          page,
        ),
      );

  @override
  Future<Result<int>> unreadCount() =>
      guard(() => _server.notifications.where((n) => !n.isRead).length);

  @override
  Future<Result<void>> markRead(String notificationId) => guard(() {
    for (final n in _server.notifications) {
      if (n.id == notificationId) n.isRead = true;
    }
  });

  @override
  Future<Result<void>> markAllRead() => guard(() {
    for (final n in _server.notifications) {
      n.isRead = true;
    }
  });

  @override
  Future<Result<Set<NotificationChannel>>> getChannelPreferences() =>
      guard(() => _server.channelPreferences);

  @override
  Future<Result<void>> setChannelPreferences(
    Set<NotificationChannel> channels,
  ) => guard(() {
    _server.channelPreferences = channels;
  });
}

// ---------------------------------------------------------------------------

class MockTenantRepository with _MockLatency implements TenantRepository {
  MockTenantRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<Tenant>> getCurrentTenant() => guard(() {
    final tenant = _server.currentTenant;
    if (tenant == null) throw const MockNotFound('No tenant record');
    return tenant;
  });

  @override
  Future<Result<TenantProfile>> updateProfile(TenantProfile profile) =>
      guard(() {
        final tenant = _server.currentTenant!;
        _server.currentTenant = Tenant(
          id: tenant.id,
          userId: tenant.userId,
          tenantType: tenant.tenantType,
          displayName: profile.legalName ?? tenant.displayName,
          status: tenant.status,
          profile: profile,
        );
        return profile;
      });
}

// ---------------------------------------------------------------------------

class MockOwnerRepository with _MockLatency implements OwnerRepository {
  MockOwnerRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<PropertyOwner>> getOwner() => guard(() {
    final owner = _server.currentOwner;
    if (owner == null) throw const MockNotFound('Not signed in as an owner');
    return owner;
  });

  @override
  Future<Result<OwnerPortfolio>> getPortfolio() => guard(() {
    final owner = _server.currentOwner;
    if (owner == null) throw const MockNotFound('Not signed in as an owner');
    return _server.ownerPortfolio(owner.id);
  });

  @override
  Future<Result<PropertyPerformance>> getPropertyPerformance(
    String propertyId,
  ) => guard(() {
    final owner = _server.currentOwner;
    if (owner == null) throw const MockNotFound('Not signed in as an owner');

    // An owner may only read their own buildings. The mock enforces it because
    // the real server will have to, and a client written against a server that
    // does not check is a client that will break when it starts.
    final property = _server.properties[propertyId];
    if (property == null || property.ownerId != owner.id) {
      throw const MockNotFound('Property not found');
    }
    return _server.propertyPerformance(propertyId);
  });

  @override
  Future<Result<RepricingImpact>> getRepricingImpact(String propertyId) =>
      guard(() {
        _requireOwned(propertyId);
        final impact = _server.repricingImpact(propertyId);
        return RepricingImpact(
          repriceable: impact.repriceable,
          overridden: impact.overridden,
          let: impact.let,
        );
      });

  @override
  Future<Result<List<RentRollEntry>>> getRentRoll(String propertyId) =>
      guard(() {
        _requireOwned(propertyId);
        return _server.rentRoll(propertyId);
      });

  @override
  Future<Result<List<OwnerTenancy>>> getTenancies({String? propertyId}) =>
      guard(() {
        final owner = _requireOwner();
        if (propertyId != null) _requireOwned(propertyId);
        return _server.tenanciesFor(owner.id, propertyId: propertyId);
      });

  @override
  Future<Result<OwnerTenancy>> getTenancy(String leaseId) => guard(() {
    final owner = _requireOwner();
    return _server.tenancy(owner.id, leaseId);
  });

  @override
  Future<Result<OwnerLedger>> getLedger() =>
      guard(() => _server.ownerLedger(_requireOwner().id));

  @override
  Future<Result<Property>> createProperty({
    required PropertyDraft draft,
    required String idempotencyKey,
  }) => guard(() {
    final owner = _requireOwner();
    return _server
        .createProperty(
          ownerId: owner.id,
          draft: draft,
          idempotencyKey: idempotencyKey,
        )
        .toDomain();
  });

  @override
  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  }) => guard(() {
    _requireOwned(propertyId);
    return _server.createUnits(
      propertyId: propertyId,
      draft: draft,
      idempotencyKey: idempotencyKey,
    );
  });

  @override
  Future<Result<Property>> setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  }) => guard(() {
    _requireOwned(propertyId);
    return _server
        .setRatePerSqm(
          propertyId: propertyId,
          rate: rate,
          repriceExistingUnits: repriceExistingUnits,
        )
        .property
        .toDomain();
  });

  @override
  Future<Result<Unit>> setUnitRent({required String unitId, Money? override}) =>
      guard(() {
        final unit = _server.units[unitId];
        if (unit == null) throw const MockNotFound('Unit not found');
        _requireOwned(unit.propertyId);
        return _server
            .setUnitRent(unitId: unitId, override: override)
            .toDomain();
      });

  PropertyOwner _requireOwner() {
    final owner = _server.currentOwner;
    if (owner == null) throw const MockNotFound('Not signed in as an owner');
    return owner;
  }

  /// An owner may only touch their own buildings. Enforced here because the
  /// real server will have to, and a client written against one that does not
  /// check is a client that breaks when it starts.
  void _requireOwned(String propertyId) {
    final owner = _requireOwner();
    final property = _server.properties[propertyId];
    if (property == null || property.ownerId != owner.id) {
      throw const MockNotFound('Property not found');
    }
  }
}

class MockDashboardRepository with _MockLatency implements DashboardRepository {
  MockDashboardRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<DashboardSummary>> getSummary() =>
      guard(() => _server.dashboard());
}

// ---------------------------------------------------------------------------
// Property structure
// ---------------------------------------------------------------------------

class MockPropertyStructureRepository
    with _MockLatency
    implements PropertyStructureRepository {
  MockPropertyStructureRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<void>> updateProperty({
    required String propertyId,
    required PropertyDraft draft,
  }) => guard(() => _server.updateProperty(propertyId, draft));

  @override
  Future<Result<void>> archiveProperty(String propertyId) =>
      guard(() => _server.setPropertyArchived(propertyId, archived: true));

  @override
  Future<Result<void>> restoreProperty(String propertyId) =>
      guard(() => _server.setPropertyArchived(propertyId, archived: false));

  @override
  Future<Result<List<Building>>> listBlocks(String propertyId) => guard(
    () => _server.buildings
        .where((block) => block.propertyId == propertyId)
        .toList(growable: false),
  );

  @override
  Future<Result<Building>> getBlock(String blockId) => guard(() {
    for (final block in _server.buildings) {
      if (block.id == blockId) return block;
    }
    throw const MockNotFound('Block not found');
  });

  @override
  Future<Result<void>> createBlock(BuildingDraft draft) =>
      guard(() => _server.createBlock(draft));

  @override
  Future<Result<void>> updateBlock({
    required String blockId,
    required BuildingDraft draft,
  }) => guard(() => _server.updateBlock(blockId, draft));

  @override
  Future<Result<void>> deleteBlock(String blockId) =>
      guard(() => _server.deleteBlock(blockId));

  @override
  Future<Result<List<Unit>>> listBlockUnits(String blockId) => guard(() {
    final rows =
        _server.units.values
            .where((unit) => unit.buildingId == blockId && !unit.isDeleted)
            .map((unit) => unit.toDomain())
            .toList()
          ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    return rows;
  });

  @override
  Future<Result<void>> createUnit(UnitDraft draft) =>
      guard(() => _server.createUnit(draft));

  @override
  Future<Result<void>> updateUnit({
    required String unitId,
    required UnitDraft draft,
  }) => guard(() => _server.updateUnit(unitId, draft));

  @override
  Future<Result<void>> deleteUnit(String unitId) =>
      guard(() => _server.deleteUnit(unitId));
}

// ---------------------------------------------------------------------------
// Treasury
// ---------------------------------------------------------------------------

class MockTreasuryRepository with _MockLatency implements TreasuryRepository {
  MockTreasuryRepository(this._server);

  final MockServer _server;

  @override
  Future<Result<List<MpesaTransaction>>> listMpesaTransactions({
    String? propertyId,
  }) => guard(() => _server.backOffice.listMpesa(propertyId: propertyId));

  @override
  Future<Result<List<MpesaTransaction>>> findMpesaTransactions(
    String transactionId,
  ) => guard(() => _server.backOffice.findMpesa(transactionId));

  @override
  Future<Result<void>> setMpesaAccountNumber({
    required String transactionId,
    required String accountNumber,
  }) => guard(
    () => _server.backOffice.setAccountNumber(
      transactionId: transactionId,
      accountNumber: accountNumber,
    ),
  );

  @override
  Future<Result<List<BankPayment>>> listBankPayments() =>
      guard(() => _server.backOffice.listBankPayments());

  @override
  Future<Result<void>> recordBankPayment({
    required BankPaymentDraft draft,
    required String idempotencyKey,
  }) => guard(
    () => _server.backOffice.recordBankPayment(
      draft: draft,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<Result<void>> updateBankPayment(BankPayment payment) =>
      guard(() => _server.backOffice.updateBankPayment(payment));

  @override
  Future<Result<void>> deleteBankPayment(String bankPaymentId) =>
      guard(() => _server.backOffice.deleteBankPayment(bankPaymentId));
}

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------

class MockAccessRepository with _MockLatency implements AccessRepository {
  MockAccessRepository(this._server);

  final MockServer _server;

  MockBackOffice get _office => _server.backOffice;

  @override
  Future<Result<List<PlatformUser>>> listUsers() =>
      guard(() => _office.listUsers());

  @override
  Future<Result<void>> toggleUserEnabled(String userId) =>
      guard(() => _office.toggleUserEnabled(userId));

  @override
  Future<Result<void>> deleteUser(String userId) =>
      guard(() => _office.deleteUser(userId));

  @override
  Future<Result<List<AccessRole>>> listRoles() =>
      guard(() => _office.listRoles());

  @override
  Future<Result<void>> createRole(String roleName) =>
      guard(() => _office.createRole(roleName));

  @override
  Future<Result<List<AccessRole>>> rolesForUser(String phoneNumber) =>
      guard(() => _office.rolesForUser(phoneNumber));

  @override
  Future<Result<void>> addUserToRole({
    required String phoneNumber,
    required String roleName,
  }) => guard(
    () => _office.addUserToRole(phoneNumber: phoneNumber, roleName: roleName),
  );

  @override
  Future<Result<void>> removeUserFromRole({
    required String phoneNumber,
    required String roleName,
  }) => guard(
    () => _office.removeUserFromRole(
      phoneNumber: phoneNumber,
      roleName: roleName,
    ),
  );

  @override
  Future<Result<List<AccessClaim>>> claimsForUser(String phoneNumber) =>
      guard(() => _office.claimsForUser(phoneNumber));

  @override
  Future<Result<void>> addClaimToUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => guard(
    () => _office.addClaimToUser(
      phoneNumber: phoneNumber,
      claimType: claimType,
      claimValue: claimValue,
    ),
  );

  @override
  Future<Result<void>> removeClaimFromUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => guard(
    () => _office.removeClaimFromUser(
      phoneNumber: phoneNumber,
      claimType: claimType,
      claimValue: claimValue,
    ),
  );

  @override
  Future<Result<List<AccessClaim>>> claimsForRole(String roleName) =>
      guard(() => _office.claimsForRole(roleName));

  @override
  Future<Result<void>> addClaimToRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) => guard(
    () => _office.addClaimToRole(
      roleName: roleName,
      claimType: claimType,
      claimValue: claimValue,
    ),
  );

  @override
  Future<Result<void>> removeClaimFromRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) => guard(
    () => _office.removeClaimFromRole(
      roleName: roleName,
      claimType: claimType,
      claimValue: claimValue,
    ),
  );
}

// ---------------------------------------------------------------------------
// The signed-in account
// ---------------------------------------------------------------------------

class MockAccountRepository with _MockLatency implements AccountRepository {
  MockAccountRepository(this._server);

  final MockServer _server;

  MockBackOffice get _office => _server.backOffice;

  @override
  Future<Result<PlatformUser>> getAccount() =>
      guard(() => _office.currentAccount());

  @override
  Future<Result<void>> changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  }) => guard(
    () => _office.changePassword(
      phoneNumber: phoneNumber,
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  @override
  Future<Result<void>> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) => guard(
    () => _office.resetPassword(
      phoneNumber: phoneNumber,
      resetToken: resetToken,
      newPassword: newPassword,
    ),
  );

  @override
  Future<Result<void>> enableTwoFactor() => guard(_office.enableTwoFactor);

  @override
  Future<Result<void>> verifyTwoFactor({
    required String email,
    required String code,
  }) => guard(() => _office.verifyTwoFactor(email: email, code: code));

  @override
  Future<Result<void>> confirmEmail({
    required String email,
    required String token,
  }) => guard(() => _office.confirmEmail(email: email, token: token));

  @override
  Future<Result<void>> confirmPhoneNumber({
    required String email,
    required String phoneNumber,
    required String token,
  }) => guard(
    () => _office.confirmPhoneNumber(
      email: email,
      phoneNumber: phoneNumber,
      token: token,
    ),
  );

  @override
  Future<Result<void>> updateProfilePicture(String encodedImage) =>
      guard(() => _office.updateProfilePicture(encodedImage));

  @override
  Future<Result<void>> updateAccount({
    required String userId,
    required String fullName,
    required String emailAddress,
    required String phoneNumber,
  }) => guard(
    () => _office.updateAccount(
      userId: userId,
      fullName: fullName,
      emailAddress: emailAddress,
      phoneNumber: phoneNumber,
    ),
  );
}
