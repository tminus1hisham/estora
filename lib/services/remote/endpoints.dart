/// Endpoint paths, laid out exactly as section 64 specifies.
///
/// Paths are relative; the version prefix and host come from
/// `AppConfig.apiRoot`, which satisfies section 65's versioning requirement in
/// one place rather than 40.
class Endpoints {
  const Endpoints._();

  // /api/v1/auth
  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String passwordReset = '/auth/password-reset';
  static const String me = '/auth/me';

  // /api/v1/properties
  static const String properties = '/properties';
  static String property(String id) => '/properties/$id';
  static String propertyBuildings(String id) => '/properties/$id/buildings';
  static String propertyUnitTypes(String id) => '/properties/$id/unit-types';

  // /api/v1/buildings, /api/v1/floors
  static String buildingFloors(String id) => '/buildings/$id/floors';

  // /api/v1/units
  static const String units = '/units';
  static String unit(String id) => '/units/$id';
  static String unitPricing(String id) => '/units/$id/pricing';

  // /api/v1/bookings
  static const String bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';
  static String bookingCancel(String id) => '/bookings/$id/cancel';
  static String bookingQuote(String unitId) => '/bookings/quote/$unitId';
  static String bookingRequirement(String bookingId, String requirementId) =>
      '/bookings/$bookingId/requirements/$requirementId';

  // /api/v1/leases
  static const String leases = '/leases';
  static String lease(String id) => '/leases/$id';
  static String leaseAgreement(String id) => '/leases/$id/agreement';
  static String leaseSign(String id) => '/leases/$id/signatures';

  // /api/v1/invoices
  static const String invoices = '/invoices';
  static String invoice(String id) => '/invoices/$id';

  // /api/v1/payments
  static const String payments = '/payments';
  static String payment(String id) => '/payments/$id';

  // /api/v1/receipts
  static const String receipts = '/receipts';
  static String receipt(String id) => '/receipts/$id';
  static String receiptForPayment(String paymentId) =>
      '/receipts/by-payment/$paymentId';

  // /api/v1/documents
  static const String documents = '/documents';
  static String documentDownload(String id) => '/documents/$id/download-url';

  // /api/v1/notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationPreferences = '/notifications/preferences';

  // /api/v1/tenants
  static const String currentTenant = '/tenants/me';
  static const String tenantProfile = '/tenants/me/profile';

  // Tenant home screen (section 44)
  static const String dashboard = '/reports/tenant-dashboard';

  // /api/v1/owners (section 88)
  static const String currentOwner = '/owners/me';
  static const String ownerPortfolio = '/reports/owner-portfolio';
  static String ownerPropertyPerformance(String propertyId) =>
      '/reports/owner-property/$propertyId';
}
