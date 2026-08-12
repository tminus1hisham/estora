/// Application-wide configuration.
///
/// The single most important switch here is [dataSource]. The spec (section 64)
/// defines a REST API that does not exist yet, so every repository has two
/// implementations: an in-memory mock that simulates the server, and a Dio
/// backed HTTP client. Flipping [dataSource] swaps the whole app over.
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

  /// Swap to [DataSource.remote] once the backend from section 89 exists.
  static const DataSource dataSource = DataSource.mock;

  /// Base URL for the versioned API described in section 64.
  ///
  /// Override at build time:
  /// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// All endpoints are versioned (section 65).
  static const String apiVersion = 'v1';

  static String get apiRoot => '$apiBaseUrl/api/$apiVersion';

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

  static bool get isMock => dataSource == DataSource.mock;
}
