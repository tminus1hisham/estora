import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../domain/entities/billing.dart';
import '../modules/access/presentation/role_claims_screen.dart';
import '../modules/access/presentation/roles_screen.dart';
import '../modules/access/presentation/user_access_screen.dart';
import '../modules/access/presentation/users_screen.dart';
import '../modules/account/presentation/change_password_screen.dart';
import '../modules/account/presentation/security_screen.dart';
import '../modules/account/presentation/verify_contact_screen.dart';
import '../modules/auth/application/auth_controller.dart';
import '../modules/auth/presentation/forgot_password_screen.dart';
import '../modules/auth/presentation/login_screen.dart';
import '../modules/auth/presentation/otp_screen.dart';
import '../modules/auth/presentation/register_screen.dart';
import '../modules/auth/presentation/reset_password_screen.dart';
import '../modules/auth/presentation/splash_screen.dart';
import '../modules/bookings/presentation/booking_screen.dart';
import '../modules/bookings/presentation/booking_status_screen.dart';
import '../modules/bookings/presentation/bookings_screen.dart';
import '../modules/documents/presentation/documents_screen.dart';
import '../modules/home/presentation/home_screen.dart';
import '../modules/invoices/presentation/defer_invoice_screen.dart';
import '../modules/invoices/presentation/invoice_detail_screen.dart';
import '../modules/invoices/presentation/invoices_screen.dart';
import '../modules/leases/presentation/lease_agreement_screen.dart';
import '../modules/leases/presentation/lease_detail_screen.dart';
import '../modules/leases/presentation/leases_screen.dart';
import '../modules/leases/presentation/sign_agreement_screen.dart';
import '../modules/notifications/presentation/notifications_screen.dart';
import '../modules/owner/presentation/owner_account_screen.dart';
import '../modules/owner/presentation/owner_add_property_screen.dart';
import '../modules/owner/presentation/owner_money_screen.dart';
import '../modules/owner/presentation/owner_payouts_screen.dart';
import '../modules/owner/presentation/owner_portfolio_screen.dart';
import '../modules/owner/presentation/owner_properties_screen.dart';
import '../modules/owner/presentation/owner_property_rate_screen.dart';
import '../modules/owner/presentation/owner_property_screen.dart';
import '../modules/owner/presentation/owner_rent_roll_screen.dart';
import '../modules/owner/presentation/owner_tenancies_screen.dart';
import '../modules/owner/presentation/owner_tenancy_screen.dart';
import '../modules/owner/presentation/tenant_invoices_screen.dart';
import '../modules/payments/presentation/bank_transfer_screen.dart';
import '../modules/payments/presentation/payment_history_screen.dart';
import '../modules/payments/presentation/payment_screen.dart';
import '../modules/payments/presentation/payment_status_screen.dart';
import '../modules/payments/presentation/receipt_screen.dart';
import '../modules/profile/presentation/edit_profile_screen.dart';
import '../modules/profile/presentation/profile_screen.dart';
import '../modules/profile/presentation/settings_screen.dart';
import '../modules/properties/presentation/properties_screen.dart';
import '../modules/properties/presentation/property_detail_screen.dart';
import '../modules/structure/presentation/block_form_screen.dart';
import '../modules/structure/presentation/block_screen.dart';
import '../modules/structure/presentation/blocks_screen.dart';
import '../modules/structure/presentation/property_edit_screen.dart';
import '../modules/structure/presentation/unit_form_screen.dart';
import '../modules/treasury/presentation/bank_payment_edit_screen.dart';
import '../modules/treasury/presentation/bank_payments_screen.dart';
import '../modules/treasury/presentation/mpesa_transactions_screen.dart';
import '../modules/units/presentation/available_units_screen.dart';
import '../modules/units/presentation/unit_detail_screen.dart';
import 'app_shell.dart';
import 'owner_shell.dart';
import 'page_transitions.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  // A ValueNotifier bridges Riverpod's auth state to go_router's
  // refreshListenable, so a sign-in or sign-out re-evaluates the redirect
  // immediately rather than on the next navigation.
  // The notifier carries the role as well as the stage. Both decide which shell
  // an account belongs in, and both change on the same event — a sign-in — so
  // one listener covers them.
  final authState = ValueNotifier<(AuthStage, bool)>((
    AuthStage.unknown,
    false,
  ));
  void syncAuthState() {
    final auth = ref.read(authControllerProvider);
    authState.value = (auth.stage, auth.isManager);
  }

  ref.listen(authControllerProvider, (_, _) => syncAuthState());
  syncAuthState();
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
          location == Routes.forgotPasswordPath ||
          location == Routes.resetPasswordPath;

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

      // Signed in. Section 88 gives an account one side of the platform, and
      // this is the only place that is enforced — there is no per-route guard
      // anywhere, so every rule about who may see what has to live here.
      //
      // The role comes from the session and nowhere else. An earlier version
      // let a debug flag override it, which could put a tenant in front of
      // owner screens that have no owner record to read and an owner in front
      // of a tenant app with no tenancy — both render nothing. Changing role
      // means changing account.
      final isManager = ref.read(authControllerProvider).isManager;
      final inOwnerSpace = location.startsWith(Routes.ownerRootPath);

      // Keep them out of the auth screens, landing each side on its own root.
      if (isAuthRoute) {
        return isManager ? Routes.ownerPortfolioPath : Routes.homePath;
      }
      // `/owner` on its own is not a screen; it is the space the tabs live in.
      if (location == Routes.ownerRootPath) return Routes.ownerPortfolioPath;
      final isSharedAccountRoute =
          location == '/profile/security' ||
          location.startsWith('/profile/security/');
      if (isSharedAccountRoute) return null;
      if (isManager && !inOwnerSpace) return Routes.ownerPortfolioPath;
      if (!isManager && inOwnerSpace) return Routes.homePath;
      return null;
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
      GoRoute(
        path: Routes.resetPasswordPath,
        name: Routes.resetPassword,
        pageBuilder: (_, state) => fadePage(
          state: state,
          child: ResetPasswordScreen(
            // Carried through from the forgot-password screen so the number
            // does not have to be typed twice.
            phoneNumber: state.uri.queryParameters['phone'],
          ),
        ),
      ),

      // Declared before the bare `security` route for the same
      // reason the invoices branch orders its routes: a shorter
      // pattern earlier would swallow the longer ones.
      GoRoute(
        path: '/profile/${Routes.changePasswordPath}',
        name: Routes.changePassword,
        pageBuilder: (_, state) =>
            lateralPage(state: state, child: const ChangePasswordScreen()),
      ),
      GoRoute(
        path: '/profile/${Routes.verifyContactPath}',
        name: Routes.verifyContact,
        pageBuilder: (_, state) => lateralPage(
          state: state,
          child: VerifyContactScreen(
            channel: VerificationChannel.fromPath(
              state.pathParameters['channel'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/${Routes.securityPath}',
        name: Routes.security,
        pageBuilder: (_, state) =>
            lateralPage(state: state, child: const SecurityScreen()),
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
                    path: Routes.bankTransferPath,
                    name: Routes.bankTransfer,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BankTransferScreen(
                        invoiceId: state.pathParameters['invoiceId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.deferInvoicePath,
                    name: Routes.deferInvoice,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: DeferInvoiceScreen(
                        invoiceId: state.pathParameters['invoiceId']!,
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

      // -- Owner shell (section 88) -----------------------------------------
      //
      // A second shell rather than a second app. The two never overlap: the
      // redirect above puts an account in one or the other and keeps it there,
      // so there is no state where both bottom bars could be reachable.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            ManagerShell(navigationShell: navigationShell),
        branches: [
          // Portfolio
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerPortfolioPath,
                name: Routes.ownerPortfolio,
                builder: (_, _) => const OwnerPortfolioScreen(),
              ),
            ],
          ),

          // Properties
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerPropertiesPath,
                name: Routes.ownerProperties,
                builder: (_, _) => const OwnerPropertiesScreen(),
                routes: [
                  // Declared before the bare `:propertyId` pattern, which
                  // would otherwise swallow it — the same ordering the
                  // invoices branch needs.
                  GoRoute(
                    path: Routes.ownerPreviewPath,
                    name: Routes.ownerPreview,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: PropertyDetailScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.ownerAddPropertyPath,
                    name: Routes.ownerAddProperty,
                    // A focused transaction with its own action bar, presented
                    // above the shell so the tab bar cannot compete with it.
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const OwnerAddPropertyScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.ownerPropertyRatePath,
                    name: Routes.ownerPropertyRate,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: OwnerPropertyRateScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.ownerRentRollPath,
                    name: Routes.ownerRentRoll,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: OwnerRentRollScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  // Every one of these is declared before the bare
                  // `:propertyId` pattern, which would otherwise swallow the
                  // ones that begin with a literal segment.
                  GoRoute(
                    path: Routes.blockDetailPath,
                    name: Routes.blockDetail,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BlockScreen(
                        blockId: state.pathParameters['blockId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.blockEditPath,
                    name: Routes.blockEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BlockFormScreen(
                        // A block already knows its property; the form reads
                        // it from the record it loads, so the query parameter
                        // is only a hint for the create case.
                        propertyId:
                            state.uri.queryParameters['propertyId'] ?? '',
                        blockId: state.pathParameters['blockId'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.unitEditPath,
                    name: Routes.unitEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: UnitFormScreen(
                        propertyId:
                            state.uri.queryParameters['propertyId'] ?? '',
                        unitId: state.pathParameters['unitId'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.blockCreatePath,
                    name: Routes.blockCreate,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BlockFormScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.unitCreatePath,
                    name: Routes.unitCreate,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: UnitFormScreen(
                        propertyId: state.pathParameters['propertyId']!,
                        blockId: state.uri.queryParameters['blockId'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.blocksPath,
                    name: Routes.blocks,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BlocksScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.propertyEditPath,
                    name: Routes.propertyEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: PropertyEditScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.ownerPropertyPath,
                    name: Routes.ownerProperty,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: OwnerPropertyScreen(
                        propertyId: state.pathParameters['propertyId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tenancies
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerTenanciesPath,
                name: Routes.ownerTenancies,
                builder: (_, _) => const OwnerTenanciesScreen(),
                routes: [
                  // Two segments, so it cannot be swallowed by `:leaseId` —
                  // declared first regardless, since the ordering rule here is
                  // easy to break later.
                  GoRoute(
                    path: Routes.ownerAgreementPath,
                    name: Routes.ownerAgreement,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: LeaseAgreementScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.tenantInvoicesPath,
                    name: Routes.tenantInvoices,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: TenantInvoicesScreen(
                        tenantId: state.pathParameters['tenantId']!,
                        tenantName:
                            state.uri.queryParameters['name'] ?? 'This tenant',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.ownerTenancyPath,
                    name: Routes.ownerTenancy,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: OwnerTenancyScreen(
                        leaseId: state.pathParameters['leaseId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Money
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerMoneyPath,
                name: Routes.ownerMoney,
                builder: (_, _) => const OwnerMoneyScreen(),
                routes: [
                  GoRoute(
                    path: Routes.ownerPayoutsPath,
                    name: Routes.ownerPayouts,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const OwnerPayoutsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: Routes.mpesaTransactionsPath,
                    name: Routes.mpesaTransactions,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const MpesaTransactionsScreen(),
                    ),
                  ),
                  // Before the plain `bank` route, which would otherwise
                  // match first.
                  GoRoute(
                    path: Routes.bankPaymentEditPath,
                    name: Routes.bankPaymentEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: BankPaymentEditScreen(
                        paymentId: state.pathParameters['paymentId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.bankPaymentsPath,
                    name: Routes.bankPayments,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: const BankPaymentsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Account
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerAccountPath,
                name: Routes.ownerAccount,
                builder: (_, _) => const OwnerAccountScreen(),
                routes: [
                  // The two-segment patterns come first, for the ordering
                  // reason that runs through this file.
                  GoRoute(
                    path: Routes.accessUserPath,
                    name: Routes.accessUser,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: UserAccessScreen(
                        phoneNumber: state.pathParameters['phoneNumber']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.accessRolePath,
                    name: Routes.accessRole,
                    pageBuilder: (_, state) => lateralPage(
                      state: state,
                      child: RoleClaimsScreen(
                        roleName: state.pathParameters['roleName']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Routes.accessUsersPath,
                    name: Routes.accessUsers,
                    pageBuilder: (_, state) =>
                        lateralPage(state: state, child: const UsersScreen()),
                  ),
                  GoRoute(
                    path: Routes.accessRolesPath,
                    name: Routes.accessRoles,
                    pageBuilder: (_, state) =>
                        lateralPage(state: state, child: const RolesScreen()),
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
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              Gap.h16,
              Text(
                'That page could not be found.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Gap.h24,
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
