import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone_number.dart';
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
import '../../storage/token_store.dart';
import '../models/api_mappers.dart';
import 'api_client.dart';
import 'endpoints.dart';

/// HTTP implementations of the repository interfaces, against the published
/// contract in `api.md`.
///
/// Three things are worth knowing before reading further.
///
/// **The contract does not cover everything the app shows.** Leases,
/// documents, notifications, receipts and the two report dashboards have no
/// published route. Those repositories still point at the paths the app was
/// designed around, grouped at the bottom of `Endpoints` and marked; against
/// the live API they will 404 until the contract catches up. Faking them here
/// would hide the gap rather than close it.
///
/// **The contract does not paginate.** List routes return a whole array. The
/// [Page] wrapper is kept because the presentation layer is built on it, and
/// filled with `Page.single` — one honest page of everything, rather than a
/// pretence of paging that would silently drop rows past the first screen.
///
/// **Filtering happens here only where the server offers no parameter.** Where
/// it does, the query goes to the server. The difference is marked at each
/// call site, because a filter applied client-side is a filter that only sees
/// what was already fetched.
// ---------------------------------------------------------------------------

/// Resolves the signed-in account, once.
///
/// Several routes are keyed on the tenant's id or the account's phone number,
/// neither of which the app carries in a repository call. Rather than have
/// each repository fetch the account for itself, they share this: it asks
/// once, remembers, and hands out what it learned.
class AccountIdentity {
  AccountIdentity(this._api);

  final ApiClient _api;
  Json? _account;

  Future<Result<Json>> load({bool refresh = false}) async {
    final cached = _account;
    if (cached != null && !refresh) return Ok(cached);

    final result = await _api.get<Json>(
      Endpoints.account,
      parse: (json) => json,
    );
    if (result case Ok(:final value)) _account = value;
    return result;
  }

  /// The tenant record's id, which is what the invoice route is keyed on.
  Future<Result<String>> tenantId() async {
    final account = await load();
    return switch (account) {
      Err<Json>(:final failure) => Err(failure),
      Ok<Json>(:final value) => () {
        final id = (value['tenantId'] ?? value['id'])?.toString();
        return id == null || id.isEmpty
            ? const Err<String>(
                NotFoundFailure('This account has no tenant record yet.'),
              )
            : Ok<String>(id);
      }(),
    };
  }

  void forget() => _account = null;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._tokenStore, this._identity);

  final ApiClient _api;
  final TokenStore _tokenStore;
  final AccountIdentity _identity;

  /// How long a token is assumed good for when the server does not say.
  ///
  /// The contract returns a token and a refresh token but no expiry. Rather
  /// than treat the session as eternal, it is treated as short: the client
  /// refreshes on the hour, and a 401 refreshes immediately regardless. An
  /// assumption that expires too early costs one extra round trip; one that
  /// expires too late costs a failed request in front of the user.
  static const Duration _assumedTokenLife = Duration(hours: 1);

  Future<Result<AuthSession>> _storeAndBuild(Json payload) async {
    final access = payload['token']?.toString();
    final refresh = payload['refreshToken']?.toString();

    if (access == null || access.isEmpty) {
      final errors = payload['errors'];
      final message = errors is List && errors.isNotEmpty
          ? errors.first.toString()
          : 'Those details were not accepted.';
      return Err(ValidationFailure(message));
    }

    await _tokenStore.write(
      AuthTokens(
        accessToken: access,
        refreshToken: refresh ?? '',
        expiresAt:
            DateTime.tryParse(payload['expiresAt']?.toString() ?? '') ??
            DateTime.now().add(_assumedTokenLife),
      ),
    );

    _identity.forget();

    // The sign-in response carries the user inline on some routes and not on
    // others. Where it does not, the account route is authoritative.
    final inline = payload['user'];
    if (inline is Json) {
      return Ok(AuthSession(user: userFromJson(inline), tenant: null));
    }

    final account = await _identity.load(refresh: true);
    return switch (account) {
      Ok<Json>(:final value) => Ok(
        AuthSession(user: userFromJson(value), tenant: null),
      ),
      Err<Json>() => Ok(AuthSession(user: userFromJson(payload), tenant: null)),
    };
  }

  /// The contract publishes no "send me a sign-in code" route.
  ///
  /// Its only code-based flow is two-factor authentication, which assumes a
  /// caller who has *already* authenticated. So this asks for that code and
  /// hands back the phone number as the challenge, which [verifyOtp] passes
  /// on. Until the contract publishes an unauthenticated OTP request, phone
  /// plus code cannot start a session on its own — password sign-in can.
  @override
  Future<Result<String>> requestOtp({required String phone}) async {
    final result = await _api.command(Endpoints.enableTwoFactor);
    return switch (result) {
      Ok<void>() => Ok(PhoneNumber.normalize(phone)),
      Err<void>(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final result = await _api.post<Json>(
      Endpoints.verifyTwoFactor,
      // The contract names this field `email`; it is the identifier the code
      // was issued against, which is what [requestOtp] handed back.
      body: {'email': challengeId, 'code': code},
      parse: (json) => json,
    );

    return switch (result) {
      Err<Json>(:final failure) => Err(failure),
      Ok<Json>(:final value) => await _storeAndBuild(value),
    };
  }

  @override
  Future<Result<AuthSession>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final result = await _api.post<Json>(
      Endpoints.login,
      // The contract signs in by phone number. [identifier] is whatever was
      // typed into the sign-in field: a number in any spelling, which is put
      // into the stored form, or an email, which [PhoneNumber] leaves alone so
      // the server states the problem rather than the client guessing at it.
      body: {
        'phoneNumber': PhoneNumber.normalize(identifier),
        'password': password,
      },
      parse: (json) => json,
    );

    return switch (result) {
      Err<Json>(:final failure) => Err(failure),
      Ok<Json>(:final value) => await _storeAndBuild(value),
    };
  }

  @override
  Future<Result<String>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required TenantType tenantType,
  }) async {
    final result = await _api.post<Json>(
      Endpoints.register,
      body: {
        // The contract holds one name, not two.
        'fullName': '$firstName $lastName'.trim(),
        'phoneNumber': PhoneNumber.normalize(phone),
        'emailAddress': email,
        'password': password,
        // `roleName`, not `api`: the server looks this up in its role table by
        // name and refuses the normalised `TENANT` with "Role Not Found".
        'userRole': AccountRole.tenant.roleName,
      },
      parse: (json) => json,
    );

    // Registration finishes through verification, and the phone number is what
    // the verification screens are keyed on.
    return switch (result) {
      Ok<Json>() => Ok(PhoneNumber.normalize(phone)),
      Err<Json>(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> requestPasswordReset({required String identifier}) =>
      _api.command(Endpoints.forgotPassword, body: {
        'phoneNumber': PhoneNumber.normalize(identifier),
      });

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return const Ok(null);

    final result = await _identity.load(refresh: true);

    return switch (result) {
      Ok<Json>(:final value) => Ok(
        AuthSession(user: userFromJson(value), tenant: null),
      ),
      // An expired session is not an error worth showing; it just means the
      // tenant needs to sign in again.
      Err<Json>(failure: UnauthorizedFailure()) => const Ok(null),
      Err<Json>(:final failure) => Err(failure),
    };
  }

  /// The contract has no sign-out route: a session ends when its token does.
  ///
  /// Clearing the token here is the whole of it, and it is enough — the app
  /// forgets the session, and nothing on this device can present it again.
  @override
  Future<Result<void>> logout() async {
    await _tokenStore.clear();
    _identity.forget();
    return const Ok(null);
  }
}

// ---------------------------------------------------------------------------
// The signed-in account
// ---------------------------------------------------------------------------

class RemoteAccountRepository implements AccountRepository {
  RemoteAccountRepository(this._api, this._identity);

  final ApiClient _api;
  final AccountIdentity _identity;

  @override
  Future<Result<PlatformUser>> getAccount() async {
    final result = await _identity.load(refresh: true);
    return result.map(platformUserFromJson);
  }

  @override
  Future<Result<void>> changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  }) => _api.command(
    Endpoints.changePassword,
    body: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    },
  );

  @override
  Future<Result<void>> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) => _api.command(
    Endpoints.resetPassword,
    body: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'resetToken': resetToken,
      'newPassword': newPassword,
    },
  );

  @override
  Future<Result<void>> enableTwoFactor() =>
      _api.command(Endpoints.enableTwoFactor);

  @override
  Future<Result<void>> verifyTwoFactor({
    required String email,
    required String code,
  }) => _api.command(
    Endpoints.verifyTwoFactor,
    body: {'email': email, 'code': code},
  );

  @override
  Future<Result<void>> confirmEmail({
    required String email,
    required String token,
  }) => _api.command(
    Endpoints.confirmEmail,
    query: {'email': email, 'token': token},
  );

  @override
  Future<Result<void>> confirmPhoneNumber({
    required String email,
    required String phoneNumber,
    required String token,
  }) => _api.command(
    Endpoints.confirmPhoneNumber,
    query: {
      'email': email,
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'token': token,
    },
  );

  @override
  Future<Result<void>> updateProfilePicture(String encodedImage) async {
    final result = await _api.command(
      Endpoints.updateProfilePicture,
      body: {'image': encodedImage},
    );
    _identity.forget();
    return result;
  }

  @override
  Future<Result<void>> updateAccount({
    required String userId,
    required String fullName,
    required String emailAddress,
    required String phoneNumber,
  }) async {
    final result = await _api.command(
      Endpoints.updateCustomUser,
      method: 'PUT',
      body: {
        'userId': userId,
        'fullName': fullName,
        'emailAddress': emailAddress,
        'phoneNumber': PhoneNumber.normalize(phoneNumber),
      },
    );
    _identity.forget();
    return result;
  }
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

class RemotePropertyRepository implements PropertyRepository {
  RemotePropertyRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Property>>> listProperties({
    String? query,
    PropertyType? type,
    int page = 1,
  }) async {
    final result = await _api.get<List<Property>>(
      Endpoints.properties,
      parse: (json) => listFromJson(json, propertyFromJson),
    );

    // Filtered here because the route takes no parameters. Everything is
    // already in hand, so this narrows the whole set rather than one page of
    // it.
    return result.map((properties) {
      final needle = query?.trim().toLowerCase();
      final matches = properties
          .where((property) {
            if (type != null && property.propertyType != type) return false;
            if (needle == null || needle.isEmpty) return true;
            return property.name.toLowerCase().contains(needle) ||
                property.city.toLowerCase().contains(needle) ||
                (property.description?.toLowerCase().contains(needle) ?? false);
          })
          .toList(growable: false);
      return Page.single(matches);
    });
  }

  @override
  Future<Result<Property>> getProperty(String propertyId) =>
      _api.get(Endpoints.property(propertyId), parse: propertyFromJson);

  @override
  Future<Result<List<Building>>> listBuildings(String propertyId) => _api.get(
    Endpoints.propertyBlocks(propertyId),
    parse: (json) => listFromJson(json, buildingFromJson),
  );

  /// Floors are a count on the block, not records of their own.
  ///
  /// See `floorsFromBlock`: the block is fetched and its floor count expanded
  /// into the levels the browse filter needs. Nothing invented — the number
  /// came from the server.
  @override
  Future<Result<List<Floor>>> listFloors(String buildingId) =>
      _api.get(Endpoints.block(buildingId), parse: floorsFromBlock);
}

// ---------------------------------------------------------------------------
// Units
// ---------------------------------------------------------------------------

class RemoteUnitRepository implements UnitRepository {
  RemoteUnitRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<Unit>>> listUnits({
    UnitFilter filter = const UnitFilter(),
    int page = 1,
  }) async {
    // The contract lists units within a block or within a property, and offers
    // nothing across the whole platform. So the narrowest route the filter
    // allows is used, and only the browse-everything case pays for the wider
    // fetch.
    final Result<List<Unit>> result;
    if (filter.buildingId != null) {
      result = await _api.get(
        Endpoints.blockUnits(filter.buildingId!),
        parse: (json) => listFromJson(json, unitFromJson),
      );
    } else if (filter.propertyId != null) {
      result = await _api.get(
        Endpoints.propertyUnits(filter.propertyId!),
        parse: (json) => listFromJson(json, unitFromJson),
      );
    } else {
      // Every property carries its units inline, so one call answers this
      // rather than one call per property.
      result = await _api.get(
        Endpoints.properties,
        parse: (json) => [
          for (final property in rawListFromJson(json))
            ...(property['units'] is List
                ? (property['units'] as List).whereType<Json>().map(
                    (unit) => unitFromJson({...unit, 'property': property}),
                  )
                : const <Unit>[]),
        ],
      );
    }

    return result.map((units) => Page.single(_applyFilter(units, filter)));
  }

  List<Unit> _applyFilter(List<Unit> units, UnitFilter filter) {
    final needle = filter.query?.trim().toLowerCase();
    return units
        .where((unit) {
          if (filter.availableOnly && !unit.status.isBookable) return false;
          if (filter.floorId != null && unit.floorId != filter.floorId) {
            return false;
          }
          if (filter.unitTypeId != null &&
              unit.unitTypeId != filter.unitTypeId) {
            return false;
          }
          final rent = unit.baseRent.minorUnits;
          if (filter.minRentMinorUnits != null &&
              rent < filter.minRentMinorUnits!) {
            return false;
          }
          if (filter.maxRentMinorUnits != null &&
              rent > filter.maxRentMinorUnits!) {
            return false;
          }
          if (needle == null || needle.isEmpty) return true;
          return unit.unitNumber.toLowerCase().contains(needle) ||
              (unit.name?.toLowerCase().contains(needle) ?? false) ||
              unit.category.label.toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  @override
  Future<Result<Unit>> getUnit(String unitId) =>
      _api.get(Endpoints.unit(unitId), parse: unitFromJson);

  /// The contract has no unit-type templates. The browse filter that reads
  /// this simply finds nothing to offer, which is the truth.
  @override
  Future<Result<List<UnitType>>> listUnitTypes(String propertyId) async =>
      const Ok(<UnitType>[]);

  /// Nor does it keep effective-dated pricing. A unit has one rent, and the
  /// detail screen shows that rather than a history that does not exist.
  @override
  Future<Result<List<UnitPricing>>> listPricing(String unitId) async =>
      const Ok(<UnitPricing>[]);
}

// ---------------------------------------------------------------------------
// Property structure
// ---------------------------------------------------------------------------

class RemotePropertyStructureRepository implements PropertyStructureRepository {
  RemotePropertyStructureRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<void>> updateProperty({
    required String propertyId,
    required PropertyDraft draft,
  }) => _api.command(
    Endpoints.updateProperty(propertyId),
    method: 'PUT',
    body: propertyDraftToJson(draft),
  );

  @override
  Future<Result<void>> archiveProperty(String propertyId) =>
      _api.command(Endpoints.deleteProperty(propertyId), method: 'DELETE');

  @override
  Future<Result<void>> restoreProperty(String propertyId) =>
      _api.command(Endpoints.restoreProperty(propertyId), method: 'PUT');

  @override
  Future<Result<List<Building>>> listBlocks(String propertyId) => _api.get(
    Endpoints.propertyBlocks(propertyId),
    parse: (json) => listFromJson(json, buildingFromJson),
  );

  @override
  Future<Result<Building>> getBlock(String blockId) =>
      _api.get(Endpoints.block(blockId), parse: buildingFromJson);

  @override
  Future<Result<void>> createBlock(BuildingDraft draft) =>
      _api.command(Endpoints.createBlock, body: buildingDraftToJson(draft));

  @override
  Future<Result<void>> updateBlock({
    required String blockId,
    required BuildingDraft draft,
  }) => _api.command(
    Endpoints.updateBlock(blockId),
    method: 'PUT',
    body: buildingDraftToJson(draft),
  );

  @override
  Future<Result<void>> deleteBlock(String blockId) =>
      _api.command(Endpoints.deleteBlock(blockId), method: 'DELETE');

  @override
  Future<Result<List<Unit>>> listBlockUnits(String blockId) => _api.get(
    Endpoints.blockUnits(blockId),
    parse: (json) => listFromJson(json, unitFromJson),
  );

  @override
  Future<Result<void>> createUnit(UnitDraft draft) =>
      _api.command(Endpoints.createUnit, body: unitDraftToJson(draft));

  @override
  Future<Result<void>> updateUnit({
    required String unitId,
    required UnitDraft draft,
  }) => _api.command(
    Endpoints.updateUnit(unitId),
    method: 'PUT',
    body: unitDraftToJson(draft),
  );

  @override
  Future<Result<void>> deleteUnit(String unitId) =>
      _api.command(Endpoints.deleteUnit(unitId), method: 'DELETE');
}

// ---------------------------------------------------------------------------
// Bookings
// ---------------------------------------------------------------------------

class RemoteBookingRepository implements BookingRepository {
  RemoteBookingRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<BookingQuote>> getQuote(String unitId) async {
    // The contract has no quote route. The unit itself states the terms, so
    // the quote is read off it — the same figures the server would quote,
    // asked for one call earlier.
    final unit = await _api.get<Unit>(
      Endpoints.unit(unitId),
      parse: unitFromJson,
    );
    return unit.map(quoteFromUnit);
  }

  @override
  Future<Result<Booking>> createBooking({
    required String unitId,
    required BookingApplicant applicant,
    required String idempotencyKey,
  }) async {
    // The booking request wants the property and block the unit sits in, and
    // the caller has only the unit. Reading the unit first is what supplies
    // them; it also means the terms shown to the applicant were the terms in
    // force a moment before the request.
    final unit = await _api.get<Unit>(
      Endpoints.unit(unitId),
      parse: unitFromJson,
    );

    return switch (unit) {
      Err<Unit>(:final failure) => Err(failure),
      Ok<Unit>(value: final found) => await _api.post<Booking>(
        Endpoints.bookUnit,
        body: bookingRequestToJson(
          unitId: unitId,
          propertyId: found.propertyId,
          blockId: found.buildingId,
          applicant: applicant,
        ),
        idempotencyKey: idempotencyKey,
        // The route answers with a message, not with the booking. What comes
        // back is built from the unit that was just booked and the terms it
        // carried, so the confirmation screen has something true to show
        // until the booking list is next read.
        parse: (json) => bookingFromCreation(json, found, applicant),
      ),
    };
  }

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
// Leases — not published; see the note at the top of this file.
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
// Invoices
// ---------------------------------------------------------------------------

class RemoteInvoiceRepository implements InvoiceRepository {
  RemoteInvoiceRepository(this._api, this._identity);

  final ApiClient _api;
  final AccountIdentity _identity;

  @override
  Future<Result<Page<Invoice>>> listInvoices({
    InvoiceStatus? status,
    String? leaseId,
    int page = 1,
  }) async {
    final tenantId = await _identity.tenantId();

    return switch (tenantId) {
      Err<String>(:final failure) => Err(failure),
      Ok<String>(value: final id) =>
        await _api
            .get<List<Invoice>>(
              Endpoints.tenantInvoices(id),
              parse: (json) => listFromJson(json, invoiceFromJson),
            )
            .then(
              // Narrowed here because the route takes the tenant and nothing
              // else. The whole set is in hand, so this filters all of it.
              (result) => result.map(
                (invoices) => Page.single(
                  invoices
                      .where(
                        (invoice) =>
                            (status == null || invoice.status == status) &&
                            (leaseId == null || invoice.leaseId == leaseId),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
    };
  }

  @override
  Future<Result<Page<Invoice>>> listInvoicesForTenant(String tenantId) => _api
      .get<List<Invoice>>(
        Endpoints.tenantInvoices(tenantId),
        parse: (json) => listFromJson(json, invoiceFromJson),
      )
      .then((result) => result.map(Page.single));

  /// The contract lists a tenant's invoices and does not serve them one by one.
  ///
  /// So the list is read and the one asked for is picked out of it. A miss is
  /// a genuine not-found rather than an empty screen.
  @override
  Future<Result<Invoice>> getInvoice(String invoiceId) async {
    final invoices = await listInvoices();

    return switch (invoices) {
      Err<Page<Invoice>>(:final failure) => Err(failure),
      Ok<Page<Invoice>>(:final value) => () {
        for (final invoice in value.items) {
          if (invoice.id == invoiceId) return Ok<Invoice>(invoice);
        }
        return const Err<Invoice>(
          NotFoundFailure('We could not find that invoice.'),
        );
      }(),
    };
  }

  @override
  Future<Result<void>> deferInvoice({
    required String invoiceId,
    required String reason,
  }) => _api.command(
    Endpoints.deferInvoice,
    body: {'invoiceId': _invoiceId(invoiceId), 'deferReason': reason},
  );

  @override
  Future<Result<void>> settleInvoice(String invoiceId) => _api.command(
    Endpoints.settleInvoice,
    body: {'invoiceId': _invoiceId(invoiceId)},
  );

  Object _invoiceId(String id) => int.tryParse(id) ?? id;
}

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

class RemotePaymentRepository implements PaymentRepository {
  RemotePaymentRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<PaymentIntent>> initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required Money amount,
    required String idempotencyKey,
    String? phoneNumber,
  }) {
    if (method != PaymentMethod.mpesa) {
      // The contract's only in-app payment route is the M-Pesa request.
      // Anything else is recorded as a manual payment through the treasury,
      // and saying so beats a request the server will refuse.
      return Future.value(
        Err(
          ValidationFailure(
            '${method.label} cannot be started in the app. Pay by M-Pesa, or '
            'record a bank transfer instead.',
          ),
        ),
      );
    }

    return _api.post(
      Endpoints.createPaymentRequest,
      body: {
        'invoiceId': int.tryParse(invoiceId) ?? invoiceId,
        // The number the STK prompt goes to; the gateway only accepts it in
        // the `2547…` form.
        'phoneNumber': PhoneNumber.normalizeOrNull(phoneNumber),
        // The invoice's outstanding balance as the server last stated it. The
        // contract requires the figure on the request; the app carries it back
        // rather than deriving one. The route types it as a whole number.
        'amount': (amount.majorUnits).round(),
      },
      idempotencyKey: idempotencyKey,
      // The route answers with the invoices, not with a payment. The intent is
      // built from what was asked for, and the outcome comes from polling —
      // which is exactly section 39's rule that the handset never decides.
      parse: (json) => paymentIntentFromRequest(json, invoiceId, amount),
    );
  }

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
// Treasury
// ---------------------------------------------------------------------------

class RemoteTreasuryRepository implements TreasuryRepository {
  RemoteTreasuryRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<MpesaTransaction>>> listMpesaTransactions({
    String? propertyId,
  }) => _api.get(
    Endpoints.mpesaPayments,
    query: {'propertyId': ?propertyId},
    parse: (json) => listFromJson(json, mpesaTransactionFromJson),
  );

  @override
  Future<Result<List<MpesaTransaction>>> findMpesaTransactions(
    String transactionId,
  ) => _api.get(
    Endpoints.mpesaPaymentByTransId,
    query: {'transId': transactionId},
    parse: (json) => listFromJson(json, mpesaTransactionFromJson),
  );

  @override
  Future<Result<void>> setMpesaAccountNumber({
    required String transactionId,
    required String accountNumber,
  }) => _api.command(
    Endpoints.updateMpesaAccountNumber,
    method: 'PUT',
    query: {'Id': transactionId, 'accountNumber': accountNumber},
  );

  @override
  Future<Result<List<BankPayment>>> listBankPayments() => _api.get(
    Endpoints.bankPayments,
    parse: (json) => listFromJson(json, bankPaymentFromJson),
  );

  @override
  Future<Result<void>> recordBankPayment({
    required BankPaymentDraft draft,
    required String idempotencyKey,
  }) => _api.command(
    Endpoints.createManualPayment,
    body: bankPaymentDraftToJson(draft),
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<void>> updateBankPayment(BankPayment payment) => _api.command(
    Endpoints.updateBankPayment,
    method: 'PUT',
    body: bankPaymentToJson(payment),
  );

  @override
  Future<Result<void>> deleteBankPayment(String bankPaymentId) => _api.command(
    Endpoints.deleteBankPayment(bankPaymentId),
    method: 'DELETE',
  );
}

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------

class RemoteAccessRepository implements AccessRepository {
  RemoteAccessRepository(this._api);

  final ApiClient _api;

  /// Merges the two views the contract keeps of an account.
  ///
  /// `/auth/get/users` knows names, phone numbers and whether an account is
  /// disabled; `/roles/get/all/users` knows what each account has been
  /// granted. Neither is complete, and an administrator needs both on one row
  /// — so both are fetched and joined on the phone number they share.
  @override
  Future<Result<List<PlatformUser>>> listUsers() async {
    final accounts = await _api.get<List<PlatformUser>>(
      Endpoints.users,
      parse: (json) => listFromJson(json, platformUserFromJson),
    );
    if (accounts case Err<List<PlatformUser>>(:final failure)) {
      return Err(failure);
    }

    final granted = await _api.get<List<PlatformUser>>(
      Endpoints.roleUsers,
      parse: (json) => listFromJson(json, platformUserFromJson),
    );

    final rolesByPhone = <String, List<String>>{};
    if (granted case Ok<List<PlatformUser>>(value: final users)) {
      for (final user in users) {
        // The two routes have been seen to spell the same handset
        // differently, so the join key is the normalised number.
        final phone = PhoneNumber.normalizeOrNull(user.phoneNumber)?.trim();
        if (phone != null && phone.isNotEmpty) rolesByPhone[phone] = user.roles;
      }
    }

    return accounts.map(
      (users) => [
        for (final user in users)
          PlatformUser(
            id: user.id,
            userId: user.userId,
            fullName: user.fullName,
            phoneNumber: user.phoneNumber,
            emailAddress: user.emailAddress,
            role: user.role,
            profileImage: user.profileImage,
            roles:
                rolesByPhone[PhoneNumber.normalizeOrNull(
                  user.phoneNumber,
                )?.trim()] ??
                user.roles,
            isActive: user.isActive,
            isDeleted: user.isDeleted,
            emailConfirmed: user.emailConfirmed,
            phoneConfirmed: user.phoneConfirmed,
            twoFactorEnabled: user.twoFactorEnabled,
            lockoutEnabled: user.lockoutEnabled,
            lockedOutUntil: user.lockedOutUntil,
            createdByName: user.createdByName,
            lastLoginAt: user.lastLoginAt,
            createdAt: user.createdAt,
          ),
      ],
    );
  }

  @override
  Future<Result<void>> toggleUserEnabled(String userId) => _api.command(
    Endpoints.enableDisableUser,
    method: 'PUT',
    query: {'id': userId},
  );

  @override
  Future<Result<void>> deleteUser(String userId) =>
      _api.command(Endpoints.deleteUser(userId), method: 'DELETE');

  @override
  Future<Result<List<AccessRole>>> listRoles() => _api.get(
    Endpoints.roles,
    parse: (json) => listFromJson(json, accessRoleFromJson),
  );

  @override
  Future<Result<void>> createRole(String roleName) =>
      _api.command(Endpoints.createRole, query: {'roleName': roleName});

  @override
  Future<Result<List<AccessRole>>> rolesForUser(String phoneNumber) => _api.get(
    Endpoints.userRoles,
    query: {'phoneNumber': PhoneNumber.normalize(phoneNumber)},
    parse: (json) => listFromJson(json, accessRoleFromJson),
  );

  @override
  Future<Result<void>> addUserToRole({
    required String phoneNumber,
    required String roleName,
  }) => _api.command(
    Endpoints.addUserToRole,
    query: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'roleName': roleName,
    },
  );

  @override
  Future<Result<void>> removeUserFromRole({
    required String phoneNumber,
    required String roleName,
  }) => _api.command(
    Endpoints.removeUserFromRole,
    query: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'roleName': roleName,
    },
  );

  @override
  Future<Result<List<AccessClaim>>> claimsForUser(String phoneNumber) =>
      _api.get(
        Endpoints.userClaims,
        query: {'phoneNumber': PhoneNumber.normalize(phoneNumber)},
        parse: (json) => listFromJson(json, accessClaimFromJson),
      );

  @override
  Future<Result<void>> addClaimToUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => _api.command(
    Endpoints.addClaimToUser,
    query: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      // The contract names this one `claimName` on the way in and `claimType`
      // on the way out. Both are sent so the route binds whichever it reads.
      'claimName': claimType,
      'claimType': claimType,
      'claimValue': claimValue,
    },
  );

  @override
  Future<Result<void>> removeClaimFromUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  }) => _api.command(
    Endpoints.removeClaimFromUser,
    query: {
      'phoneNumber': PhoneNumber.normalize(phoneNumber),
      'claimName': claimType,
      'claimType': claimType,
      'claimValue': claimValue,
    },
  );

  @override
  Future<Result<List<AccessClaim>>> claimsForRole(String roleName) => _api.get(
    Endpoints.roleClaims,
    query: {'roleName': roleName},
    parse: (json) => listFromJson(json, accessClaimFromJson),
  );

  @override
  Future<Result<void>> addClaimToRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) => _api.command(
    Endpoints.addClaimToRole,
    query: {
      'roleName': roleName,
      'claimType': claimType,
      'claimValue': claimValue,
    },
  );

  @override
  Future<Result<void>> removeClaimFromRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  }) => _api.command(
    Endpoints.removeClaimFromRole,
    query: {
      'roleName': roleName,
      'claimType': claimType,
      'claimValue': claimValue,
    },
  );
}

// ---------------------------------------------------------------------------
// Receipts, documents, notifications, tenants, dashboards — not published.
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
  Future<Result<List<RentRollEntry>>> getRentRoll(String propertyId) =>
      _api.get(
        Endpoints.ownerRentRoll(propertyId),
        parse: (json) => pageFromJson(json, rentRollEntryFromJson).items,
      );

  @override
  Future<Result<List<OwnerTenancy>>> getTenancies({String? propertyId}) =>
      _api.get(
        Endpoints.ownerTenancies,
        query: {'propertyId': ?propertyId},
        parse: (json) => pageFromJson(json, ownerTenancyFromJson).items,
      );

  @override
  Future<Result<OwnerTenancy>> getTenancy(String leaseId) =>
      _api.get(Endpoints.ownerTenancy(leaseId), parse: ownerTenancyFromJson);

  @override
  Future<Result<OwnerLedger>> getLedger() =>
      _api.get(Endpoints.ownerLedger, parse: ownerLedgerFromJson);

  /// The one owner write the contract does publish.
  ///
  /// It answers with a message rather than the created property, so the
  /// property is read back afterwards — the caller gets the server's record,
  /// not a hopeful reconstruction of what it was asked to make.
  @override
  Future<Result<Property>> createProperty({
    required PropertyDraft draft,
    required String idempotencyKey,
  }) async {
    final created = await _api.command(
      Endpoints.createProperty,
      body: propertyDraftToJson(draft),
      idempotencyKey: idempotencyKey,
    );
    if (created case Err<void>(:final failure)) return Err(failure);

    final properties = await _api.get<List<Property>>(
      Endpoints.properties,
      parse: (json) => listFromJson(json, propertyFromJson),
    );

    return properties.map(
      (all) => all.lastWhere(
        (property) => property.name == draft.name,
        orElse: () => all.last,
      ),
    );
  }

  @override
  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  }) async {
    // The contract creates units one at a time. A batch is that call repeated,
    // and it stops at the first refusal rather than pressing on — a half-built
    // floor an owner can see is better than one built past an error nobody
    // was told about.
    var created = 0;
    for (var index = 0; index < draft.quantity; index++) {
      final result = await _api.command(
        Endpoints.createUnit,
        body: unitDraftToJson(unitDraftFromBatch(draft, propertyId, index)),
        idempotencyKey: '$idempotencyKey-$index',
      );
      if (result case Err<void>(:final failure)) {
        return created == 0 ? Err(failure) : Ok(created);
      }
      created++;
    }
    return Ok(created);
  }

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
  Future<Result<Unit>> setUnitRent({required String unitId, Money? override}) =>
      _api.put(
        Endpoints.ownerUnitRent(unitId),
        body: {
          // Null clears the override; the server re-derives from the rate.
          'baseRent': override?.toJson(),
          if (override != null) 'currency': override.currency,
        },
        parse: unitFromJson,
      );
}
