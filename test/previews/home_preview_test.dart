import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/dashboard_summary.dart';
import 'package:estora/domain/entities/tenant.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/auth/application/auth_controller.dart';
import 'package:estora/modules/home/application/dashboard_controller.dart';
import 'package:estora/modules/home/presentation/home_screen.dart';
import 'package:estora/modules/notifications/application/notification_controller.dart';

import '../support/preview_capture.dart';

const _user = AppUser(
  id: 'usr_preview',
  firstName: 'Amina',
  lastName: 'Wanjiru',
  email: 'amina@example.co.ke',
  phone: '+254712345678',
  status: 'ACTIVE',
  emailVerified: true,
  phoneVerified: true,
);

const _tenant = Tenant(
  id: 'tnt_preview',
  userId: 'usr_preview',
  tenantType: TenantType.business,
  displayName: 'Wanjiru Retail Ltd',
  status: 'ACTIVE',
);

final _summary = DashboardSummary(
  currency: 'KES',
  outstandingBalance: const Money(15000000, 'KES'),
  recentPayments: const [],
  unreadNotifications: 3,
  propertyId: 'prp_sarit',
  propertyName: 'Sarit Mall',
  propertyImageUrl: 'assets/images/property_sarit_mall.jpg',
  unitId: 'unt_shop_101',
  unitNumber: 'SHOP-101',
  leaseId: 'lse_active',
  leaseStatus: LeaseStatus.active,
  leaseEndDate: DateTime.now().add(const Duration(days: 240)),
  nextInvoiceAmount: const Money(15000000, 'KES'),
  nextPaymentDueDate: DateTime.now().add(const Duration(days: 12)),
);

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthState(
    stage: AuthStage.authenticated,
    session: AuthSession(user: _user, tenant: _tenant),
  );
}

class _Dashboard extends DashboardController {
  @override
  Future<DashboardSummary> build() async => _summary;
}

void main() {
  setUpAll(loadPreviewFonts);

  for (final (name, dark, scale, scroll) in [
    ('light', false, 1.0, 0.0),
    ('dark', true, 1.0, 0.0),
    ('light-scrolled', false, 1.0, 420.0),
    ('dark-scrolled', true, 1.0, 420.0),
    ('light-text1.6', false, 1.6, 700.0),
  ]) {
    testWidgets('tenant home preview ($name)', (tester) async {
      usePhoneViewport(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const key = ValueKey('home-preview');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_Auth.new),
            dashboardControllerProvider.overrideWith(_Dashboard.new),
            unreadNotificationCountProvider.overrideWith((ref) async => 3),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: const RepaintBoundary(key: key, child: HomeScreen()),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/property_sarit_mall.jpg'),
          tester.element(find.byType(HomeScreen)),
        ),
      );
      await tester.pumpAndSettle();
      if (scroll > 0) {
        await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await capturePreview(tester, key, 'home-$name');
    });
  }
}
