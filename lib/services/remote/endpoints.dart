/// Endpoint paths, transcribed from the published contract in `api.md`
/// (Property Manager Api v1, `property-manager-api.transfa.org`).
///
/// Paths are relative; the host and the `/v1/api` prefix come from
/// `AppConfig.apiRoot`, so a version bump is one edit rather than sixty.
///
/// Only operations defined in `api.md` belong here.
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
  static const String enquireUnit = '/payments/enquire/unit';
  static const String confirmBookedUnit = '/payments/confirm/booked/unit';

  /// The bookings the caller may see. Whose they are is the server's call:
  /// the route takes no parameter, and the app does not second-guess it.
  ///
  /// `enqueries` is the contract's spelling, kept as published: a corrected
  /// path would simply miss the route.
  static const String allEnquiries = '/payments/get/all/enqueries';
  static String unitBookings(String unitId) =>
      '/payments/get/bookings/unit/$unitId';
  static String tenantInvoices(String tenantId) =>
      '/payments/get/invoices/$tenantId';
  static String unitInvoices(String unitId) =>
      '/payments/get/invoices/unit/$unitId';
  static String blockInvoices(String blockId) =>
      '/payments/get/invoices/block/$blockId';
  static String propertyInvoices(String propertyId) =>
      '/payments/get/invoices/property/$propertyId';
  static const String createPaymentRequest = '/payments/create/payment/request';
  static const String deferInvoice = '/payments/defer/invoice';
  static const String settleInvoice = '/payments/settle/invoice';
  static const String mpesaPayments = '/payments/get/mpesa/payments';
  static const String mpesaPaymentByTransId =
      '/payments/get/mpesa/payment/by/trans/id';
  static String mpesaPaymentsByUnit(String unitId) =>
      '/payments/get/mpesa/payment/by/unit/$unitId';
  static String mpesaPaymentsByBlock(String blockId) =>
      '/payments/get/mpesa/payment/by/block/$blockId';
  static String mpesaPaymentsByProperty(String propertyId) =>
      '/payments/get/mpesa/payment/by/property/$propertyId';

  /// Every M-Pesa arrival across the properties the caller owns. Whose they
  /// are is the server's call from the bearer token; the route takes nothing.
  static const String ownerReport = '/payments/get/owner/report';
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

  /// The server's availability engine, asked across the whole platform.
  ///
  /// It answers with blocks that have bookable stock and the sizes on offer in
  /// each, not with unit records — see `unitAvailabilityFromJson`. It takes no
  /// parameters and no bearer token.
  static const String availableUnitsToBook =
      '/properties/available/units/to/book';
  static const String createUnit = '/properties/create/unit';
  static String updateUnit(String id) => '/properties/update/unit/$id';
  static String deleteUnit(String id) => '/properties/delete/unit/$id';

  // -- Tenants -------------------------------------------------------------

  /// The tenant directory. Each record carries its own `id` — the id the
  /// invoice route is keyed on — beside the `userId` of the account that
  /// signs in as it; see [AccountIdentity.tenantId].
  static const String tenants = '/properties/get/all/tenants';

  // -- Leases --------------------------------------------------------------

  /// The caller's lease agreements. The route takes no parameter: whose
  /// leases come back is the server's decision, made from the bearer token,
  /// the same way [allEnquiries] and [ownerReport] work.
  static const String leaseAgreements = '/properties/get/lease/agreements';

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
}
