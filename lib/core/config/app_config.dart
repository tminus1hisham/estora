/// Application-wide API configuration.
class AppConfig {
  const AppConfig._();

  /// Base URL of the Property Manager API.
  ///
  /// Override at build time:
  /// `flutter run --dart-define=API_BASE_URL=https://staging.example.com`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://property-manager-api.transfa.org',
  );

  /// The contract versions ahead of the `api` segment, not after it —
  /// `/v1/api/auth/login`, not `/api/v1/auth/login`.
  static const String apiVersion = 'v1';

  static String get apiRoot => '$apiBaseUrl/$apiVersion/api';

  /// Serves the Money, Leases and Invoices screens from fixtures in
  /// `lib/services/demo/` instead of the API.
  ///
  /// Off in every ordinary build. Turn it on for a design review or a
  /// screenshot run:
  /// `flutter run --dart-define=DEMO_DATA=true`
  ///
  /// The contract publishes no route for leases or the owner ledger, so
  /// those two screens can only ever show their "on its way" state against
  /// the live server; this is the one way to see them with figures on them.
  /// Everything else — sign-in, properties, units, payments — still goes to
  /// the API, and the fixtures never reach a build that does not ask for
  /// them.
  static const bool demoData = bool.fromEnvironment('DEMO_DATA');

  /// Whether the owner's account page lists the People and Roles screens.
  /// Hidden for now; the routes themselves stay registered, so flipping this
  /// back on is the whole change.
  static const bool showAdministration = false;

  /// How often the payment status screen re-checks the server while a payment
  /// is in a non-terminal state. Section 39 forbids trusting the handset's own
  /// view of the outcome, so the client polls rather than assuming success.
  static const Duration paymentPollInterval = Duration(seconds: 3);

  /// Give up automatic polling after this long and fall back to telling the
  /// tenant they will be notified. The payment itself is unaffected.
  static const Duration paymentPollTimeout = Duration(minutes: 3);

  // -------------------------------------------------------------------------
  // Google Play in-app updates
  // -------------------------------------------------------------------------

  /// The in-app update priority at or above which a release stops being
  /// optional and Play is asked to install it before the tenant goes any
  /// further.
  ///
  /// Priority is 0-5 and is a property of the *release*, not of this build:
  /// it can only be set through the Play Developer API at publish time
  /// (`inAppUpdatePriority` on the edit), never in the Play Console UI, and it
  /// cannot be changed afterwards. Releases published without it arrive here
  /// as 0. Reserve 4 and 5 for builds that fix something a tenant would lose
  /// money over — a broken payment or invoice figure.
  static const int blockingUpdatePriority = 4;

  /// How long a handset may keep declining an available update before it is
  /// required rather than offered.
  ///
  /// Play counts these days itself, from the moment the Play Store on that
  /// device first learned about the release — not from when this app first
  /// asked. Two weeks leaves room for a tenant who only opens the app on rent
  /// day to see the offer at least once before it becomes a block.
  static const int forcedUpdateStalenessDays = 14;
}
