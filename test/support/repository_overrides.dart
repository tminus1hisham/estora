import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mall/services/providers.dart';
import 'mock/mock_server.dart';
import 'mock/mock_repositories.dart';

final mockServerProvider = Provider<MockServer>((ref) => MockServer());

// Explicit test fixtures; production has no mock data source.
final mockRepositoryOverrides = [
  authRepositoryProvider.overrideWith(
    (ref) => MockAuthRepository(ref.watch(mockServerProvider)),
  ),
  propertyRepositoryProvider.overrideWith(
    (ref) => MockPropertyRepository(ref.watch(mockServerProvider)),
  ),
  unitRepositoryProvider.overrideWith(
    (ref) => MockUnitRepository(ref.watch(mockServerProvider)),
  ),
  bookingRepositoryProvider.overrideWith(
    (ref) => MockBookingRepository(ref.watch(mockServerProvider)),
  ),
  leaseRepositoryProvider.overrideWith(
    (ref) => MockLeaseRepository(ref.watch(mockServerProvider)),
  ),
  invoiceRepositoryProvider.overrideWith(
    (ref) => MockInvoiceRepository(ref.watch(mockServerProvider)),
  ),
  paymentRepositoryProvider.overrideWith(
    (ref) => MockPaymentRepository(ref.watch(mockServerProvider)),
  ),
  receiptRepositoryProvider.overrideWith(
    (ref) => MockReceiptRepository(ref.watch(mockServerProvider)),
  ),
  documentRepositoryProvider.overrideWith(
    (ref) => MockDocumentRepository(ref.watch(mockServerProvider)),
  ),
  notificationRepositoryProvider.overrideWith(
    (ref) => MockNotificationRepository(ref.watch(mockServerProvider)),
  ),
  tenantRepositoryProvider.overrideWith(
    (ref) => MockTenantRepository(ref.watch(mockServerProvider)),
  ),
  dashboardRepositoryProvider.overrideWith(
    (ref) => MockDashboardRepository(ref.watch(mockServerProvider)),
  ),
  ownerRepositoryProvider.overrideWith(
    (ref) => MockOwnerRepository(ref.watch(mockServerProvider)),
  ),
  propertyStructureRepositoryProvider.overrideWith(
    (ref) => MockPropertyStructureRepository(ref.watch(mockServerProvider)),
  ),
  treasuryRepositoryProvider.overrideWith(
    (ref) => MockTreasuryRepository(ref.watch(mockServerProvider)),
  ),
  accessRepositoryProvider.overrideWith(
    (ref) => MockAccessRepository(ref.watch(mockServerProvider)),
  ),
  accountRepositoryProvider.overrideWith(
    (ref) => MockAccountRepository(ref.watch(mockServerProvider)),
  ),
];
