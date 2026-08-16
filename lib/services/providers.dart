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

/// Chooses between the two implementations of a repository.
///
/// Written as a helper so each provider below reads as one line and the switch
/// itself appears in exactly one place.
T _pick<T>(Ref ref, T Function() mock, T Function() remote) =>
    AppConfig.isMock ? mock() : remote();

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
  (ref) => _pick(
    ref,
    () => MockBookingRepository(ref.watch(mockServerProvider)),
    () => RemoteBookingRepository(ref.watch(apiClientProvider)),
  ),
);

final leaseRepositoryProvider = Provider<LeaseRepository>(
  (ref) => _pick(
    ref,
    () => MockLeaseRepository(ref.watch(mockServerProvider)),
    () => RemoteLeaseRepository(ref.watch(apiClientProvider)),
  ),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => _pick(
    ref,
    () => MockInvoiceRepository(ref.watch(mockServerProvider)),
    () => RemoteInvoiceRepository(ref.watch(apiClientProvider)),
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
  (ref) => _pick(
    ref,
    () => MockReceiptRepository(ref.watch(mockServerProvider)),
    () => RemoteReceiptRepository(ref.watch(apiClientProvider)),
  ),
);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => _pick(
    ref,
    () => MockDocumentRepository(ref.watch(mockServerProvider)),
    () => RemoteDocumentRepository(ref.watch(apiClientProvider)),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _pick(
    ref,
    () => MockNotificationRepository(ref.watch(mockServerProvider)),
    () => RemoteNotificationRepository(ref.watch(apiClientProvider)),
  ),
);

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => _pick(
    ref,
    () => MockTenantRepository(ref.watch(mockServerProvider)),
    () => RemoteTenantRepository(ref.watch(apiClientProvider)),
  ),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => _pick(
    ref,
    () => MockDashboardRepository(ref.watch(mockServerProvider)),
    () => RemoteDashboardRepository(ref.watch(apiClientProvider)),
  ),
);

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => _pick(
    ref,
    () => MockOwnerRepository(ref.watch(mockServerProvider)),
    () => RemoteOwnerRepository(ref.watch(apiClientProvider)),
  ),
);
