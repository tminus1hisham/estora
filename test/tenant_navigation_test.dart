import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/app.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
import 'package:mall/modules/profile/presentation/profile_screen.dart';
import 'package:mall/modules/properties/presentation/properties_screen.dart';
import 'package:mall/modules/support/presentation/new_ticket_screen.dart';
import 'package:mall/modules/support/presentation/support_tickets_screen.dart';
import 'package:mall/modules/utilities/presentation/utilities_screen.dart';
import 'package:mall/modules/utilities/presentation/utility_detail_screen.dart';
import 'package:mall/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/mock/mock_server.dart';
import 'support/repository_overrides.dart';

/// The tenant's way around the app after Browse gave up its tab.
///
/// Three claims are worth holding still. The fifth tab is Utilities. Browse
/// and Support are pushed over the shell rather than replacing it, so the tab
/// the tenant left is still underneath them. And both are reachable from the
/// two places that were meant to carry them — Profile for each, Home for
/// support — because a feature nobody can find is not a feature.
void main() {
  late MockServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = MockServer(
      paymentAuthorisationDelay: const Duration(milliseconds: 1),
      paymentSettlementDelay: const Duration(milliseconds: 1),
    );
  });

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<Widget> buildApp() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...mockRepositoryOverrides,
        mockServerProvider.overrideWithValue(server),
      ],
      child: const MallApp(),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpAndSettle();
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
  }

  /// Taps something that the page has built but has not scrolled to yet.
  ///
  /// These screens build their whole column up front, so a finder matches a
  /// row that is still below the fold and the tap then lands on nothing.
  /// `ensureVisible` is what closes that gap.
  Future<void> scrollAndTap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapProfileRow(WidgetTester tester, String label) async {
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text(label));
  }

  testWidgets('Utilities holds the fifth tab, and Browse holds none', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Utilities'), findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Browse'), findsNothing);

    await tester.tap(find.text('Utilities'));
    await tester.pumpAndSettle();

    // A tab, so the bar it was reached from is still on screen.
    expect(find.byType(UtilitiesScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Both meters are there, and one opens its own page through the router.
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Electricity'), findsWidgets);
    await scrollAndTap(tester, find.text('Water').first);
    expect(find.byType(UtilityDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile opens Browse over the shell, not in place of it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tapProfileRow(tester, 'Available spaces');

    expect(find.byType(PropertiesScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // The back arrow returns to the tab it was opened from, still on Profile.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile and Home both reach the support desk', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tapProfileRow(tester, 'Support tickets');
    expect(find.byType(SupportTicketsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('Support'));
    expect(find.byType(SupportTicketsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a raised ticket lands at the top of the list', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tapProfileRow(tester, 'Support tickets');
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Raise a ticket'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NewTicketScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Subject'),
      'Corridor light out',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What is happening?'),
      'The light outside the unit has been off since Tuesday evening.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send to support'));
    await tester.pumpAndSettle();

    // Back on the list, with the new ticket on it.
    expect(find.byType(SupportTicketsScreen), findsOneWidget);
    expect(find.text('Corridor light out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
