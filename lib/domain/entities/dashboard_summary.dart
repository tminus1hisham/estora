import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';
import 'billing.dart';

/// Section 44. Everything the tenant home screen shows, in one payload.
///
/// This is a single server-computed object rather than something the app
/// assembles by fetching invoices and summing them. Section 71 says these
/// values should be derived from transactional data, and the server is the only
/// place that has all of it — the handset sees a filtered view and would get
/// the outstanding balance wrong the moment a page of invoices was missing.
class DashboardSummary {
  const DashboardSummary({
    required this.currency,
    required this.outstandingBalance,
    required this.recentPayments,
    required this.unreadNotifications,
    this.propertyId,
    this.propertyName,
    this.propertyImageUrl,
    this.unitId,
    this.unitNumber,
    this.leaseId,
    this.leaseStatus,
    this.leaseEndDate,
    this.nextInvoice,
    this.nextPaymentDueDate,
    this.nextInvoiceAmount,
    this.overdueAmount,
    this.activeBookingId,
    this.activeBookingReference,
    this.activeBookingExpiresAt,
    this.pendingSignatureLeaseId,
  });

  final String currency;

  // -- Current tenancy -------------------------------------------------------

  final String? propertyId;
  final String? propertyName;
  final String? propertyImageUrl;
  final String? unitId;
  final String? unitNumber;
  final String? leaseId;
  final LeaseStatus? leaseStatus;
  final DateTime? leaseEndDate;

  // -- Money -----------------------------------------------------------------

  /// Total invoiced less allocated payments (section 71).
  final Money outstandingBalance;

  /// The portion of [outstandingBalance] that is past its due date.
  final Money? overdueAmount;

  final Money? nextInvoiceAmount;
  final DateTime? nextPaymentDueDate;

  /// The next invoice in full, when there is one to show.
  final Invoice? nextInvoice;

  final List<Payment> recentPayments;

  // -- Things needing the tenant's attention ---------------------------------

  final String? activeBookingId;
  final String? activeBookingReference;
  final DateTime? activeBookingExpiresAt;

  /// Set when a lease is sitting in PENDING_SIGNATURE (section 29).
  final String? pendingSignatureLeaseId;

  final int unreadNotifications;

  bool get hasTenancy => leaseId != null;
  bool get hasActiveBooking => activeBookingId != null;
  bool get hasOutstandingBalance => outstandingBalance.isPositive;
  bool get hasOverdue => (overdueAmount?.isPositive) ?? false;
  bool get needsSignature => pendingSignatureLeaseId != null;

  int? get daysUntilLeaseExpiry {
    final end = leaseEndDate;
    if (end == null) return null;
    return DateTime(end.year, end.month, end.day)
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
  }

  bool get isLeaseExpiringSoon {
    final days = daysUntilLeaseExpiry;
    return days != null && days <= 90 && days >= 0;
  }

  /// True when the tenant has nothing at all yet — drives the "browse units"
  /// empty state on the home screen.
  bool get isNewTenant => !hasTenancy && !hasActiveBooking;
}
