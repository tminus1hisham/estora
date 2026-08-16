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
import '../entities/billing.dart';
import '../entities/booking.dart';
import '../entities/dashboard_summary.dart';
import '../entities/lease.dart';
import '../entities/owner.dart';
import '../entities/property.dart';
import '../entities/tenant.dart';
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

  Future<Result<AuthSession>> loginWithPassword({
    required String email,
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

  Future<Result<void>> requestPasswordReset({required String email});

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
  /// The request body is the unit id and nothing else — no amounts. The server
  /// determines the commercial terms and captures them on the booking
  /// (section 21). [idempotencyKey] makes a retry safe (section 66).
  Future<Result<Booking>> createBooking({
    required String unitId,
    required String idempotencyKey,
  });

  Future<Result<Page<Booking>>> listBookings({
    BookingStatus? status,
    int page = 1,
  });

  Future<Result<Booking>> getBooking(String bookingId);

  Future<Result<Booking>> cancelBooking(String bookingId);

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

  Future<Result<Invoice>> getInvoice(String invoiceId);
}

abstract interface class PaymentRepository {
  /// Starts a payment against an invoice.
  ///
  /// Note what is *not* here: no total, no fee breakdown. The server knows what
  /// the invoice is worth (section 65). [phoneNumber] is only needed for M-Pesa
  /// STK Push, which sends the prompt to that handset (section 39).
  Future<Result<PaymentIntent>> initiatePayment({
    required String invoiceId,
    required PaymentMethod method,
    required String idempotencyKey,
    String? phoneNumber,
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
///
/// Read-only for now: an owner can see how the portfolio is doing. Creating a
/// property and moving its rate arrive with the next milestone, and they take
/// an `idempotencyKey` when they do.
abstract interface class OwnerRepository {
  Future<Result<PropertyOwner>> getOwner();

  /// Everything the portfolio screen shows, in one payload — the owner's
  /// counterpart to [DashboardRepository.getSummary].
  Future<Result<OwnerPortfolio>> getPortfolio();

  Future<Result<PropertyPerformance>> getPropertyPerformance(String propertyId);
}
