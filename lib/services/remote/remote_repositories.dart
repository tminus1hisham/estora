import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/lease.dart';
import '../../domain/entities/owner.dart';
import '../../domain/entities/property.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/unit.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../../storage/token_store.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'endpoints.dart';

/// HTTP implementations of the repository interfaces, against the API layout in
/// section 64.
///
/// These are written to the documented contract but have not been exercised
/// against a running server, because none exists yet. Expect to adjust key
/// names in `api_mappers.dart` once the backend is real; the shape of these
/// classes should not need to change.
///
/// Note what is absent throughout: no amount is ever sent from the client, and
/// no total is ever computed here. That is section 65 and section 84 rule 7,
/// and it is the reason these methods look thin.
// ---------------------------------------------------------------------------

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._tokenStore);

  final ApiClient _api;
  final TokenStore _tokenStore;

  Future<Result<AuthSession>> _sessionFrom(Result<Json> result) async {
    return switch (result) {
      Err<Json>(:final failure) => Err(failure),
      Ok<Json>(:final value) => await _storeAndBuild(value),
    };
  }

  Future<Result<AuthSession>> _storeAndBuild(Json payload) async {
    final access = payload['accessToken']?.toString();
    final refresh = payload['refreshToken']?.toString();
    final expiresAt = DateTime.tryParse(payload['expiresAt']?.toString() ?? '');

    if (access == null || refresh == null || expiresAt == null) {
      return const Err(ServerFailure('The sign-in response was incomplete.'));
    }

    await _tokenStore.write(
      AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt,
      ),
    );

    final user = payload['user'];
    if (user is! Json) {
      return const Err(ServerFailure('The sign-in response was incomplete.'));
    }

    return Ok(
      AuthSession(
        user: userFromJson(user),
        tenant: payload['tenant'] is Json
            ? tenantFromJson(payload['tenant'] as Json)
            : null,
      ),
    );
  }

  @override
  Future<Result<String>> requestOtp({required String phone}) => _api.post(
    Endpoints.requestOtp,
    body: {'phone': phone},
    parse: (json) => json['challengeId'].toString(),
  );

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String challengeId,
    required String code,
  }) async => _sessionFrom(
    await _api.post<Json>(
      Endpoints.verifyOtp,
      body: {'challengeId': challengeId, 'code': code},
      parse: (json) => json,
    ),
  );

  @override
  Future<Result<AuthSession>> loginWithPassword({
    required String email,
    required String password,
  }) async => _sessionFrom(
    await _api.post<Json>(
      Endpoints.login,
      body: {'email': email, 'password': password},
      parse: (json) => json,
    ),
  );

  @override
  Future<Result<String>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required TenantType tenantType,
  }) => _api.post(
    Endpoints.register,
    body: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'password': password,
      'tenantType': tenantType.api,
    },
    parse: (json) => json['challengeId'].toString(),
  );

  @override
  Future<Result<void>> requestPasswordReset({required String email}) =>
      _api.command(Endpoints.passwordReset, body: {'email': email});

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return const Ok(null);

    final result = await _api.get<AuthSession>(
      Endpoints.me,
      parse: (json) => AuthSession(
        user: userFromJson(json['user'] as Json? ?? json),
        tenant: json['tenant'] is Json
            ? tenantFromJson(json['tenant'] as Json)
            : null,
      ),
    );

    return switch (result) {
      Ok<AuthSession>(:final value) => Ok(value),
      // An expired session is not an error worth showing; it just means the
      // tenant needs to sign in again.
      Err<AuthSession>(failure: UnauthorizedFailure()) => const Ok(null),
      Err<AuthSession>(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> logout() async {
    final result = await _api.command(Endpoints.logout);
    // Clear locally regardless: if the server call failed, the tenant still
    // expects to be signed out on this device.
    await _tokenStore.clear();
    return result;
  }
}

// ---------------------------------------------------------------------------

class RemotePropertyRepository implements PropertyRepository {
  RemotePropertyRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Property>>> listProperties({
    String? query,
    PropertyType? type,
    int page = 1,
  }) => _api.get(
    Endpoints.properties,
    query: {
      'page': page,
      if (query != null && query.isNotEmpty) 'search': query,
      if (type != null) 'propertyType': type.api,
    },
    parse: (json) => pageFromJson(json, propertyFromJson),
  );

  @override
  Future<Result<Property>> getProperty(String propertyId) =>
      _api.get(Endpoints.property(propertyId), parse: propertyFromJson);

  @override
  Future<Result<List<Building>>> listBuildings(String propertyId) => _api.get(
    Endpoints.propertyBuildings(propertyId),
    parse: (json) => pageFromJson(json, buildingFromJson).items,
  );

  @override
  Future<Result<List<Floor>>> listFloors(String buildingId) => _api.get(
    Endpoints.buildingFloors(buildingId),
    parse: (json) => pageFromJson(json, floorFromJson).items,
  );
}

// ---------------------------------------------------------------------------

class RemoteUnitRepository implements UnitRepository {
  RemoteUnitRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Unit>>> listUnits({
    UnitFilter filter = const UnitFilter(),
    int page = 1,
  }) => _api.get(
    Endpoints.units,
    query: {
      'page': page,
      if (filter.propertyId != null) 'propertyId': filter.propertyId,
      if (filter.buildingId != null) 'buildingId': filter.buildingId,
      if (filter.floorId != null) 'floorId': filter.floorId,
      if (filter.unitTypeId != null) 'unitTypeId': filter.unitTypeId,
      if (filter.query != null && filter.query!.isNotEmpty)
        'search': filter.query,
      if (filter.minRentMinorUnits != null)
        'minRent': filter.minRentMinorUnits! / 100,
      if (filter.maxRentMinorUnits != null)
        'maxRent': filter.maxRentMinorUnits! / 100,
      // Section 48: availability is the server's judgement, not a status filter
      // the client applies after the fact.
      if (filter.availableOnly) 'available': true,
    },
    parse: (json) => pageFromJson(json, unitFromJson),
  );

  @override
  Future<Result<Unit>> getUnit(String unitId) =>
      _api.get(Endpoints.unit(unitId), parse: unitFromJson);

  @override
  Future<Result<List<UnitType>>> listUnitTypes(String propertyId) => _api.get(
    Endpoints.propertyUnitTypes(propertyId),
    parse: (json) => pageFromJson(json, unitTypeFromJson).items,
  );

  @override
  Future<Result<List<UnitPricing>>> listPricing(String unitId) => _api.get(
    Endpoints.unitPricing(unitId),
    parse: (json) => pageFromJson(json, unitPricingFromJson).items,
  );
}

// ---------------------------------------------------------------------------

class RemoteBookingRepository implements BookingRepository {
  RemoteBookingRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<BookingQuote>> getQuote(String unitId) =>
      _api.get(Endpoints.bookingQuote(unitId), parse: bookingQuoteFromJson);

  @override
  Future<Result<Booking>> createBooking({
    required String unitId,
    required String idempotencyKey,
  }) => _api.post(
    Endpoints.bookings,
    // Section 65's worked example, exactly: the body is the unit id and
    // nothing else. Rent, deposit, booking fee, tax and expiry are all
    // determined by the server.
    body: {'unitId': unitId},
    idempotencyKey: idempotencyKey,
    parse: bookingFromJson,
  );

  @override
  Future<Result<Page<Booking>>> listBookings({
    BookingStatus? status,
    int page = 1,
  }) => _api.get(
    Endpoints.bookings,
    query: {'page': page, if (status != null) 'status': status.api},
    parse: (json) => pageFromJson(json, bookingFromJson),
  );

  @override
  Future<Result<Booking>> getBooking(String bookingId) =>
      _api.get(Endpoints.booking(bookingId), parse: bookingFromJson);

  @override
  Future<Result<Booking>> cancelBooking(String bookingId) =>
      _api.post(Endpoints.bookingCancel(bookingId), parse: bookingFromJson);

  @override
  Future<Result<BookingRequirement>> submitRequirement({
    required String bookingId,
    required String requirementId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) => _api.upload(
    Endpoints.bookingRequirement(bookingId, requirementId),
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    parse: bookingRequirementFromJson,
  );
}

// ---------------------------------------------------------------------------

class RemoteLeaseRepository implements LeaseRepository {
  RemoteLeaseRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Lease>>> listLeases({LeaseStatus? status, int page = 1}) =>
      _api.get(
        Endpoints.leases,
        query: {'page': page, if (status != null) 'status': status.api},
        parse: (json) => pageFromJson(json, leaseFromJson),
      );

  @override
  Future<Result<Lease>> getLease(String leaseId) =>
      _api.get(Endpoints.lease(leaseId), parse: leaseFromJson);

  @override
  Future<Result<LeaseAgreement>> getAgreement(String leaseId) => _api.get(
    Endpoints.leaseAgreement(leaseId),
    parse: leaseAgreementFromJson,
  );

  @override
  Future<Result<Lease>> signLease({
    required String leaseId,
    required SignatureType signatureType,
    required List<int> signatureData,
    required String documentHash,
    required String idempotencyKey,
  }) => _api.post(
    Endpoints.leaseSign(leaseId),
    body: {
      'signatureType': signatureType.api,
      'signatureData': _base64(signatureData),
      // Section 29: binds the signature to the exact version reviewed. If the
      // agreement has since been regenerated, the server rejects this.
      'documentHash': documentHash,
    },
    idempotencyKey: idempotencyKey,
    parse: leaseFromJson,
  );
}

String _base64(List<int> bytes) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : null;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : null;

    buffer.write(chars[b0 >> 2]);
    buffer.write(chars[((b0 & 0x03) << 4) | ((b1 ?? 0) >> 4)]);
    buffer.write(
      b1 == null ? '=' : chars[((b1 & 0x0F) << 2) | ((b2 ?? 0) >> 6)],
    );
    buffer.write(b2 == null ? '=' : chars[b2 & 0x3F]);
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------

class RemoteInvoiceRepository implements InvoiceRepository {
  RemoteInvoiceRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Invoice>>> listInvoices({
    InvoiceStatus? status,
    String? leaseId,
    int page = 1,
  }) => _api.get(
    Endpoints.invoices,
    query: {
      'page': page,
      if (status != null) 'status': status.api,
      'leaseId': ?leaseId,
    },
    parse: (json) => pageFromJson(json, invoiceFromJson),
  );

  @override
  Future<Result<Invoice>> getInvoice(String invoiceId) =>
      _api.get(Endpoints.invoice(invoiceId), parse: invoiceFromJson);
}

// ---------------------------------------------------------------------------

class RemotePaymentRepository implements PaymentRepository {
  RemotePaymentRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<PaymentIntent>> initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required String idempotencyKey,
    String? phoneNumber,
  }) => _api.post(
    Endpoints.payments,
    body: {
      'invoiceId': invoiceId,
      'paymentMethod': method.api,
      // The handset the STK push should go to (section 39). Not an amount --
      // the server charges what the invoice says is outstanding.
      'phoneNumber': ?phoneNumber,
    },
    idempotencyKey: idempotencyKey,
    parse: paymentIntentFromJson,
  );

  @override
  Future<Result<Payment>> getPayment(String paymentId) =>
      _api.get(Endpoints.payment(paymentId), parse: paymentFromJson);

  @override
  Future<Result<Page<Payment>>> listPayments({int page = 1}) => _api.get(
    Endpoints.payments,
    query: {'page': page},
    parse: (json) => pageFromJson(json, paymentFromJson),
  );
}

// ---------------------------------------------------------------------------

class RemoteReceiptRepository implements ReceiptRepository {
  RemoteReceiptRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Receipt>> getReceipt(String receiptId) =>
      _api.get(Endpoints.receipt(receiptId), parse: receiptFromJson);

  @override
  Future<Result<Receipt>> getReceiptForPayment(String paymentId) =>
      _api.get(Endpoints.receiptForPayment(paymentId), parse: receiptFromJson);

  @override
  Future<Result<Page<Receipt>>> listReceipts({int page = 1}) => _api.get(
    Endpoints.receipts,
    query: {'page': page},
    parse: (json) => pageFromJson(json, receiptFromJson),
  );
}

// ---------------------------------------------------------------------------

class RemoteDocumentRepository implements DocumentRepository {
  RemoteDocumentRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Document>>> listDocuments({
    DocumentType? type,
    int page = 1,
  }) => _api.get(
    Endpoints.documents,
    query: {'page': page, if (type != null) 'documentType': type.api},
    parse: (json) => pageFromJson(json, documentFromJson),
  );

  @override
  Future<Result<String>> getDownloadUrl(String documentId) => _api.get(
    // Section 75: the server hands back a short-lived signed URL rather than
    // the file itself or a permanent public link.
    Endpoints.documentDownload(documentId),
    parse: (json) => json['url'].toString(),
  );

  @override
  Future<Result<Document>> upload({
    required DocumentType type,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) => _api.upload(
    Endpoints.documents,
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    fields: {'documentType': type.api},
    parse: documentFromJson,
  );
}

// ---------------------------------------------------------------------------

class RemoteNotificationRepository implements NotificationRepository {
  RemoteNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<NotificationItem>>> listNotifications({int page = 1}) =>
      _api.get(
        Endpoints.notifications,
        query: {'page': page},
        parse: (json) => pageFromJson(json, notificationFromJson),
      );

  @override
  Future<Result<int>> unreadCount() => _api.get(
    Endpoints.notificationsUnread,
    parse: (json) => int.tryParse(json['count'].toString()) ?? 0,
  );

  @override
  Future<Result<void>> markRead(String notificationId) =>
      _api.command(Endpoints.notificationRead(notificationId));

  @override
  Future<Result<void>> markAllRead() =>
      _api.command(Endpoints.notificationsReadAll);

  @override
  Future<Result<Set<NotificationChannel>>> getChannelPreferences() => _api.get(
    Endpoints.notificationPreferences,
    parse: (json) {
      final channels = json['channels'];
      if (channels is! List) return <NotificationChannel>{};
      return channels
          .map((c) => NotificationChannel.fromApi(c.toString()))
          .where((c) => c != NotificationChannel.unknown)
          .toSet();
    },
  );

  @override
  Future<Result<void>> setChannelPreferences(
    Set<NotificationChannel> channels,
  ) => _api.command(
    Endpoints.notificationPreferences,
    method: 'PUT',
    body: {'channels': channels.map((c) => c.api).toList()},
  );
}

// ---------------------------------------------------------------------------

class RemoteTenantRepository implements TenantRepository {
  RemoteTenantRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Tenant>> getCurrentTenant() =>
      _api.get(Endpoints.currentTenant, parse: tenantFromJson);

  @override
  Future<Result<TenantProfile>> updateProfile(TenantProfile profile) =>
      _api.put(
        Endpoints.tenantProfile,
        body: tenantProfileToJson(profile),
        parse: tenantProfileFromJson,
      );
}

// ---------------------------------------------------------------------------

class RemoteDashboardRepository implements DashboardRepository {
  RemoteDashboardRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<DashboardSummary>> getSummary() =>
      _api.get(Endpoints.dashboard, parse: dashboardFromJson);
}

// ---------------------------------------------------------------------------
// Owner (section 88)
// ---------------------------------------------------------------------------

class RemoteOwnerRepository implements OwnerRepository {
  RemoteOwnerRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<PropertyOwner>> getOwner() =>
      _api.get(Endpoints.currentOwner, parse: ownerFromJson);

  @override
  Future<Result<OwnerPortfolio>> getPortfolio() =>
      _api.get(Endpoints.ownerPortfolio, parse: ownerPortfolioFromJson);

  @override
  Future<Result<PropertyPerformance>> getPropertyPerformance(
    String propertyId,
  ) => _api.get(
    Endpoints.ownerPropertyPerformance(propertyId),
    parse: propertyPerformanceFromJson,
  );

  @override
  Future<Result<RepricingImpact>> getRepricingImpact(String propertyId) =>
      _api.get(
        Endpoints.ownerRepricingImpact(propertyId),
        parse: repricingImpactFromJson,
      );

  @override
  Future<Result<Property>> createProperty({
    required PropertyDraft draft,
    required String idempotencyKey,
  }) => _api.post(
    Endpoints.properties,
    body: propertyDraftToJson(draft),
    idempotencyKey: idempotencyKey,
    parse: propertyFromJson,
  );

  @override
  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  }) => _api.post(
    Endpoints.ownerPropertyUnits(propertyId),
    body: unitBatchDraftToJson(draft),
    idempotencyKey: idempotencyKey,
    parse: (json) => (json['created'] as num?)?.toInt() ?? draft.quantity,
  );

  @override
  Future<Result<Property>> setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  }) => _api.put(
    Endpoints.ownerPropertyRate(propertyId),
    body: {
      'rentRatePerSqm': rate.toJson(),
      'currency': rate.currency,
      'repriceExistingUnits': repriceExistingUnits,
    },
    parse: propertyFromJson,
  );

  @override
  Future<Result<Unit>> setUnitRent({
    required String unitId,
    Money? override,
  }) => _api.put(
    Endpoints.ownerUnitRent(unitId),
    body: {
      // Null clears the override; the server re-derives from the rate.
      'baseRent': override?.toJson(),
      if (override != null) 'currency': override.currency,
    },
    parse: unitFromJson,
  );
}
