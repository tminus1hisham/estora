import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mall/app.dart';
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

  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      Routes.booking,
      Routes.bookingStatus,
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

    // Detail and browsing pages remain in their branch so tab state survives.
    expect(
      _routeNamed(shell.routes, Routes.invoiceDetail).parentNavigatorKey,
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

  testWidgets('the demo picker opens each account in its own shell', (
    tester,
  ) async {
    // How a demo moves between the two sides: by changing account, since the
    // role lives on the session and nothing overrides it.
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _tapDemoAccount(tester, 'Karuna Holdings');
    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the tenant demo account opens the tenant shell', (
    tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await _tapDemoAccount(tester, 'Amina Wanjiru');
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

/// Taps a tile in the login screen's demo account picker.
///
/// The picker sits below the form, so on a default test viewport it has to be
/// scrolled to before it can be hit.
Future<void> _tapDemoAccount(WidgetTester tester, String name) async {
  final tile = find.text(name);
  // ensureVisible rather than scrollUntilVisible: the auth page has more than
  // one Scrollable, and scrollUntilVisible cannot tell which to drive.
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
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
