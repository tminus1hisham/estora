import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/config/app_config.dart';
import 'package:mall/app.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/bookings/presentation/booking_screen.dart';
import 'package:mall/modules/bookings/presentation/booking_status_screen.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
import 'package:mall/modules/properties/presentation/properties_screen.dart';
import 'package:mall/modules/properties/presentation/property_detail_screen.dart';
import 'package:mall/modules/units/presentation/available_units_screen.dart';
import 'package:mall/modules/units/presentation/unit_detail_screen.dart';
import 'package:mall/services/mock/mock_server.dart';
import 'package:mall/services/providers.dart';
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
        dataSourceProvider.overrideWithValue(DataSource.mock),
        // Shared with the test body, so assertions can read server state.
        mockServerProvider.overrideWithValue(server),
      ],
      child: const MallApp(),
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

  testWidgets('a tenant can sign in and see their tenancy', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    expect(find.byType(HomeScreen), findsOneWidget);

    // Section 44: current property, unit and outstanding balance.
    expect(find.text('Sarit Mall'), findsOneWidget);
    expect(find.text('Unit SHOP-101'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);

    // The seeded outstanding rent invoice.
    expect(find.text('KES 150,000'), findsWidgets);
  });

  testWidgets('a tenant can browse to an available unit', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.byType(PropertiesScreen), findsOneWidget);

    await tester.tap(find.text('Sarit Mall').first);
    await tester.pumpAndSettle();
    expect(find.byType(PropertyDetailScreen), findsOneWidget);

    await tester.tap(find.textContaining('available units'));
    await tester.pumpAndSettle();
    expect(find.byType(AvailableUnitsScreen), findsOneWidget);

    // SHOP-101 is let and SHOP-105 is under maintenance, so neither should be
    // offered; section 48's availability engine decides this, not the client.
    expect(find.text('SHOP-102'), findsOneWidget);
    expect(find.text('SHOP-101'), findsNothing);
    expect(find.text('SHOP-105'), findsNothing);
  });

  testWidgets('a let unit is not bookable from its detail screen', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarit Mall').first);
    await tester.pumpAndSettle();

    // Show everything, including units that are not available.
    await tester.tap(find.textContaining('available units'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SHOP-101'));
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

  testWidgets('booking a unit shows a server quote and creates the booking', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(await buildApp());
    await signIn(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarit Mall').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('available units'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SHOP-102'));
    await tester.pumpAndSettle();
    expect(find.byType(UnitDetailScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Book this unit'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingScreen), findsOneWidget);

    // Section 80's figures, supplied by the server rather than computed here.
    // The fee shows more than once: as the line item, as the card total, and in
    // the payable-now bar. All three read the server's fields; none is summed
    // on screen.
    expect(find.text('KES 20,000'), findsWidgets);
    expect(find.text('KES 750,000'), findsOneWidget); // deposit
    expect(find.textContaining('48 hours'), findsWidgets);

    // Confirm is gated on acknowledging the terms.
    final confirmFinder = find.widgetWithText(FilledButton, 'Confirm booking');
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    final list = find.byType(ListView).first;
    await tester.scrollUntilVisible(
      find.text('Your rent'),
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

    // The rent the booking will be held at (section 21).
    expect(find.text('KES 150,000'), findsOneWidget);

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

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    // Landed on the status screen for a real booking.
    expect(find.byType(BookingStatusScreen), findsOneWidget);
    expect(find.textContaining('BKG-'), findsWidgets);
    expect(find.text('Awaiting payment'), findsWidgets);

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
  });
}
