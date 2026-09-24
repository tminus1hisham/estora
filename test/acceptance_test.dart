import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'support/repository_overrides.dart';
import 'package:estora/app.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/bookings/presentation/booking_screen.dart';
import 'package:estora/modules/bookings/presentation/bookings_screen.dart';
import 'package:estora/modules/home/presentation/home_screen.dart';
import 'package:estora/modules/profile/presentation/profile_screen.dart';
import 'package:estora/modules/properties/presentation/properties_screen.dart';
import 'package:estora/navigation/routes.dart';
import 'package:estora/modules/units/presentation/property_spaces_screen.dart';
import 'package:estora/modules/units/presentation/unit_detail_screen.dart';
import 'support/mock/mock_server.dart';
import 'package:estora/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the section 94 acceptance path through the real widget tree.
///
/// The unit tests in this suite exercise the server rules directly; this one
/// exercises the app — navigation, provider wiring, and the screens actually
/// rendering what the repositories return. Between them, "it builds" and "it
/// works" are separate claims with separate evidence.
///
/// It stops at the point money changes hands. Payment settles on a timer and
/// the status screen polls, which does not sit well with `pumpAndSettle`; the
/// financial cascade after that point is covered thoroughly in
/// `payment_flow_test.dart` against the same server.
void main() {
  late MockServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = MockServer(
      paymentAuthorisationDelay: const Duration(milliseconds: 1),
      paymentSettlementDelay: const Duration(milliseconds: 1),
    );
  });

  /// The default 800x600 test surface is neither the shape nor the height of a
  /// phone, which pushes bottom sheets and lower cards out of the tree. These
  /// are phone proportions, so what the test sees matches what a tenant sees.
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
        // Pinned so the suite never reaches the network, whatever
        // AppConfig.dataSource is set to.
        ...mockRepositoryOverrides,
        // Shared with the test body, so assertions can read server state.
        mockServerProvider.overrideWithValue(server),
      ],
      child: const EstoraApp(),
    );
  }

  /// Advances past any in-flight mock request.
  ///
  /// `pumpAndSettle` alone is not enough: a pending `Future.delayed` does not
  /// schedule a frame, so there is nothing for it to settle and the test would
  /// end with a timer still outstanding.
  Future<void> drainPendingRequests(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
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

  /// Opens Browse the way a tenant now has to.
  ///
  /// It is no longer a tab: the fifth slot went to Utilities, and browsing is
  /// reached from the Profile section that replaced it. Going through that
  /// section rather than pushing the route keeps this test honest about the
  /// journey actually being reachable.
  Future<void> openBrowse(WidgetTester tester) async {
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Available spaces'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Available spaces'));
    await tester.pumpAndSettle();
  }

  testWidgets('a tenant can sign in and see their tenancy', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    expect(find.byType(HomeScreen), findsOneWidget);

    // Section 44: current property, unit and outstanding balance.
    expect(find.text('Sarit Estora'), findsOneWidget);
    expect(find.text('Unit SHOP-101'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);

    // The seeded outstanding rent invoice.
    expect(find.text('KES 150,000'), findsWidgets);
  });

  testWidgets('a tenant can browse to a property\'s spaces', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await openBrowse(tester);
    expect(find.byType(PropertiesScreen), findsOneWidget);

    // Pushed over the shell rather than replacing a tab, so the bar the
    // tenant left is still underneath and the back arrow is the way out.
    expect(find.byType(NavigationBar), findsNothing);

    // Browse lists what the availability engine says can be booked, by
    // property; a card opens that property's spaces, read off the same
    // engine answer — blocks and sizes, not unit records.
    await tester.tap(find.text('Sarit Estora').first);
    await tester.pumpAndSettle();
    expect(find.byType(PropertySpacesScreen), findsOneWidget);

    // SHOP-102, SHOP-103 and the kiosk are free in the main building,
    // SHOP-104 in the east wing; SHOP-101 is let and SHOP-105 under
    // maintenance. The engine counts the free ones by size and names none.
    expect(find.text('MAIN BUILDING'), findsOneWidget);
    expect(find.text('EAST WING'), findsOneWidget);
    expect(find.text('5000 sq ft'), findsNWidgets(2));
    expect(find.text('1000 sq ft'), findsOneWidget);
    expect(find.text('2 units left'), findsOneWidget);
    expect(find.text('1 unit left'), findsNWidgets(2));
    expect(find.textContaining('SHOP-'), findsNothing);
  });

  testWidgets('a let unit is not bookable from its detail screen', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    // Browse no longer lists units — the engine names none — so the unit
    // record is opened by its own route, as a link into it would.
    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).goNamed(Routes.unitDetail, pathParameters: {'unitId': 'unt_shop_101'});
    await tester.pumpAndSettle();

    expect(find.byType(UnitDetailScreen), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.textContaining('currently let'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Not available'),
    );
    expect(button.onPressed, isNull);

    // The unit detail screen also fetches pricing in the background.
    await drainPendingRequests(tester);
  });

  testWidgets(
    'booking a unit asks who is booking, not for money, and creates the booking',
    (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(await buildApp());
      await signIn(tester);

      await openBrowse(tester);
      await tester.tap(find.text('Sarit Estora').first);
      await tester.pumpAndSettle();

      // The first Book is the main building's 5000 sq ft, of which two are
      // free. No unit is chosen here; the server allocates one.
      await tester.tap(find.widgetWithText(FilledButton, 'Book').first);
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);

      // Nothing is asked for here: the screen opens on the space and who is
      // booking it, and says so.
      expect(find.textContaining('Nothing is paid now'), findsOneWidget);
      expect(find.text('Main Building'), findsOneWidget);
      expect(find.text('5000 sq ft'), findsOneWidget);
      expect(find.text('2 units'), findsOneWidget);

      // Confirm is gated on acknowledging the terms.
      final confirmFinder = find.widgetWithText(
        FilledButton,
        'Confirm booking',
      );
      expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

      final list = find.byType(ListView).first;
      await tester.scrollUntilVisible(
        find.text('After you book'),
        240,
        // `.first` is the ListView's own scrollable. The applicant fields
        // further down the page are text fields, and every text field carries a
        // Scrollable of its own — so once they build, an unqualified descendant
        // finder matches more than one.
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();

      // The engine prices nothing, and the screen does not guess: rent, fee
      // and deposit are set on the booking by the server and read from it.
      expect(find.text('Set on your booking'), findsNWidgets(3));
      expect(find.text('KES 150,000'), findsNothing);
      expect(find.text('KES 20,000'), findsNothing);
      expect(find.text('KES 750,000'), findsNothing);

      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        240,
        // `.first` is the ListView's own scrollable. The applicant fields
        // further down the page are text fields, and every text field carries a
        // Scrollable of its own — so once they build, an unqualified descendant
        // finder matches more than one.
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Every unit is let to a trade, so the trading name and what will trade
      // from it are always asked — and the form does not submit without them.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trading name'),
        'Sokoni Fresh',
      );
      await tester.tap(find.text('Type of business'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retail').last);
      await tester.pumpAndSettle();

      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      // The booking is announced in a dialog naming the real booking, and
      // dismissing it lands on My bookings, where the fee is paid.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Booking made'), findsOneWidget);
      expect(find.textContaining('BKG-'), findsWidgets);
      await tester.tap(find.text('View my bookings'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BookingScreen), findsNothing);
      expect(find.byType(BookingsScreen), findsOneWidget);
      expect(find.textContaining('BKG-'), findsWidgets);

      // And the server captured the terms (section 21).
      final booking = server.bookings.values.single;
      expect(booking.unitId, 'unt_shop_102');
      expect(booking.monthlyRent, Money.fromMajor(150000, 'KES'));
      expect(booking.depositAmount, Money.fromMajor(750000, 'KES'));
      expect(booking.bookingFee, Money.fromMajor(20000, 'KES'));
      expect(booking.status, BookingStatus.pendingPayment);

      // Section 31: the fee was raised as an invoice, not a flag.
      expect(booking.bookingFeeInvoiceId, isNotNull);

      // Section 23: no hold yet, because nothing has been paid.
      expect(booking.expiresAt, isNull);

      await drainPendingRequests(tester);
    },
  );
}
