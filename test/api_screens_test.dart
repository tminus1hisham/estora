import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'support/repository_overrides.dart';
import 'package:mall/app.dart';
import 'package:mall/navigation/routes.dart';
import 'package:mall/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens added for the published contract, opened in the real app.
///
/// Deliberately a smoke test rather than an interaction test: the rules these
/// screens obey are asserted against the server in `api_surface_test.dart`,
/// and what is worth proving here is the thing that suite cannot — that each
/// route resolves, the screen builds against real seeded data, and nothing
/// overflows on a phone. An unhandled overflow throws during pump and fails
/// the test, which is the point of pumping them at 390×844 rather than on a
/// desktop-sized surface.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> signIn(WidgetTester tester, String email) async {
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

  /// Navigates by route name, the way the app itself does.
  ///
  /// Going through the router rather than pushing a widget directly is what
  /// makes this a test of the routing as well as the screen — a pattern
  /// declared in the wrong order would resolve to the wrong page here.
  Future<void> open(
    WidgetTester tester,
    String route, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) async {
    final context = tester.element(find.byType(Navigator).first);
    GoRouter.of(context).pushNamed(
      route,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
    // Twice: the first settle builds the screen, and a screen that watches a
    // provider from inside its build starts that request on the frame after.
    // One settle would leave the mock's latency timer pending at teardown.
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  group('the owner side', () {
    Future<String> firstPropertyId(WidgetTester tester) async {
      final context = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(context);
      final server = container.read(mockServerProvider);
      return server.properties.values
          .firstWhere((property) => property.ownerId != null)
          .id;
    }

    testWidgets('blocks, and a block with its units', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      final propertyId = await firstPropertyId(tester);
      await open(
        tester,
        Routes.blocks,
        pathParameters: {'propertyId': propertyId},
      );
      expect(find.text('Blocks'), findsWidgets);

      // Straight into the first block, which is where the units live.
      await tester.tap(find.byIcon(Icons.dashboard_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('The block'), findsOneWidget);
    });

    testWidgets('the new-unit form opens with its blocks loaded', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(
        tester,
        Routes.unitCreate,
        pathParameters: {'propertyId': await firstPropertyId(tester)},
      );

      expect(find.text('Add a unit'), findsOneWidget);
      expect(find.text('Unit number'), findsOneWidget);
      // The block picker is the part that had to load something. An empty
      // dropdown here would mean the form opened before its blocks arrived.
      expect(find.text('Block'), findsOneWidget);
      expect(find.text('No block'), findsOneWidget);
    });

    testWidgets('the property edit form is filled from the record', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(
        tester,
        Routes.propertyEdit,
        pathParameters: {'propertyId': await firstPropertyId(tester)},
      );

      expect(find.text('Edit property'), findsOneWidget);
      // Seeded, not blank: an edit form that opens empty invites somebody to
      // overwrite a field they never meant to touch.
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Property name'),
            )
            .controller!
            .text,
        isNotEmpty,
      );
    });

    testWidgets('the till lists what arrived and what is unallocated', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(tester, Routes.mpesaTransactions);

      expect(find.text('M-Pesa payments'), findsOneWidget);
      // The seeded orphan — money in the account with nothing to match it to,
      // which is the reason this screen exists. It sorts above the reconciled
      // rows, so it is on screen without scrolling. Matched on the payer
      // rather than the reference, which the search field also uses as its
      // hint.
      expect(find.textContaining('JOSEPH'), findsOneWidget);
      expect(find.text('Unallocated'), findsOneWidget);
    });

    testWidgets('bank payments separate pending from reconciled', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(tester, Routes.bankPayments);

      expect(find.text('Bank payments'), findsOneWidget);
      expect(find.text('FT24099KX41M'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('people and roles open from the account tab', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(tester, Routes.accessUsers);
      expect(find.text('People'), findsWidgets);
      expect(find.text('Fatuma Hassan'), findsOneWidget);

      await open(tester, Routes.accessRoles);
      expect(find.text('Administrator'), findsWidgets);
    });

    testWidgets('a role shows the permissions it carries', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'owner@karunaholdings.co.ke');

      await open(
        tester,
        Routes.accessRole,
        pathParameters: {'roleName': 'FinanceOfficer'},
      );

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('invoices.settle'), findsOneWidget);
    });
  });

  group('the tenant side', () {
    testWidgets('security gathers the credential screens', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'amina@example.co.ke');

      await open(tester, Routes.security);

      expect(find.text('Sign-in and security'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Two-factor authentication'), findsOneWidget);
      expect(find.text('Contact details'), findsOneWidget);
    });

    testWidgets('the change-password form asks for the current one', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'amina@example.co.ke');

      await open(tester, Routes.changePassword);

      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
    });

    testWidgets('a deferral request states that the debt does not move', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'amina@example.co.ke');

      final context = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(context);
      final invoiceId = container
          .read(mockServerProvider)
          .invoices
          .values
          .firstWhere((invoice) => invoice.status.isPayable)
          .id;

      await open(
        tester,
        Routes.deferInvoice,
        pathParameters: {'invoiceId': invoiceId},
      );

      expect(find.text('Why you need more time'), findsOneWidget);
      // Stated on the screen rather than left to be discovered later.
      expect(
        find.textContaining('does not reduce what you owe'),
        findsOneWidget,
      );
    });

    testWidgets('a bank payment is prefilled with the balance', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await signIn(tester, 'amina@example.co.ke');

      final context = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(context);
      final invoice = container
          .read(mockServerProvider)
          .invoices
          .values
          .firstWhere((row) => row.status.isPayable);

      await open(
        tester,
        Routes.bankTransfer,
        pathParameters: {'invoiceId': invoice.id},
      );

      expect(find.text('What you paid'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Amount paid'),
            )
            .controller!
            .text,
        invoice.amountDue.majorUnits.toStringAsFixed(0),
      );
    });

    testWidgets('the reset screen is reachable without a session', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();

      await open(tester, Routes.resetPassword);

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('Reset code'), findsOneWidget);
    });
  });
}
