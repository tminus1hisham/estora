import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estora/core/theme/app_theme.dart';
import 'package:estora/domain/entities/tenant.dart';
import 'package:estora/modules/auth/application/auth_controller.dart';
import 'package:estora/modules/profile/presentation/profile_screen.dart';
import 'package:estora/navigation/routes.dart';

class _ProfileAuth extends AuthController {
  @override
  Future<void> logout() async {
    state = const AuthState(stage: AuthStage.unauthenticated);
  }

  @override
  AuthState build() => const AuthState(
    stage: AuthStage.authenticated,
    session: AuthSession(
      user: AppUser(
        id: 'profile-test',
        firstName: 'Alexandra',
        lastName: 'Wanjiru',
        status: 'ACTIVE',
        email: 'alexandra.wanjiru@example.com',
        emailVerified: true,
      ),
      tenant: null,
    ),
  );
}

void main() {
  testWidgets('profile sign out ends the session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_ProfileAuth.new)],
        child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Sign out');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(button));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      container.read(authControllerProvider).stage,
      AuthStage.unauthenticated,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 430.0, 1100.0]) {
    for (final dark in [false, true]) {
      testWidgets('profile fits $width, dark: $dark, with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [authControllerProvider.overrideWith(_ProfileAuth.new)],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.6),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alexandra Wanjiru'), findsNWidgets(2));
        expect(find.text('Not added yet'), findsOneWidget);
        expect(find.bySemanticsLabel('Email verified'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('profile actions keep their destinations and animations settle', (
    tester,
  ) async {
    // Everything the profile links to is pushed over the shell, so the tab
    // the tenant came from is still underneath. Browse is here because it is
    // no longer a tab; support is the row beneath it.
    final destinations = {
      'Available spaces': (route: Routes.browse, query: '', pushed: true),
      'Support tickets': (route: Routes.support, query: '', pushed: true),
      'Sign-in and security': (route: Routes.security, query: '', pushed: true),
      'Settings': (route: Routes.settings, query: '', pushed: true),
    };
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        for (final name in destinations.values.map((d) => d.route))
          GoRoute(
            path: '/$name',
            name: name,
            builder: (_, state) => Scaffold(
              body: Text(
                'Destination: $name'
                '${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
              ),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_ProfileAuth.new)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    for (final destination in destinations.entries) {
      final action = find.text(destination.key);
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      final target = destination.value;
      expect(
        find.text('Destination: ${target.route}${target.query}'),
        findsOneWidget,
      );
      if (target.pushed) {
        router.pop();
      } else {
        router.go('/');
      }
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
