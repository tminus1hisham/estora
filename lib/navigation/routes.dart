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

  // -- Shell tabs (section 45) ----------------------------------------------
  static const home = 'home';
  static const homePath = '/home';

  static const browse = 'browse';
  static const browsePath = '/browse';

  static const leases = 'leases';
  static const leasesPath = '/leases';

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

  static const ownerAddProperty = 'owner-add-property';
  static const ownerAddPropertyPath = 'new';

  static const ownerPropertyRate = 'owner-property-rate';
  static const ownerPropertyRatePath = ':propertyId/rate';

  static const ownerRentRoll = 'owner-rent-roll';
  static const ownerRentRollPath = ':propertyId/rent-roll';

  static const ownerTenancy = 'owner-tenancy';
  static const ownerTenancyPath = ':leaseId';

  static const ownerPayouts = 'owner-payouts';
  static const ownerPayoutsPath = 'payouts';

  // -- Browse sub-routes ----------------------------------------------------
  static const propertyDetail = 'property-detail';
  static const propertyDetailPath = 'property/:propertyId';

  static const availableUnits = 'available-units';
  static const availableUnitsPath = 'property/:propertyId/units';

  static const unitDetail = 'unit-detail';
  static const unitDetailPath = 'unit/:unitId';

  static const booking = 'booking';
  static const bookingPath = 'unit/:unitId/book';

  static const bookingStatus = 'booking-status';
  static const bookingStatusPath = 'booking/:bookingId';

  static const bookings = 'bookings';
  static const bookingsPath = 'bookings';

  // -- Lease sub-routes -----------------------------------------------------
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

  static const editProfile = 'edit-profile';
  static const editProfilePath = 'edit';

  // -- Reachable from the home tab ------------------------------------------
  static const notifications = 'notifications';
  static const notificationsPath = 'notifications';

  static const currentProperty = 'current-property';
  static const currentPropertyPath = 'property/:leaseId';
}
