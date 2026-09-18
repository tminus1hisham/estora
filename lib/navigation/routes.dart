/// Route names and paths.
///
/// Names are used for navigation (`context.goNamed`) so a path change does not
/// mean editing every call site; paths are here so deep links stay readable.
class Routes {
  const Routes._();

  // -- Auth (section 77) ----------------------------------------------------
  static const splash = 'splash';
  static const splashPath = '/';

  static const login = 'login';
  static const loginPath = '/login';

  static const register = 'register';
  static const registerPath = '/register';

  static const otp = 'otp';
  static const otpPath = '/otp';

  static const forgotPassword = 'forgot-password';
  static const forgotPasswordPath = '/forgot-password';

  /// Finishes the reset begun on [forgotPassword], with the token that was
  /// sent. Reachable without a session — whoever is here could not sign in,
  /// which is the whole reason they are here.
  static const resetPassword = 'reset-password';
  static const resetPasswordPath = '/reset-password';

  // -- Shell tabs (section 45) ----------------------------------------------
  static const home = 'home';
  static const homePath = '/home';

  static const browse = 'browse';
  static const browsePath = '/browse';

  static const bookings = 'bookings';
  static const bookingsPath = '/bookings';

  static const invoices = 'invoices';
  static const invoicesPath = '/invoices';

  static const profile = 'profile';
  static const profilePath = '/profile';

  // -- Owner shell (section 88) ---------------------------------------------
  //
  // Every branch root gets its own segment rather than one of them sitting at
  // a bare `/owner`. Sibling branches under a shared parent path match by
  // accident — `/owner/properties` would be tried against the `/owner` branch
  // first — and the resulting bug looks like a rendering fault, not a routing
  // one. `/owner` itself redirects to the portfolio.
  static const ownerRootPath = '/owner';

  static const ownerPortfolio = 'owner-portfolio';
  static const ownerPortfolioPath = '/owner/portfolio';

  static const ownerProperties = 'owner-properties';
  static const ownerPropertiesPath = '/owner/properties';

  static const ownerTenancies = 'owner-tenancies';
  static const ownerTenanciesPath = '/owner/tenancies';

  static const ownerMoney = 'owner-money';
  static const ownerMoneyPath = '/owner/money';

  static const ownerAccount = 'owner-account';
  static const ownerAccountPath = '/owner/account';

  // -- Owner sub-routes -----------------------------------------------------
  static const ownerProperty = 'owner-property';
  static const ownerPropertyPath = ':propertyId';

  /// The tenant's own property screen, shown to the owner as a preview.
  ///
  /// Lives under `/owner` rather than pointing at `/browse/property/:id`
  /// because the redirect keeps an owner out of tenant space — sending them
  /// there would bounce them straight back to the portfolio. Presented on the
  /// root navigator, so it arrives without the owner tab bar and in the
  /// tenant's own theme, which is the point of a preview.
  static const ownerPreview = 'owner-preview';
  static const ownerPreviewPath = 'preview/:propertyId';

  static const ownerPropertyRate = 'owner-property-rate';
  static const ownerPropertyRatePath = ':propertyId/rate';

  static const ownerRentRoll = 'owner-rent-roll';
  static const ownerRentRollPath = ':propertyId/rent-roll';

  static const ownerTenancy = 'owner-tenancy';
  static const ownerTenancyPath = ':leaseId';

  /// A tenant's invoices, read from the landlord's side. Keyed on the tenant
  /// rather than the lease, because that is what the contract's invoice route
  /// is keyed on.
  static const tenantInvoices = 'tenant-invoices';
  static const tenantInvoicesPath = 'tenant/:tenantId/invoices';

  /// The tenant's read-only agreement screen, reached from the owner's side.
  ///
  /// Under `/owner` for the same reason as [ownerPreview]: the redirect keeps
  /// an owner out of `/profile/leases`, so linking there would bounce them home.
  static const ownerAgreement = 'owner-agreement';
  static const ownerAgreementPath = 'agreement/:leaseId';

  static const ownerPayouts = 'owner-payouts';
  static const ownerPayoutsPath = 'payouts';

  // -- Property structure ---------------------------------------------------
  //
  // Blocks and units, under the properties branch. A block's own routes are
  // keyed on the block rather than nested under its property: a block already
  // knows which property it belongs to, and repeating that in the path would
  // mean every link needed both ids to hand.

  static const blocks = 'blocks';
  static const blocksPath = ':propertyId/blocks';

  static const blockDetail = 'block-detail';
  static const blockDetailPath = 'block/:blockId';

  static const blockEdit = 'block-edit';
  static const blockEditPath = 'block/:blockId/edit';

  static const unitEdit = 'unit-edit';
  static const unitEditPath = 'unit/:unitId/edit';

  // -- Treasury (under the money tab) ---------------------------------------
  static const mpesaTransactions = 'mpesa-transactions';
  static const mpesaTransactionsPath = 'mpesa';

  static const bankPayments = 'bank-payments';
  static const bankPaymentsPath = 'bank';

  static const bankPaymentEdit = 'bank-payment-edit';
  static const bankPaymentEditPath = 'bank/:paymentId';

  // -- Access control (under the owner account tab) -------------------------
  static const accessUsers = 'access-users';
  static const accessUsersPath = 'users';

  static const accessUser = 'access-user';
  static const accessUserPath = 'users/:phoneNumber';

  static const accessRoles = 'access-roles';
  static const accessRolesPath = 'roles';

  static const accessRole = 'access-role';
  static const accessRolePath = 'roles/:roleName';

  // -- Browse sub-routes ----------------------------------------------------
  static const propertyDetail = 'property-detail';
  static const propertyDetailPath = 'property/:propertyId';

  /// The spaces the availability engine lists for one property.
  static const availableUnits = 'available-units';
  static const availableUnitsPath = 'property/:propertyId/units';

  static const unitDetail = 'unit-detail';
  static const unitDetailPath = 'unit/:unitId';

  /// Booking is keyed the way the contract keys it: a property and a block,
  /// with the size wanted as `?size=`. There is no unit in the address
  /// because the engine names none and the server allocates one.
  static const booking = 'booking';
  static const bookingPath = 'property/:propertyId/block/:blockId/book';
  static const bookingSizeQuery = 'size';

  static const bookingStatus = 'booking-status';
  static const bookingStatusPath = 'booking/:bookingId';

  // -- Lease sub-routes -----------------------------------------------------
  //
  // Under the profile tab. The bottom bar carries bookings, not the lease: a
  // booking is the thing a tenant checks on daily while it is live, whereas a
  // signed lease is read once and then kept. Everything below nests under
  // [leases], so a lease id never has to be resolved from anywhere else.
  static const leases = 'leases';
  static const leasesPath = 'leases';

  static const leaseDetail = 'lease-detail';
  static const leaseDetailPath = ':leaseId';

  static const leaseAgreement = 'lease-agreement';
  static const leaseAgreementPath = ':leaseId/agreement';

  static const signAgreement = 'sign-agreement';
  static const signAgreementPath = ':leaseId/sign';

  // -- Finance sub-routes ---------------------------------------------------
  static const invoiceDetail = 'invoice-detail';
  static const invoiceDetailPath = ':invoiceId';

  static const payment = 'payment';
  static const paymentPath = ':invoiceId/pay';

  static const paymentStatus = 'payment-status';
  static const paymentStatusPath = 'payment/:paymentId';

  static const receipt = 'receipt';
  static const receiptPath = 'receipt/:receiptId';

  // -- Account sub-routes ---------------------------------------------------
  static const paymentHistory = 'payment-history';
  static const paymentHistoryPath = 'payments';

  static const documents = 'documents';
  static const documentsPath = 'documents';

  static const settings = 'settings';
  static const settingsPath = 'settings';

  /// Everything to do with credentials, gathered in one place: the password,
  /// two-factor authentication, and confirming the email and phone number on
  /// the account.
  static const security = 'security';
  static const securityPath = 'security';

  static const changePassword = 'change-password';
  static const changePasswordPath = 'security/password';

  /// `channel` is `email` or `phone`.
  static const verifyContact = 'verify-contact';
  static const verifyContactPath = 'security/verify/:channel';

  // -- Paying an invoice another way ----------------------------------------
  static const bankTransfer = 'bank-transfer';
  static const bankTransferPath = ':invoiceId/bank-transfer';

  static const deferInvoice = 'defer-invoice';
  static const deferInvoicePath = ':invoiceId/defer';

  static const editProfile = 'edit-profile';
  static const editProfilePath = 'edit';

  // -- Reachable from the home tab ------------------------------------------
  static const notifications = 'notifications';
  static const notificationsPath = 'notifications';

  static const currentProperty = 'current-property';
  static const currentPropertyPath = 'property/:leaseId';
}
