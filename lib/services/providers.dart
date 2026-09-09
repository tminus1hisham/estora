import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/utils/idempotency_key.dart';
import '../domain/repositories/repositories.dart';
import '../storage/token_store.dart';
import '../storage/token_store_factory.dart';
import 'mock/mock_repositories.dart';
import 'mock/mock_server.dart';
import 'remote/api_client.dart';
import 'remote/remote_repositories.dart';
import 'update/app_update_service.dart';

/// Dependency wiring.
///
/// Every repository provider below reads [AppConfig.dataSource] and returns
/// either the in-memory mock or the HTTP client. That constant is the only
/// thing that has to change to point the whole app at a real backend — no
/// screen, controller or widget imports an implementation directly.

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

/// Overridden in `main()` once `SharedPreferences` has loaded, so the rest of
/// the graph can depend on it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => tokenStoreForPlatform(ref.watch(sharedPreferencesProvider)),
);

final idempotencyKeysProvider = Provider<IdempotencyKeys>(
  (ref) => IdempotencyKeys(ref.watch(sharedPreferencesProvider)),
);

/// The mock backend.
///
/// A single long-lived instance: it is standing in for a server, and a server
/// does not forget its state between screens. Only constructed when the mock
/// data source is selected.
final mockServerProvider = Provider<MockServer>((ref) => MockServer());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
);

/// Google Play's view of whether this build is the current one.
///
/// A provider rather than a static call so a test can override it with a
/// service that answers without a Play Store behind it.
final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => const AppUpdateService(),
);

/// The signed-in account, resolved once and shared.
///
/// Several published routes are keyed on the tenant's id or the account's
/// phone number. Rather than have each repository fetch the account for
/// itself, they share this one.
final accountIdentityProvider = Provider<AccountIdentity>(
  (ref) => AccountIdentity(ref.watch(apiClientProvider)),
);

/// Which implementation the repositories below resolve to.
///
/// Defaults to [AppConfig.dataSource], which is what the app ships with. It is
/// a provider rather than a direct read of the constant so that tests can pin
/// the mock without depending on how the app happens to be configured — a
/// widget test should not start making HTTP requests because a release switch
/// moved.
final dataSourceProvider = Provider<DataSource>((ref) => AppConfig.dataSource);

/// Whether the app is running on mock data.
///
/// The demo shortcuts on the sign-in screens are the visible consequence of
/// this: a list of accounts to sign in as, and the OTP the mock will accept.
/// Neither may ever appear in front of a real server, so they read this rather
/// than [AppConfig.isMock] — the same switch the repositories resolve through.
final isMockDataProvider = Provider<bool>(
  (ref) => ref.watch(dataSourceProvider) == DataSource.mock,
);

/// Chooses between the two implementations of a repository.
///
/// Written as a helper so each provider below reads as one line and the switch
/// itself appears in exactly one place.
T _pick<T>(Ref ref, T Function() mock, T Function() remote) =>
    ref.watch(dataSourceProvider) == DataSource.mock ? mock() : remote();

/// A repository the published contract does not serve yet.
///
/// These stay on the mock even when the rest of the app is live, so the
/// screens behind them keep working rather than failing on a route that does
/// not exist. Marked at every call site rather than hidden in a list, and
/// enumerated with the routes each one needs in `backend_requirement.md`.
///
/// The [Remote] implementations are kept, not deleted: they are written
/// against the shape these routes are expected to take, and become one line
/// each to switch on once the backend publishes them.
T _untilPublished<T>(T Function() mock) => mock();

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _pick(
    ref,
    () => MockAuthRepository(ref.watch(mockServerProvider)),
    () => RemoteAuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(tokenStoreProvider),
      ref.watch(accountIdentityProvider),
    ),
  ),
);

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => _pick(
    ref,
    () => MockPropertyRepository(ref.watch(mockServerProvider)),
    () => RemotePropertyRepository(ref.watch(apiClientProvider)),
  ),
);

final unitRepositoryProvider = Provider<UnitRepository>(
  (ref) => _pick(
    ref,
    () => MockUnitRepository(ref.watch(mockServerProvider)),
    () => RemoteUnitRepository(ref.watch(apiClientProvider)),
  ),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => _untilPublished(
    () => MockBookingRepository(ref.watch(mockServerProvider)),
  ),
);

final leaseRepositoryProvider = Provider<LeaseRepository>(
  (ref) =>
      _untilPublished(() => MockLeaseRepository(ref.watch(mockServerProvider))),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => _pick(
    ref,
    () => MockInvoiceRepository(ref.watch(mockServerProvider)),
    () => RemoteInvoiceRepository(
      ref.watch(apiClientProvider),
      ref.watch(accountIdentityProvider),
    ),
  ),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => _pick(
    ref,
    () => MockPaymentRepository(ref.watch(mockServerProvider)),
    () => RemotePaymentRepository(ref.watch(apiClientProvider)),
  ),
);

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => _untilPublished(
    () => MockReceiptRepository(ref.watch(mockServerProvider)),
  ),
);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => _untilPublished(
    () => MockDocumentRepository(ref.watch(mockServerProvider)),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _untilPublished(
    () => MockNotificationRepository(ref.watch(mockServerProvider)),
  ),
);

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => _untilPublished(
    () => MockTenantRepository(ref.watch(mockServerProvider)),
  ),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => _untilPublished(
    () => MockDashboardRepository(ref.watch(mockServerProvider)),
  ),
);

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) =>
      _untilPublished(() => MockOwnerRepository(ref.watch(mockServerProvider))),
);

/// Editing the shape of a property: its blocks and its individual units.
final propertyStructureRepositoryProvider =
    Provider<PropertyStructureRepository>(
      (ref) => _pick(
        ref,
        () => MockPropertyStructureRepository(ref.watch(mockServerProvider)),
        () => RemotePropertyStructureRepository(ref.watch(apiClientProvider)),
      ),
    );

/// Money as it actually arrived: M-Pesa callbacks and bank transfers.
final treasuryRepositoryProvider = Provider<TreasuryRepository>(
  (ref) => _pick(
    ref,
    () => MockTreasuryRepository(ref.watch(mockServerProvider)),
    () => RemoteTreasuryRepository(ref.watch(apiClientProvider)),
  ),
);

/// Accounts, roles and claims.
final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => _pick(
    ref,
    () => MockAccessRepository(ref.watch(mockServerProvider)),
    () => RemoteAccessRepository(ref.watch(apiClientProvider)),
  ),
);

/// The signed-in account's own credentials and verification state.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => _pick(
    ref,
    () => MockAccountRepository(ref.watch(mockServerProvider)),
    () => RemoteAccountRepository(
      ref.watch(apiClientProvider),
      ref.watch(accountIdentityProvider),
    ),
  ),
);
