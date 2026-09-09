import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mall/core/config/app_config.dart';
import 'package:mall/app.dart';
import 'package:mall/components/collection_columns.dart';
import 'package:mall/components/unit_status_strip.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/domain/entities/owner.dart';
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
        dataSourceProvider.overrideWithValue(DataSource.mock),
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

    // Tenancies: grouped by what needs doing, so the arrears tenant leads.
    // RecordGroup sets its heading in small caps, hence the case here.
    await tester.tap(find.text('Tenancies'));
    await tester.pumpAndSettle();
    expect(find.text('IN ARREARS'), findsOneWidget);
    expect(find.text('Tembo Electronics'), findsOneWidget);

    // And into one tenancy.
    await tester.tap(find.text('Tembo Electronics'));
    await tester.pumpAndSettle();
    expect(find.text('Money'), findsWidgets);
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

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);
    expect(find.text('OWED TO YOU'), findsOneWidget);
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
        const MaterialApp(
          home: Scaffold(body: CollectionColumns(months: [])),
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
              child: CollectionColumns(months: months),
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
