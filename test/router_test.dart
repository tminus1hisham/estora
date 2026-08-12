import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/app.dart';
import 'package:mall/modules/auth/presentation/login_screen.dart';
import 'package:mall/modules/auth/presentation/splash_screen.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
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
}
