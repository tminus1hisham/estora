import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/utils/idempotency_key.dart';
import '../domain/repositories/repositories.dart';
import '../storage/token_store.dart';
import '../storage/token_store_factory.dart';
import 'demo/demo_fixtures.dart';
import 'demo/demo_repositories.dart';
import 'remote/api_client.dart';
import 'remote/remote_repositories.dart';
import 'update/app_update_service.dart';

/// API-only dependency wiring. Tests override individual repositories.
///
/// The one exception is `--dart-define=DEMO_DATA=true`, which puts fixtures
/// behind Money (with its M-Pesa and bank payment screens), Leases and
/// Invoices — and nothing else. See [AppConfig.demoData].

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

/// Ticks each time [ApiClient] gives up on a session: the server refused to
/// renew the token, and the tokens are already gone from the store.
///
/// The auth controller listens and moves the app to the sign-in screen. It
/// lives here, below the modules, so that the transport can raise it without
/// knowing who is listening. A count rather than a flag, so a second loss in
/// the same process — sign in again, lose that session too — notifies too.
final sessionLostProvider = NotifierProvider<SessionLostNotifier, int>(
  SessionLostNotifier.new,
);

class SessionLostNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    onAuthLost: () => ref.read(sessionLostProvider.notifier).notify(),
  ),
);

/// One set of fixtures for the life of the app, so a deferral or a signature
/// made on one screen is still there when the next screen reads.
///
/// Only ever read when [AppConfig.demoData] is set.
final demoFixturesProvider = Provider<DemoFixtures>((ref) => DemoFixtures());

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
  (ref) => AccountIdentity(
    ref.watch(apiClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => RemoteAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(accountIdentityProvider),
  ),
);

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => RemotePropertyRepository(ref.watch(apiClientProvider)),
);

final unitRepositoryProvider = Provider<UnitRepository>(
  (ref) => RemoteUnitRepository(ref.watch(apiClientProvider)),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => RemoteBookingRepository(ref.watch(apiClientProvider)),
);

final leaseRepositoryProvider = Provider<LeaseRepository>(
  (ref) => AppConfig.demoData
      ? DemoLeaseRepository(ref.watch(demoFixturesProvider))
      : RemoteLeaseRepository(
          ref.watch(apiClientProvider),
          ref.watch(accountIdentityProvider),
        ),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => AppConfig.demoData
      ? DemoInvoiceRepository(ref.watch(demoFixturesProvider))
      : RemoteInvoiceRepository(
          ref.watch(apiClientProvider),
          ref.watch(accountIdentityProvider),
        ),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => RemotePaymentRepository(
    ref.watch(apiClientProvider),
    ref.watch(accountIdentityProvider),
  ),
);

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => RemoteReceiptRepository(ref.watch(apiClientProvider)),
);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => RemoteDocumentRepository(ref.watch(apiClientProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => RemoteNotificationRepository(ref.watch(apiClientProvider)),
);

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => RemoteTenantRepository(ref.watch(apiClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => RemoteDashboardRepository(ref.watch(apiClientProvider)),
);

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  final remote = RemoteOwnerRepository(ref.watch(apiClientProvider));
  return AppConfig.demoData
      ? DemoOwnerRepository(ref.watch(demoFixturesProvider), remote)
      : remote;
});

final propertyStructureRepositoryProvider =
    Provider<PropertyStructureRepository>(
      (ref) => RemotePropertyStructureRepository(ref.watch(apiClientProvider)),
    );

final treasuryRepositoryProvider = Provider<TreasuryRepository>(
  (ref) => AppConfig.demoData
      ? DemoTreasuryRepository(ref.watch(demoFixturesProvider))
      : RemoteTreasuryRepository(ref.watch(apiClientProvider)),
);

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => RemoteSupportRepository(
    ref.watch(apiClientProvider),
    ref.watch(accountIdentityProvider),
  ),
);

final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => RemoteAccessRepository(ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => RemoteAccountRepository(
    ref.watch(apiClientProvider),
    ref.watch(accountIdentityProvider),
  ),
);
