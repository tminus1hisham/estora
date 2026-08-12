import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/billing.dart';
import '../modules/auth/application/auth_controller.dart';
import '../modules/auth/presentation/forgot_password_screen.dart';
import '../modules/auth/presentation/login_screen.dart';
import '../modules/auth/presentation/otp_screen.dart';
import '../modules/auth/presentation/register_screen.dart';
import '../modules/auth/presentation/splash_screen.dart';
import '../modules/bookings/presentation/booking_screen.dart';
import '../modules/bookings/presentation/booking_status_screen.dart';
import '../modules/bookings/presentation/bookings_screen.dart';
import '../modules/documents/presentation/documents_screen.dart';
import '../modules/home/presentation/home_screen.dart';
import '../modules/invoices/presentation/invoice_detail_screen.dart';
import '../modules/invoices/presentation/invoices_screen.dart';
import '../modules/leases/presentation/lease_agreement_screen.dart';
import '../modules/leases/presentation/lease_detail_screen.dart';
import '../modules/leases/presentation/leases_screen.dart';
import '../modules/leases/presentation/sign_agreement_screen.dart';
import '../modules/notifications/presentation/notifications_screen.dart';
import '../modules/payments/presentation/payment_history_screen.dart';
import '../modules/payments/presentation/payment_screen.dart';
import '../modules/payments/presentation/payment_status_screen.dart';
import '../modules/payments/presentation/receipt_screen.dart';
import '../modules/profile/presentation/edit_profile_screen.dart';
import '../modules/profile/presentation/profile_screen.dart';
import '../modules/profile/presentation/settings_screen.dart';
import '../modules/properties/presentation/properties_screen.dart';
import '../modules/properties/presentation/property_detail_screen.dart';
import '../modules/units/presentation/available_units_screen.dart';
import '../modules/units/presentation/unit_detail_screen.dart';
import 'app_shell.dart';
import 'page_transitions.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  // A ValueNotifier bridges Riverpod's auth state to go_router's
  // refreshListenable, so a sign-in or sign-out re-evaluates the redirect
  // immediately rather than on the next navigation.
  final authState = ValueNotifier<AuthStage>(AuthStage.unknown);
  ref.listen(authControllerProvider, (previous, next) {
    authState.value = next.stage;
  }, fireImmediately: true);
  ref.onDispose(authState.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splashPath,
    refreshListenable: authState,
    redirect: (context, state) {
      final stage = ref.read(authControllerProvider).stage;
      final location = state.matchedLocation;
      final isAuthRoute =
          location == Routes.splashPath ||
          location == Routes.loginPath ||
          location == Routes.registerPath ||
          location == Routes.otpPath ||
          location == Routes.forgotPasswordPath;

      // While the stored session is still being read, hold on the splash
      // screen. Redirecting to login here would flash it at a signed-in tenant
      // on every launch.
      if (stage == AuthStage.unknown) {
        return location == Routes.splashPath ? null : Routes.splashPath;
      }

      if (stage == AuthStage.unauthenticated) {
        return isAuthRoute && location != Routes.splashPath
            ? null
            : Routes.loginPath;
      }

      // Signed in: keep them out of the auth screens.
      return isAuthRoute ? Routes.homePath : null;
    },
    routes: [
      // -- Auth (section 77) -------------------------------------------------
      GoRoute(
        path: Routes.splashPath,
        name: Routes.splash,
        pageBuilder: (_, state) =>
            fadePage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: Routes.loginPath,
        name: Routes.login,
        pageBuilder: (_, state) =>
            fadePage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: Routes.registerPath,
        name: Routes.register,
        pageBuilder: (_, state) =>
            fadePage(state: state, child: const RegisterScreen()),
      ),
      GoRoute(
        path: Routes.otpPath,
        name: Routes.otp,
        pageBuilder: (_, state) =>
            fadePage(state: state, child: const OtpScreen()),
      ),
      GoRoute(
        path: Routes.forgotPasswordPath,
        name: Routes.forgotPassword,
        pageBuilder: (_, state) =>
            fadePage(state: state, child: const ForgotPasswordScreen()),
      ),

      // -- Main shell (section 45) ------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homePath,
                name: Routes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: Routes.notificationsPath,
                    name: Routes.notifications,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const NotificationsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.currentPropertyPath,
                    name: Routes.currentProperty,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: LeaseDetailScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Browse: the pre-tenancy journey from section 77's Main group.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.browsePath,
                name: Routes.browse,
                builder: (_, _) => const PropertiesScreen(),
                routes: [
                  GoRoute(
                    path: Routes.propertyDetailPath,
                    name: Routes.propertyDetail,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: PropertyDetailScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.availableUnitsPath,
                    name: Routes.availableUnits,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: AvailableUnitsScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.unitDetailPath,
                    name: Routes.unitDetail,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: UnitDetailScreen(
                        unitId: state.pathParameters['unitId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.bookingPath,
                    name: Routes.booking,
                    // Booking is a focused transaction with its own persistent
                    // action bar. Present it above the shell so the tab bar
                    // cannot compete with that action.
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BookingScreen(
                        unitId: state.pathParameters['unitId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.bookingStatusPath,
                    name: Routes.bookingStatus,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BookingStatusScreen(
                        bookingId: state.pathParameters['bookingId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Lease
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.leasesPath,
                name: Routes.leases,
                builder: (_, _) => const LeasesScreen(),
                routes: [
                  GoRoute(
                    path: Routes.leaseDetailPath,
                    name: Routes.leaseDetail,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: LeaseDetailScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.leaseAgreementPath,
                    name: Routes.leaseAgreement,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: LeaseAgreementScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.signAgreementPath,
                    name: Routes.signAgreement,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: SignAgreementScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Invoices and payment
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.invoicesPath,
                name: Routes.invoices,
                builder: (_, _) => const InvoicesScreen(),
                routes: [
                  GoRoute(
                    path: Routes.paymentStatusPath,
                    name: Routes.paymentStatus,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: PaymentStatusScreen(
                        paymentId: state.pathParameters['paymentId']!,
                        // Passed through from the payment screen so the provider
                        // instruction is on screen before the first poll returns.
                        intent: state.extra is PaymentIntent
                            ? state.extra! as PaymentIntent
                            : null,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.receiptPath,
                    name: Routes.receipt,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: ReceiptScreen(
                        receiptId: state.pathParameters['receiptId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.invoiceDetailPath,
                    name: Routes.invoiceDetail,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: InvoiceDetailScreen(
                        invoiceId: state.pathParameters['invoiceId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.paymentPath,
                    name: Routes.payment,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: PaymentScreen(
                        invoiceId: state.pathParameters['invoiceId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Profile and account
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profilePath,
                name: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: Routes.editProfilePath,
                    name: Routes.editProfile,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const EditProfileScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.paymentHistoryPath,
                    name: Routes.paymentHistory,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const PaymentHistoryScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.documentsPath,
                    name: Routes.documents,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const DocumentsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.bookingsPath,
                    name: Routes.bookings,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const BookingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.settingsPath,
                    name: Routes.settings,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const SettingsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'That page could not be found.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.goNamed(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
