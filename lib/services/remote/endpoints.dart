/// Endpoint paths, transcribed from the published contract in `api.md`
/// (Property Manager Api v1, `property-manager-api.transfa.org`).
///
/// Paths are relative; the host and the `/v1/api` prefix come from
/// `AppConfig.apiRoot`, so a version bump is one edit rather than sixty.
///
/// Two groups live here:
///
/// * **Published** — an operation the contract defines, named after its
///   `operationId` so a path can be traced back to the spec.
/// * **Unpublished** — a screen the app has that the contract does not serve
///   yet (documents, notifications, receipts, the tenant dashboard, the owner
///   reports). Those are grouped at the bottom and marked, so nobody mistakes
///   them for something the backend answers today. They use HTTP and report an error until the backend supports them.
library;

class Endpoints {
  const Endpoints._();

  // -- Auth ----------------------------------------------------------------
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String enableTwoFactor = '/auth/enable/two/factor';
  static const String verifyTwoFactor = '/auth/verify/two/factor';
  static const String refresh = '/auth/refresh/token';
  static const String confirmPhoneNumber = '/auth/confirm/phonenumber';
  static const String confirmEmail = '/auth/confirm/email';
  static const String forgotPassword = '/auth/forgot/password';
  static const String resetPassword = '/auth/reset/password';
  static const String changePassword = '/auth/change/password';
  static const String updateProfilePicture = '/auth/update/profile/picture';
  static const String users = '/auth/get/users';
  static const String updateUser = '/auth/update/user';
  static const String updateCustomUser = '/auth/custom/update/user';
  static const String enableDisableUser = '/auth/enable/disable/user';
  static const String account = '/auth/get/account';
  static const String updateUserName = '/auth/user/mobile/update';
  static String deleteUser(String id) => '/auth/delete/$id';

  /// The routes a caller reaches before a session exists.
  ///
  /// A 401 from one of these is the server's answer to the request itself —
  /// a password that was not accepted, an account it will not create — and
  /// not a token that has run out. `ApiClient` therefore neither refreshes
  /// nor signs out over them: there is nothing yet to refresh, and a mistyped
  /// password should not end the session of whoever was signed in before.
  ///
  /// Two-factor is deliberately absent. The contract's code flow assumes a
  /// caller who has already authenticated, so a 401 there *is* an expiry.
  static const Set<String> preSession = {
    register,
    login,
    refresh,
    forgotPassword,
    resetPassword,
    confirmEmail,
    confirmPhoneNumber,
  };

  // -- Payments ------------------------------------------------------------
  static const String bookUnit = '/payments/book/unit';
  static const String confirmBookedUnit = '/payments/confirm/booked/unit';
  static String tenantInvoices(String tenantId) =>
      '/payments/get/invoices/$tenantId';
  static const String createPaymentRequest = '/payments/create/payment/request';
  static const String deferInvoice = '/payments/defer/invoice';
  static const String settleInvoice = '/payments/settle/invoice';
  static const String mpesaPayments = '/payments/get/mpesa/payments';
  static const String mpesaPaymentByTransId =
      '/payments/get/mpesa/payment/by/trans/id';
  static const String createManualPayment = '/payments/create/manual/payment';
  static const String bankPayments = '/payments/get/bank/payments';
  static String deleteBankPayment(String id) =>
      '/payments/delete/bank/payment/$id';
  static const String updateBankPayment = '/payments/update/bank/payment';
  static const String updateMpesaAccountNumber =
      '/payments/update/mpesa/acc/no';

  // -- Properties ----------------------------------------------------------
  static const String properties = '/properties/get/all/properties';
  static String property(String id) => '/properties/get/property/$id';
  static const String createProperty = '/properties/create/property';
  static String deleteProperty(String id) => '/properties/delete/property/$id';
  static String restoreProperty(String id) =>
      '/properties/restore/property/$id';
  static String updateProperty(String id) => '/properties/update/property/$id';

  // -- Blocks --------------------------------------------------------------
  static String propertyBlocks(String propertyId) =>
      '/properties/get/all/blocks/$propertyId';
  static String block(String id) => '/properties/get/block/$id';
  static const String createBlock = '/properties/create/block';
  static String updateBlock(String id) => '/properties/update/block/$id';
  static String deleteBlock(String id) => '/properties/delete/block/$id';

  // -- Units ---------------------------------------------------------------
  //
  // The contract declares the two list routes without a separator before the
  // path parameter — `.../in/property{propertyId}` — so they are written the
  // same way here. Tidying them client-side would simply miss the route.
  static String propertyUnits(String propertyId) =>
      '/properties/get/all/units/in/property$propertyId';
  static String blockUnits(String blockId) =>
      '/properties/get/all/units/in/block$blockId';
  static String unit(String id) => '/properties/get/unit/$id';
  static const String createUnit = '/properties/create/unit';
  static String updateUnit(String id) => '/properties/update/unit/$id';
  static String deleteUnit(String id) => '/properties/delete/unit/$id';

  // -- Roles and claims ----------------------------------------------------
  static const String roles = '/roles/get/all/roles';
  static const String createRole = '/roles/create/role';
  static const String roleUsers = '/roles/get/all/users';
  static const String addUserToRole = '/roles/add/user/to/role';
  static const String userRoles = '/roles/get/user/roles';
  static const String removeUserFromRole = '/roles/remove/user/from/role';
  static const String userClaims = '/roles/get/all/claims';
  static const String addClaimToUser = '/roles/add/claims/to/user';
  static const String removeClaimFromUser = '/roles/remove/claim/from/user';
  static const String addClaimToRole = '/roles/add/claim/to/role';
  static const String roleClaims = '/roles/get/claims/for/role';
  static const String removeClaimFromRole = '/roles/remove/claim/from/role';

  // -- Not in the published contract ---------------------------------------
  //
  // Screens whose endpoints are still missing. These use HTTP too; failures
  // are shown to the user without substituting fabricated records.
  static const String leases = '/leases';
  static String lease(String id) => '/leases/$id';
  static String leaseAgreement(String id) => '/leases/$id/agreement';
  static String leaseSign(String id) => '/leases/$id/signatures';

  static const String bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';
  static String bookingCancel(String id) => '/bookings/$id/cancel';
  static String bookingQuote(String unitId) => '/bookings/quote/$unitId';
  static String bookingRequirement(String bookingId, String requirementId) =>
      '/bookings/$bookingId/requirements/$requirementId';

  static const String payments = '/payments';
  static String payment(String id) => '/payments/$id';

  static const String receipts = '/receipts';
  static String receipt(String id) => '/receipts/$id';
  static String receiptForPayment(String paymentId) =>
      '/receipts/by-payment/$paymentId';

  static const String documents = '/documents';
  static String documentDownload(String id) => '/documents/$id/download-url';

  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationPreferences = '/notifications/preferences';

  static const String currentTenant = '/tenants/me';
  static const String tenantProfile = '/tenants/me/profile';
  static const String dashboard = '/reports/tenant-dashboard';

  static const String currentOwner = '/owners/me';
  static const String ownerPortfolio = '/reports/owner-portfolio';
  static String ownerPropertyPerformance(String propertyId) =>
      '/reports/owner-property/$propertyId';
  static String ownerRepricingImpact(String propertyId) =>
      '/properties/$propertyId/rate/impact';
  static String ownerPropertyRate(String propertyId) =>
      '/properties/$propertyId/rate';
  static String ownerUnitRent(String unitId) => '/units/$unitId/rent';
  static String ownerRentRoll(String propertyId) =>
      '/properties/$propertyId/rent-roll';
  static const String ownerTenancies = '/owners/me/tenancies';
  static String ownerTenancy(String leaseId) => '/owners/me/tenancies/$leaseId';
  static const String ownerLedger = '/reports/owner-ledger';

  static String unitPricing(String id) => '/units/$id/pricing';
  static String propertyUnitTypes(String id) => '/properties/$id/unit-types';
  static String buildingFloors(String id) => '/buildings/$id/floors';
}
