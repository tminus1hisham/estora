/// Repository interfaces.
///
/// One per resource in the API layout of section 64. These are the contract
/// between the app and the backend: presentation code depends only on what is
/// here, so swapping the in-memory mock for the HTTP client is a wiring change
/// in `services/providers.dart` and nothing else.
///
/// Two conventions run through every signature:
///
/// * Everything returns `Result<T>` — errors are values, never exceptions
///   crossing a layer boundary.
/// * Financial writes take an `idempotencyKey` (section 66). It is a required
///   parameter rather than an optional one so a call site cannot forget it.
library;

import '../../core/error/result.dart';
import '../../core/utils/money.dart';
import '../entities/access.dart';
import '../entities/billing.dart';
import '../entities/booking.dart';
import '../entities/dashboard_summary.dart';
import '../entities/lease.dart';
import '../entities/owner.dart';
import '../entities/property.dart';
import '../entities/tenant.dart';
import '../entities/treasury.dart';
import '../entities/unit.dart';
import '../enums/domain_enums.dart';

/// A page of results. Section 65 requires pagination on every list endpoint.
class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  const Page.single(this.items)
    : page = 1,
      pageSize = items.length,
      total = items.length;

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// /api/v1/auth
// ---------------------------------------------------------------------------

/// Section 72. Phone plus OTP is the primary flow for tenants; email and
/// password is the fallback.
abstract interface class AuthRepository {
  /// Sends an OTP to [phone]. Returns an opaque challenge id that must be
  /// passed back to [verifyOtp].
  Future<Result<String>> requestOtp({required String phone});

  Future<Result<AuthSession>> verifyOtp({
    required String challengeId,
    required String code,
  });

  /// Signs in with a password.
  ///
  /// [identifier] is whatever was typed into the sign-in field. The published
  /// contract keys on the phone number; the mock also answers to an email
  /// address, which is how the demo accounts work. Neither implementation
  /// guesses at which one it was given — the server decides, and its refusal
  /// is a better message than anything the client could invent.
  Future<Result<AuthSession>> loginWithPassword({
    required String identifier,
    required String password,
  });

  /// Registers a tenant account. Returns a challenge id — registration always
  /// finishes through phone verification.
  Future<Result<String>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required TenantType tenantType,
  });

  /// Starts a password reset. The contract sends the token to the phone
  /// number on the account; `AccountRepository.resetPassword` finishes it.
  Future<Result<void>> requestPasswordReset({required String identifier});

  /// Restores a session from stored tokens on app launch. Returns null when
  /// there is no usable session.
  Future<Result<AuthSession?>> restoreSession();

  Future<Result<void>> logout();
}

// ---------------------------------------------------------------------------
// /api/v1/properties, /api/v1/units
// ---------------------------------------------------------------------------

abstract interface class PropertyRepository {
  Future<Result<Page<Property>>> listProperties({
    String? query,
    PropertyType? type,
    int page = 1,
  });

  Future<Result<Property>> getProperty(String propertyId);

  Future<Result<List<Building>>> listBuildings(String propertyId);

  Future<Result<List<Floor>>> listFloors(String buildingId);
}

/// Filters for the available-units browse screen.
class UnitFilter {
  const UnitFilter({
    this.propertyId,
    this.buildingId,
    this.floorId,
    this.unitTypeId,
    this.query,
    this.minRentMinorUnits,
    this.maxRentMinorUnits,
    this.availableOnly = true,
  });

  final String? propertyId;
  final String? buildingId;
  final String? floorId;
  final String? unitTypeId;
  final String? query;
  final int? minRentMinorUnits;
  final int? maxRentMinorUnits;

  /// Section 48's availability engine is server-side. This asks it to return
  /// only what a tenant could actually book right now.
  final bool availableOnly;

  UnitFilter copyWith({
    String? propertyId,
    String? buildingId,
    String? floorId,
    String? unitTypeId,
    String? query,
    int? minRentMinorUnits,
    int? maxRentMinorUnits,
    bool? availableOnly,
    bool clearBuilding = false,
    bool clearFloor = false,
    bool clearUnitType = false,
  }) {
    return UnitFilter(
      propertyId: propertyId ?? this.propertyId,
      buildingId: clearBuilding ? null : (buildingId ?? this.buildingId),
      floorId: clearFloor ? null : (floorId ?? this.floorId),
      unitTypeId: clearUnitType ? null : (unitTypeId ?? this.unitTypeId),
      query: query ?? this.query,
      minRentMinorUnits: minRentMinorUnits ?? this.minRentMinorUnits,
      maxRentMinorUnits: maxRentMinorUnits ?? this.maxRentMinorUnits,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }

  bool get hasActiveFilters =>
      buildingId != null ||
      floorId != null ||
      unitTypeId != null ||
      minRentMinorUnits != null ||
      maxRentMinorUnits != null;
}

abstract interface class UnitRepository {
  /// Section 48's availability engine across the whole platform: every block
  /// with bookable stock, and the sizes on offer in each. This is what the
  /// Browse tab lists, so a tenant sees only spaces they could actually book.
  Future<Result<List<UnitAvailability>>> listAvailability();

  Future<Result<Page<Unit>>> listUnits({
    UnitFilter filter = const UnitFilter(),
    int page = 1,
  });

  Future<Result<Unit>> getUnit(String unitId);

  Future<Result<List<UnitType>>> listUnitTypes(String propertyId);

  /// Effective-dated pricing history (section 19). Shown on the unit detail
  /// screen so a tenant can see a scheduled increase before committing.
  Future<Result<List<UnitPricing>>> listPricing(String unitId);
}

// ---------------------------------------------------------------------------
// /api/v1/bookings
// ---------------------------------------------------------------------------

abstract interface class BookingRepository {
  /// Asks the server what booking this unit would produce and what it costs.
  ///
  /// Section 65: the client does not calculate rent, deposit, booking fee, tax
  /// or expiry. It asks, and renders the answer.
  Future<Result<BookingQuote>> getQuote(String unitId);

  /// Creates a booking.
  ///
  /// The body carries what is wanted and who is asking — and no amounts. The
  /// server determines the commercial terms and captures them on the booking
  /// (section 21). [idempotencyKey] makes a retry safe (section 66).
  Future<Result<Booking>> createBooking({
    required BookingTarget target,
    required BookingApplicant applicant,
    required String idempotencyKey,
  });

  Future<Result<Page<Booking>>> listBookings({
    BookingStatus? status,
    int page = 1,
  });

  Future<Result<Booking>> getBooking(String bookingId);

  Future<Result<Booking>> cancelBooking(String bookingId);

  /// Asks the server to send an M-Pesa prompt for the booking fee (section 24).
  ///
  /// [amount] is the booking's own [Booking.bookingFee], the figure the server
  /// captured when the booking was made, carried back unchanged because the
  /// contract's confirmation request requires it on the wire. The app never
  /// derives it. [phoneNumber] is the handset the prompt goes to.
  ///
  /// The answer is a [PaymentPrompt], not a payment: the outcome is read off
  /// the booking once the tenant has answered the prompt.
  Future<Result<PaymentPrompt>> requestBookingFeePrompt({
    required String bookingId,
    required String phoneNumber,
    required Money amount,
    required String idempotencyKey,
  });

  /// Uploads a document against one of the booking's requirements
  /// (sections 18 and 51).
  Future<Result<BookingRequirement>> submitRequirement({
    required String bookingId,
    required String requirementId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  });
}

// ---------------------------------------------------------------------------
// /api/v1/leases
// ---------------------------------------------------------------------------

abstract interface class LeaseRepository {
  Future<Result<Page<Lease>>> listLeases({LeaseStatus? status, int page = 1});

  Future<Result<Lease>> getLease(String leaseId);

  /// The rendered agreement text for in-app review (section 29 step 3).
  ///
  /// [documentHash] identifies exactly which version was displayed, and is
  /// echoed back on signing so the signature is bound to the text the tenant
  /// actually read.
  Future<Result<LeaseAgreement>> getAgreement(String leaseId);

  /// Section 29. Submits the tenant's signature.
  Future<Result<Lease>> signLease({
    required String leaseId,
    required SignatureType signatureType,
    required List<int> signatureData,
    required String documentHash,
    required String idempotencyKey,
  });
}

/// The lease agreement as presented for signing.
class LeaseAgreement {
  const LeaseAgreement({
    required this.leaseId,
    required this.documentHash,
    required this.version,
    required this.generatedAt,
    this.body,
    this.documentId,
    this.pdfUrl,
  });

  final String leaseId;

  /// Hash of this exact version (section 29). Passed back on signing.
  final String documentHash;

  /// Generated documents are versioned and immutable (section 28).
  final int version;
  final DateTime generatedAt;

  /// Rendered agreement text, for the in-app reader.
  final String? body;

  final String? documentId;
  final String? pdfUrl;
}

// ---------------------------------------------------------------------------
// /api/v1/invoices, /api/v1/payments, /api/v1/receipts
// ---------------------------------------------------------------------------

abstract interface class InvoiceRepository {
  Future<Result<Page<Invoice>>> listInvoices({
    InvoiceStatus? status,
    String? leaseId,
    int page = 1,
  });

  /// One tenant's invoices, read by somebody who is not that tenant.
  ///
  /// The contract's only invoice route is keyed on the tenant, which is what
  /// makes this the landlord's view as well as the tenant's: [listInvoices]
  /// answers for whoever is signed in, and this answers for a named tenant.
  /// Who may ask is the server's judgement, not the client's.
  Future<Result<Page<Invoice>>> listInvoicesForTenant(String tenantId);

  Future<Result<Invoice>> getInvoice(String invoiceId);

  /// Asks for payment of an invoice to be postponed, giving a reason.
  ///
  /// The decision is the landlord's; this records the request against the
  /// invoice. The debt is unchanged either way — see [Invoice.isDeferred].
  Future<Result<void>> deferInvoice({
    required String invoiceId,
    required String reason,
  });

  /// Closes an invoice against something other than a payment made through
  /// this app — a settlement, an offset, a write-off.
  ///
  /// Landlord-side only. Nothing on the tenant's side of the app calls this.
  Future<Result<void>> settleInvoice(String invoiceId);
}

abstract interface class PaymentRepository {
  /// Starts a payment against an invoice.
  ///
  /// [amount] is the invoice's outstanding balance as the *server* last stated
  /// it, carried back unchanged. It is here because the contract's payment
  /// request requires it, and for no other reason: nothing in the app derives,
  /// adjusts or sums it, and a stale figure is rejected by the server rather
  /// than reconciled by the client (section 65).
  ///
  /// [phoneNumber] is only needed for M-Pesa STK Push, which sends the prompt
  /// to that handset (section 39).
  Future<Result<PaymentIntent>> initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required Money amount,
    required String idempotencyKey,
    String? phoneNumber,
  });

  /// Asks the server to send an M-Pesa prompt for an invoice.
  ///
  /// The contract's payment request answers with the invoices it touched,
  /// not with a payment to poll, so this returns a [PaymentPrompt] and the
  /// outcome is read off the invoice afterwards. The same rules as
  /// [initiatePayment] apply to [amount]: the server's figure, echoed back.
  Future<Result<PaymentPrompt>> requestMpesaPrompt({
    required String invoiceId,
    required String phoneNumber,
    required Money amount,
    required String idempotencyKey,
  });

  /// Reads current server-side payment state.
  ///
  /// Section 39: "Never trust only the mobile application's payment result."
  /// The payment screen polls this until [PaymentStatus.isTerminal], and the
  /// app never marks a payment successful on its own.
  Future<Result<Payment>> getPayment(String paymentId);

  Future<Result<Page<Payment>>> listPayments({int page = 1});
}

abstract interface class ReceiptRepository {
  Future<Result<Receipt>> getReceipt(String receiptId);

  Future<Result<Receipt>> getReceiptForPayment(String paymentId);

  Future<Result<Page<Receipt>>> listReceipts({int page = 1});
}

// ---------------------------------------------------------------------------
// /api/v1/documents, /api/v1/notifications, /api/v1/tenants
// ---------------------------------------------------------------------------

abstract interface class DocumentRepository {
  Future<Result<Page<Document>>> listDocuments({
    DocumentType? type,
    int page = 1,
  });

  /// Returns a short-lived signed URL for viewing or downloading (section 75).
  Future<Result<String>> getDownloadUrl(String documentId);

  Future<Result<Document>> upload({
    required DocumentType type,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  });
}

abstract interface class NotificationRepository {
  Future<Result<Page<NotificationItem>>> listNotifications({int page = 1});

  Future<Result<int>> unreadCount();

  Future<Result<void>> markRead(String notificationId);

  Future<Result<void>> markAllRead();

  /// Section 49's channels. Which ones the tenant wants to receive.
  Future<Result<Set<NotificationChannel>>> getChannelPreferences();

  Future<Result<void>> setChannelPreferences(Set<NotificationChannel> channels);
}

abstract interface class TenantRepository {
  Future<Result<Tenant>> getCurrentTenant();

  Future<Result<TenantProfile>> updateProfile(TenantProfile profile);
}

abstract interface class DashboardRepository {
  /// Section 44's home screen payload, computed server-side (section 71).
  Future<Result<DashboardSummary>> getSummary();
}

/// Section 88. The owner's side of the platform.
abstract interface class OwnerRepository {
  Future<Result<PropertyOwner>> getOwner();

  /// Everything the portfolio screen shows, in one payload — the owner's
  /// counterpart to [DashboardRepository.getSummary].
  Future<Result<OwnerPortfolio>> getPortfolio();

  Future<Result<PropertyPerformance>> getPropertyPerformance(String propertyId);

  /// What a repricing would move, before committing to it.
  Future<Result<RepricingImpact>> getRepricingImpact(String propertyId);

  /// Every unit in a property, with its occupant and what they owe.
  Future<Result<List<RentRollEntry>>> getRentRoll(String propertyId);

  /// Tenancies across the portfolio, or one property's.
  Future<Result<List<OwnerTenancy>>> getTenancies({String? propertyId});

  Future<Result<OwnerTenancy>> getTenancy(String leaseId);

  /// What came in, what is owed, and what is due out (section 41).
  Future<Result<OwnerLedger>> getLedger();

  /// What came in over one [CollectionWindow], totalled and bucketed by the
  /// server (section 84 rule 7): the Money screen never adds up payments.
  Future<Result<CollectionSeries>> getCollections(CollectionWindow window);

  /// The owner's money as the contract serves it: every M-Pesa arrival and
  /// every invoice across the properties they hold, or across one property
  /// when [propertyId] is given. The Revenue screen is drawn from this.
  Future<Result<OwnerReport>> getReport({String? propertyId});

  Future<Result<Property>> createProperty({
    required PropertyDraft draft,
    required String idempotencyKey,
  });

  /// Returns how many units were generated.
  Future<Result<int>> createUnits({
    required String propertyId,
    required UnitBatchDraft draft,
    required String idempotencyKey,
  });

  /// Moves the asking rate, optionally repricing the units free to move.
  Future<Result<Property>> setRatePerSqm({
    required String propertyId,
    required Money rate,
    required bool repriceExistingUnits,
  });

  /// Prices one unit by hand. A null [override] clears it and re-derives the
  /// rent from the rate.
  Future<Result<Unit>> setUnitRent({required String unitId, Money? override});
}

// ---------------------------------------------------------------------------
// Property structure: blocks and individual units
// ---------------------------------------------------------------------------

/// Editing the shape of a property, rather than reading it.
///
/// [OwnerRepository] answers commercial questions — what a portfolio earns,
/// what a repricing would move. This one changes the fabric: the wings a
/// property is divided into and the units inside them. Kept apart because the
/// two are read by different screens at different moments, and because
/// everything here is a write.
abstract interface class PropertyStructureRepository {
  Future<Result<void>> updateProperty({
    required String propertyId,
    required PropertyDraft draft,
  });

  /// Archives a property. The contract's delete is a soft one — hence the
  /// name, and hence [restoreProperty] existing at all.
  Future<Result<void>> archiveProperty(String propertyId);

  Future<Result<void>> restoreProperty(String propertyId);

  Future<Result<List<Building>>> listBlocks(String propertyId);

  Future<Result<Building>> getBlock(String blockId);

  Future<Result<void>> createBlock(BuildingDraft draft);

  Future<Result<void>> updateBlock({
    required String blockId,
    required BuildingDraft draft,
  });

  Future<Result<void>> deleteBlock(String blockId);

  Future<Result<List<Unit>>> listBlockUnits(String blockId);

  Future<Result<void>> createUnit(UnitDraft draft);

  Future<Result<void>> updateUnit({
    required String unitId,
    required UnitDraft draft,
  });

  Future<Result<void>> deleteUnit(String unitId);
}

// ---------------------------------------------------------------------------
// Treasury: money as it actually arrived
// ---------------------------------------------------------------------------

abstract interface class TreasuryRepository {
  /// Every M-Pesa transaction the till received, newest first.
  Future<Result<List<MpesaTransaction>>> listMpesaTransactions({
    String? propertyId,
  });

  /// Looks a transaction up by the reference the payer holds.
  ///
  /// Returns a list because the contract does: a reference can appear more
  /// than once when a payment has been split or reissued.
  Future<Result<List<MpesaTransaction>>> findMpesaTransactions(
    String transactionId,
  );

  /// Corrects the account number a payer typed, so an orphaned payment can be
  /// reconciled against the right invoice.
  Future<Result<void>> setMpesaAccountNumber({
    required String transactionId,
    required String accountNumber,
  });

  Future<Result<List<BankPayment>>> listBankPayments();

  /// Records a payment made outside the app. Idempotent for the same reason
  /// every other financial write is (section 66).
  Future<Result<void>> recordBankPayment({
    required BankPaymentDraft draft,
    required String idempotencyKey,
  });

  Future<Result<void>> updateBankPayment(BankPayment payment);

  Future<Result<void>> deleteBankPayment(String bankPaymentId);
}

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------

/// Accounts, roles and claims.
///
/// Note that every role and claim operation is addressed by *phone number*
/// rather than by user id. That is the contract's choice and it is not
/// smoothed over here: an account without a phone number cannot be granted
/// anything, and the screens say so rather than offering a control that would
/// fail on submission.
abstract interface class AccessRepository {
  Future<Result<List<PlatformUser>>> listUsers();

  /// Flips an account between enabled and disabled. The contract exposes one
  /// route for both directions, so this is a toggle, not a setter.
  Future<Result<void>> toggleUserEnabled(String userId);

  Future<Result<void>> deleteUser(String userId);

  Future<Result<List<AccessRole>>> listRoles();

  Future<Result<void>> createRole(String roleName);

  Future<Result<List<AccessRole>>> rolesForUser(String phoneNumber);

  Future<Result<void>> addUserToRole({
    required String phoneNumber,
    required String roleName,
  });

  Future<Result<void>> removeUserFromRole({
    required String phoneNumber,
    required String roleName,
  });

  Future<Result<List<AccessClaim>>> claimsForUser(String phoneNumber);

  Future<Result<void>> addClaimToUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  });

  Future<Result<void>> removeClaimFromUser({
    required String phoneNumber,
    required String claimType,
    required String claimValue,
  });

  Future<Result<List<AccessClaim>>> claimsForRole(String roleName);

  Future<Result<void>> addClaimToRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  });

  Future<Result<void>> removeClaimFromRole({
    required String roleName,
    required String claimType,
    required String claimValue,
  });
}

// ---------------------------------------------------------------------------
// The signed-in account
// ---------------------------------------------------------------------------

/// Everything an account holder can do to their own credentials.
///
/// Separate from [AuthRepository], which is about *getting* a session. This is
/// about maintaining one that already exists — and about the two verification
/// flows that finish a registration.
abstract interface class AccountRepository {
  Future<Result<PlatformUser>> getAccount();

  Future<Result<void>> changePassword({
    required String phoneNumber,
    required String currentPassword,
    required String newPassword,
  });

  /// Completes the reset begun by [AuthRepository.requestPasswordReset], using
  /// the token that was sent to the tenant.
  Future<Result<void>> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  });

  /// Turns on two-factor authentication for the signed-in account. The server
  /// sends the first code; [verifyTwoFactor] confirms it.
  Future<Result<void>> enableTwoFactor();

  Future<Result<void>> verifyTwoFactor({
    required String email,
    required String code,
  });

  Future<Result<void>> confirmEmail({
    required String email,
    required String token,
  });

  Future<Result<void>> confirmPhoneNumber({
    required String email,
    required String phoneNumber,
    required String token,
  });

  /// Replaces the profile photo. The contract takes the image as an encoded
  /// string rather than a multipart upload.
  Future<Result<void>> updateProfilePicture(String encodedImage);

  Future<Result<void>> updateAccount({
    required String userId,
    required String fullName,
    required String emailAddress,
    required String phoneNumber,
  });
}
