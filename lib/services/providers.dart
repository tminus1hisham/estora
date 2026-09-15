import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/idempotency_key.dart';
import '../domain/repositories/repositories.dart';
import '../storage/token_store.dart';
import '../storage/token_store_factory.dart';
import 'remote/api_client.dart';
import 'remote/remote_repositories.dart';
import 'update/app_update_service.dart';

/// API-only dependency wiring. Tests override individual repositories.

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
  (ref) => RemoteLeaseRepository(ref.watch(apiClientProvider)),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => RemoteInvoiceRepository(
    ref.watch(apiClientProvider),
    ref.watch(accountIdentityProvider),
  ),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => RemotePaymentRepository(ref.watch(apiClientProvider)),
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

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => RemoteOwnerRepository(ref.watch(apiClientProvider)),
);

final propertyStructureRepositoryProvider =
    Provider<PropertyStructureRepository>(
      (ref) => RemotePropertyStructureRepository(ref.watch(apiClientProvider)),
    );

final treasuryRepositoryProvider = Provider<TreasuryRepository>(
  (ref) => RemoteTreasuryRepository(ref.watch(apiClientProvider)),
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
