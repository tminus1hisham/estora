/// Application-wide configuration.
///
/// The single most important switch here is [dataSource]. Every repository has
/// two implementations: an in-memory mock that simulates the server, and a Dio
/// backed HTTP client speaking the published Property Manager API contract in
/// `api.md`. Flipping [dataSource] swaps the whole app over.
library;

/// Where repository implementations read their data from.
enum DataSource {
  /// In-memory implementations seeded from the worked example in section 80.
  /// The mock deliberately simulates *server* behaviour (fee calculation,
  /// reference generation, idempotency replay, payment state transitions) so
  /// that no presentation code has to.
  mock,

  /// Dio-backed implementations that talk to [AppConfig.apiBaseUrl].
  remote,
}

class AppConfig {
  const AppConfig._();

  /// The app runs against the live API.
  ///
  /// The contract does not cover every screen this app ships. Rather than let
  /// those screens fail, the repositories behind them stay on the mock even
  /// here — see `providers.dart`, where each one is marked, and
  /// `backend_requirement.md`, which lists the routes they are waiting on.
  /// Everything else talks to [apiBaseUrl].
  static const DataSource dataSource = DataSource.remote;

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

  /// How often the payment status screen re-checks the server while a payment
  /// is in a non-terminal state. Section 39 forbids trusting the handset's own
  /// view of the outcome, so the client polls rather than assuming success.
  static const Duration paymentPollInterval = Duration(seconds: 3);

  /// Give up automatic polling after this long and fall back to telling the
  /// tenant they will be notified. The payment itself is unaffected.
  static const Duration paymentPollTimeout = Duration(minutes: 3);

  /// Artificial latency for the mock data source, so loading and error states
  /// are actually exercised during development.
  static const Duration mockLatency = Duration(milliseconds: 350);

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

  static bool get isMock => dataSource == DataSource.mock;
}
