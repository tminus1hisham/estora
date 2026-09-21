import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'support/repository_overrides.dart';
import 'package:mall/app.dart';
import 'package:mall/components/app_surface_card.dart';
import 'package:mall/components/collection_columns.dart';
import 'package:mall/components/unit_status_strip.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/domain/entities/owner.dart';
import 'package:mall/modules/owner/application/owner_controller.dart';
import 'package:mall/modules/owner/presentation/widgets/invoice_payments_sheet.dart';
import 'package:mall/modules/properties/application/property_controller.dart';
import 'package:mall/modules/treasury/application/treasury_controller.dart';
import 'package:mall/navigation/owner_shell.dart';
import 'package:mall/navigation/routes.dart';
import 'package:mall/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mall/core/utils/money.dart';

/// Section 88's owner screens, held to the same layout standard as the tenant's.
///
/// The existing quality tests cover 320×640 at an accessibility text size
/// because that is where a two-up row silently truncates. The owner stage is
/// denser than anything on the tenant side, so it gets the same treatment: any
/// unhandled overflow shows up as an exception during pump and fails the test.
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

  void useViewport(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  Future<void> signInAsOwner(WidgetTester tester) async {
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'owner@karunaholdings.co.ke',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'a-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('the portfolio survives a small phone at an accessibility '
      'text size', (tester) async {
    // Signed in at a comfortable size first, then squeezed. At 320 wide with
    // doubled text the login form's fields are below the fold, so driving the
    // sign-in there would be testing the login screen's scroll behaviour
    // rather than the owner stage's layout.
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);
    expect(find.byType(OwnerShell), findsOneWidget);

    useViewport(tester, const Size(320, 640), textScale: 2);
    await tester.pumpAndSettle();

    expect(find.byType(OwnerShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the portfolio is safe on a flagship viewport', (tester) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    expect(find.byType(OwnerShell), findsOneWidget);
    // The stage is drawing the real portfolio, not an empty state.
    expect(find.text('DUE TO YOU THIS MONTH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every owner tab opens on real data', (tester) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    // Properties: the portfolio's buildings.
    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();
    expect(find.text('Sarit Mall'), findsWidgets);

    // The current shell exposes Revenue and Account; Tenancies is hidden.
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('owner@karunaholdings.co.ke'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rent roll groups let units before empty ones', (
    tester,
  ) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    // Navigated by route rather than by scrolling to a tile and tapping it:
    // the tile's position depends on how tall the sections above it happen to
    // be, which is not what this test is about.
    GoRouter.of(tester.element(find.byType(OwnerShell))).pushNamed(
      Routes.ownerRentRoll,
      pathParameters: {'propertyId': 'prp_sarit'},
    );
    await tester.pumpAndSettle();

    // RecordGroup sets its headings in small caps.
    expect(find.text('LET'), findsOneWidget);
    expect(find.text('AVAILABLE'), findsOneWidget);
    // SHOP-103 was priced by hand and the line says so.
    expect(find.textContaining('overridden'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('money shows what came in and what is owed', (tester) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OWED TO YOU'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('OWED TO YOU'), findsOneWidget);
    expect(find.text('Total outstanding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the revenue tiles count the ledger and open each list', (
    tester,
  ) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OwnerShell)),
    );
    final report = container.read(ownerReportProvider).requireValue;
    final bank = container.read(bankPaymentsProvider).requireValue;

    // The tiles sit under the collected card, past the fold on a phone.
    await tester.scrollUntilVisible(
      find.text('TRANSACTIONS'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Two groups, four doors, in this order: invoices then transactions.
    expect(find.text('INVOICES'), findsOneWidget);
    expect(find.text('TRANSACTIONS'), findsOneWidget);
    Finder tile(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(AppSurfaceCard),
    );
    Finder figure(String label, int count) =>
        find.descendant(of: tile(label), matching: find.text('$count'));
    expect(figure('Paid', report.paidInvoices.length), findsOneWidget);
    expect(figure('Unpaid', report.outstandingInvoices.length), findsOneWidget);
    expect(figure('Bank', bank.length), findsOneWidget);
    expect(figure('M-Pesa', report.received.length), findsOneWidget);
    final order = [
      for (final label in ['Paid', 'Unpaid', 'Bank', 'M-Pesa'])
        tester.getTopLeft(tile(label)),
    ];
    expect(order[0].dy, lessThan(order[2].dy));
    expect(order[1].dy, lessThan(order[3].dy));
    expect(order[0].dx, lessThan(order[1].dx));

    // Unpaid opens the invoices still owed, the same rows the tile counted.
    await tester.tap(tile('Unpaid'));
    await tester.pumpAndSettle();
    expect(find.text('Unpaid invoices'), findsOneWidget);
    final owed = report.outstandingInvoices;
    expect(owed, isNotEmpty);
    expect(
      find.text(owed.first.tenantName ?? owed.first.invoiceNumber),
      findsWidgets,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(tile('Paid'));
    await tester.pumpAndSettle();
    await tester.tap(tile('Paid'));
    await tester.pumpAndSettle();
    expect(find.text('Paid invoices'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The transaction tiles open the till's own screens.
    await tester.ensureVisible(tile('M-Pesa'));
    await tester.pumpAndSettle();
    await tester.tap(tile('M-Pesa'));
    await tester.pumpAndSettle();
    expect(find.text('M-Pesa payments'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(tile('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(tile('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Bank payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revenue period controls fit a small phone with large text', (
    tester,
  ) async {
    useViewport(tester, const Size(390, 844));
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    useViewport(tester, const Size(320, 640), textScale: 2);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Today'),
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('COLLECTED TODAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an unpaid invoice opens its payments', (tester) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OwnerShell)),
    );
    final report = container.read(ownerReportProvider).requireValue;
    final owed = report.outstandingInvoices;
    expect(owed, isNotEmpty);

    // The rows live behind the Unpaid tile, which sits under the collected
    // card, not on the Revenue page itself.
    final unpaid = find.ancestor(
      of: find.text('Unpaid'),
      matching: find.byType(AppSurfaceCard),
    );
    await tester.scrollUntilVisible(
      unpaid,
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(unpaid);
    await tester.pumpAndSettle();
    expect(find.text('Unpaid invoices'), findsOneWidget);
    final row = find.text(owed.first.tenantName ?? owed.first.invoiceNumber);
    await tester.ensureVisible(row.first);
    await tester.pumpAndSettle();
    await tester.tap(row.first);
    await tester.pumpAndSettle();

    // The sheet leads with the invoice's own figures, then the till's rows
    // against it, or says plainly that there are none.
    expect(find.byType(InvoicePaymentsSheet), findsOneWidget);
    expect(find.text('Balance due'), findsOneWidget);
    final count = owed.first.payments.length;
    if (count == 0) {
      expect(
        find.text('No payments have been received against this invoice.'),
        findsOneWidget,
      );
    } else {
      expect(
        find.text('$count PAYMENT${count == 1 ? '' : 'S'}'),
        findsOneWidget,
      );
      expect(
        find.text(owed.first.payments.first.transactionId),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('an owner of two properties can cut the report to one', (
    tester,
  ) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    // Karuna holds both seeded properties, so the strip is offered, opening
    // on the whole portfolio.
    expect(find.text('All properties'), findsOneWidget);
    expect(find.text('ABC Business Centre'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OwnerShell)),
    );
    expect(container.read(reportPropertyProvider), isNull);

    // The strip scrolls sideways; the second property sits past the edge
    // of a phone.
    await tester.ensureVisible(find.text('ABC Business Centre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABC Business Centre'));
    await tester.pumpAndSettle();

    // The filter is the server's: the report is re-asked for that property.
    final abc = container
        .read(propertyListProvider)
        .requireValue
        .singleWhere((property) => property.name == 'ABC Business Centre');
    expect(container.read(reportPropertyProvider), abc.id);
    expect(container.read(ownerReportProvider).requireValue.propertyId, abc.id);
    expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payouts show the fee as its own line', (tester) async {
    useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await signInAsOwner(tester);

    GoRouter.of(
      tester.element(find.byType(OwnerShell)),
    ).pushNamed(Routes.ownerPayouts);
    await tester.pumpAndSettle();

    // Section 41: shown rather than quietly deducted.
    expect(find.text('Collected'), findsWidgets);
    expect(find.text('Platform fee'), findsWidgets);
    expect(find.text('Due to you'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the owner stage is navy with a brass primary in both modes', (
    tester,
  ) async {
    // What separates the tier from the tenant's dark theme is the primary:
    // both are navy-grounded, and only one is brass.
    final stage = AppTheme.ownerStage.colorScheme;
    expect(stage.primary, AppPalette.brass300);
    expect(stage.surface, AppPalette.navy950);
    expect(AppTheme.dark.colorScheme.primary, AppPalette.azure300);

    // Cards lift off the owner stage rather than sinking into it, which is the
    // one relationship deliberately inverted from the tenant's dark theme.
    expect(stage.surfaceContainerLowest, AppPalette.navy900);
  });

  group('CollectionColumns', () {
    testWidgets('draws nothing when there is nothing to draw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CollectionColumns.monthly(months: const [])),
        ),
      );
      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles a month that collected more than it billed', (
      tester,
    ) async {
      // A deposit invoiced in one month and paid in the next does exactly
      // this. The bar must not overflow its column.
      final months = [
        MonthlyCollection(
          month: DateTime(2026, 7),
          billed: Money.fromMajor(100000, 'KES'),
          collected: Money.fromMajor(850000, 'KES'),
        ),
        MonthlyCollection(
          month: DateTime(2026, 8),
          billed: Money.fromMajor(100000, 'KES'),
          collected: Money.fromMajor(100000, 'KES'),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: CollectionColumns.monthly(months: months),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('UnitStatusStrip', () {
    testWidgets('shows a segment and a count for each occupied state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: UnitStatusStrip(
                mix: UnitMix(leased: 5, available: 4, unavailable: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // Nothing is booked, so that segment is absent rather than drawn empty.
      expect(find.text('booked'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws nothing for a property with no units', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UnitStatusStrip(mix: UnitMix())),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
