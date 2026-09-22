import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'support/repository_overrides.dart';
import 'package:mall/app.dart';
import 'package:mall/domain/entities/tenant.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/auth/application/auth_controller.dart';
import 'package:mall/modules/account/presentation/edit_contact_screen.dart';
import 'package:mall/modules/account/presentation/security_screen.dart';
import 'package:mall/modules/auth/presentation/login_screen.dart';
import 'package:mall/modules/auth/presentation/splash_screen.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
import 'package:mall/navigation/owner_shell.dart';
import 'package:mall/navigation/routes.dart';
import 'package:mall/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The auth redirect from `app_router.dart`.
///
/// The case worth protecting is the `unknown` stage: on launch the stored
/// session has not been read yet, and redirecting to login during that window
/// would flash the login screen at a tenant who is in fact signed in.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final role in [
    AccountRole.owner,
    AccountRole.manager,
    AccountRole.admin,
    AccountRole.superadmin,
  ]) {
    testWidgets('${role.name} uses manager routes and shared security', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...mockRepositoryOverrides,
            authControllerProvider.overrideWith(() => _RoleAuth(role)),
          ],
          child: const MallApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ManagerShell), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(ManagerShell)));
      router.go(Routes.homePath);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        Routes.ownerPortfolioPath,
      );
      router.pushNamed(Routes.security);
      await tester.pumpAndSettle();
      expect(find.byType(SecurityScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Opening the contact editor from here must stay on the root navigator.
      // Pushing a tenant-shell route from a root route rebuilt the shell page
      // under a duplicate key and asserted inside the Navigator. The security
      // screen no longer links to it, so push the route directly.
      router.pushNamed(Routes.editContact);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EditContactScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  }

  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Pinned so the suite never reaches the network, whatever
        // AppConfig.dataSource is set to.
        ...mockRepositoryOverrides,
      ],
      child: const MallApp(),
    );
  }

  testWidgets('holds on the splash screen while the session is being read', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());

    // One frame: the auth stage is still unknown.
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // Drain the mock's simulated latency so the test does not end with a timer
    // still pending.
    await tester.pumpAndSettle();
  });

  testWidgets('sends an unauthenticated tenant to login once resolved', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('focused transactions are presented above the tab shell', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(LoginScreen)));
    // Section 88 added a second shell for the owner side, so the tenant one has
    // to be identified rather than assumed to be the only one.
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .firstWhere((route) => _hasRouteNamed(route.routes, Routes.home));

    for (final name in const [
      Routes.payment,
      Routes.paymentStatus,
      Routes.receipt,
      Routes.leaseAgreement,
      Routes.signAgreement,
    ]) {
      expect(
        _routeNamed(shell.routes, name).parentNavigatorKey,
        isNotNull,
        reason: '$name must use the root navigator',
      );
    }

    // Browse and support are not in the shell at all — they are declared
    // beside it, on the root navigator, and pushed over it. Booking came with
    // Browse when it left, and never needed a key of its own again.
    for (final name in const [
      Routes.browse,
      Routes.booking,
      Routes.bookingStatus,
      Routes.enquiry,
      Routes.support,
      Routes.newTicket,
      Routes.ticketDetail,
    ]) {
      expect(
        _hasRouteNamed(shell.routes, name),
        isFalse,
        reason: '$name must be declared outside the tab shell',
      );
      expect(
        _hasRouteNamed(router.configuration.routes, name),
        isTrue,
        reason: '$name must still be reachable from the root',
      );
    }

    // Detail pages remain in their branch so tab state survives.
    expect(
      _routeNamed(shell.routes, Routes.invoiceDetail).parentNavigatorKey,
      isNull,
    );

    // Utilities took the tab Browse gave up, so its own pages stay in-branch.
    expect(_hasRouteNamed(shell.routes, Routes.utilities), isTrue);
    expect(
      _routeNamed(shell.routes, Routes.utilityDetail).parentNavigatorKey,
      isNull,
    );
  });

  testWidgets('current property route carries the lease identifier', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(LoginScreen)));
    expect(
      router.namedLocation(
        Routes.currentProperty,
        pathParameters: const {'leaseId': 'lse_demo'},
      ),
      '/home/property/lse_demo',
    );
  });

  testWidgets('a phone number and a password sign a tenant in', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // The method the screen opens on, and the pair the contract keys on: no
    // code is sent and nothing routes through the OTP screen.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '+254712345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'a-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('a number typed the local way signs in on the country code', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // How a tenant actually types it. The selector sits on Kenya, so this is
    // the same account as `+254712345678` above — which is the point of
    // joining the code on before the number is sent.
    expect(find.text('+254'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '0712345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'a-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a signed-in tenant lands on home and cannot go back to login', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // Sign in through the mock's email and password path.
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'amina@example.co.ke',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'a-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // The redirect keeps a signed-in tenant out of the auth screens.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  // -- The role gate (section 88) --------------------------------------------
  //
  // The redirect in `app_router.dart` is the only place a role decides
  // anything. There is no per-route guard anywhere in the app, so if these
  // three pass, an account cannot reach the wrong side.

  testWidgets('an owner signs in to the owner shell, not the tenant one', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _signInWithEmail(tester, 'owner@karunaholdings.co.ke');

    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('a tenant sent to an owner route is returned home', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _signInWithEmail(tester, 'amina@example.co.ke');
    expect(find.byType(HomeScreen), findsOneWidget);

    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).go(Routes.ownerPortfolioPath);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OwnerShell), findsNothing);
  });

  testWidgets('owner credentials open the manager view', (tester) async {
    // How a demo moves between the two sides: by changing account, since the
    // role lives on the session and nothing overrides it.
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _signInWithEmail(tester, 'owner@karunaholdings.co.ke');
    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('tenant credentials open the tenant view', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _signInWithEmail(tester, 'amina@example.co.ke');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OwnerShell), findsNothing);
  });

  testWidgets('an owner sent to a tenant route is returned to the portfolio', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _signInWithEmail(tester, 'owner@karunaholdings.co.ke');

    GoRouter.of(
      tester.element(find.byType(OwnerShell)),
    ).go(Routes.invoicesPath);
    await tester.pumpAndSettle();

    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}

class _RoleAuth extends AuthController {
  _RoleAuth(this.role);
  final AccountRole role;
  @override
  AuthState build() => AuthState(
    stage: AuthStage.authenticated,
    session: AuthSession(
      user: AppUser(
        id: 'test-user',
        firstName: 'Test',
        lastName: 'Account',
        status: 'ACTIVE',
        role: role,
      ),
      tenant: null,
    ),
  );
}

/// Signs in through the mock's email and password path.
///
/// Which account you land on is decided by the address: the mock resolves it
/// against the accounts the seed registered.
Future<void> _signInWithEmail(WidgetTester tester, String email) async {
  await tester.tap(find.text('Email'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    email,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'a-password',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

bool _hasRouteNamed(Iterable<RouteBase> routes, String name) {
  try {
    _routeNamed(routes, name);
    return true;
  } on StateError {
    return false;
  }
}

GoRoute _routeNamed(Iterable<RouteBase> routes, String name) {
  for (final route in routes) {
    if (route is GoRoute && route.name == name) return route;
    try {
      return _routeNamed(route.routes, name);
    } on StateError {
      // Keep looking in sibling branches.
    }
  }
  throw StateError('No route named $name');
}
