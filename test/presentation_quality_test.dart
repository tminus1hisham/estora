import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mall/app.dart';
import 'package:mall/components/amount_text.dart';
import 'package:mall/components/app_brand_mark.dart';
import 'package:mall/components/app_media.dart';
import 'package:mall/components/money_count_up.dart';
import 'package:mall/components/status_chip.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:mall/core/theme/status_palette.dart';
import 'package:mall/core/utils/money.dart';
import 'package:mall/domain/entities/unit.dart';
import 'package:mall/domain/entities/dashboard_summary.dart';
import 'package:mall/domain/entities/property.dart';
import 'package:mall/domain/entities/tenant.dart';
import 'package:mall/domain/enums/domain_enums.dart';
import 'package:mall/modules/auth/application/auth_controller.dart';
import 'package:mall/modules/auth/presentation/login_screen.dart';
import 'package:mall/modules/units/application/unit_controller.dart';
import 'package:mall/modules/bookings/presentation/booking_screen.dart';
import 'package:mall/modules/home/application/dashboard_controller.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
import 'package:mall/modules/home/presentation/widgets/balance_card.dart';
import 'package:mall/modules/home/presentation/widgets/home_hero.dart';
import 'package:mall/modules/notifications/application/notification_controller.dart';
import 'package:mall/modules/properties/application/property_controller.dart';
import 'package:mall/navigation/routes.dart';


const _user = AppUser(
  id: 'usr_presentation',
  firstName: 'Amina',
  lastName: 'Wanjiru',
  email: 'amina@example.co.ke',
  phone: '+254712345678',
  status: 'ACTIVE',
  emailVerified: true,
  phoneVerified: true,
);

const _tenant = Tenant(
  id: 'tnt_presentation',
  userId: 'usr_presentation',
  tenantType: TenantType.business,
  displayName: 'Wanjiru Retail Ltd',
  status: 'ACTIVE',
);

const _summary = DashboardSummary(
  currency: 'KES',
  outstandingBalance: Money(15000000, 'KES'),
  recentPayments: [],
  unreadNotifications: 3,
  propertyId: 'prp_sarit',
  propertyName: 'Sarit Mall',
  propertyImageUrl: 'assets/images/property_sarit_mall.jpg',
  unitId: 'unt_shop_101',
  unitNumber: 'SHOP-101',
  leaseId: 'lse_active',
  leaseStatus: LeaseStatus.active,
);

/// The availability engine's answer for the space the booking route opens on.
const _availability = [
  UnitAvailability(
    propertyId: 'prp_sarit',
    propertyName: 'Sarit Mall',
    blockId: 'bld_sarit_main',
    blockName: 'Main Building',
    bySize: [UnitAvailabilitySize(size: 5000, count: 2)],
  ),
];

class _StubAvailability extends AvailabilityController {
  @override
  Future<List<UnitAvailability>> build() async => _availability;
}

class _UnauthenticatedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(stage: AuthStage.unauthenticated);
}

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    stage: AuthStage.authenticated,
    session: AuthSession(user: _user, tenant: _tenant),
  );
}

class _PresentationDashboardController extends DashboardController {
  @override
  Future<DashboardSummary> build() async => _summary;
}

class _EmptyPropertyListController extends PropertyListController {
  @override
  Future<List<Property>> build() async => const <Property>[];
}

void main() {
  Widget themed({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: child,
    );
  }

  void usePhoneViewport(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  Widget signedInApp({bool includeTransactionStubs = false}) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
        dashboardControllerProvider.overrideWith(
          _PresentationDashboardController.new,
        ),
        unreadNotificationCountProvider.overrideWith((ref) async => 3),
        if (includeTransactionStubs) ...[
          propertyListProvider.overrideWith(_EmptyPropertyListController.new),
          availabilityProvider.overrideWith(_StubAvailability.new),
        ],
      ],
      child: const MallApp(),
    );
  }

  group('premium theme', () {
    for (final testCase
        in <
          ({
            String name,
            ThemeMode mode,
            Brightness brightness,
            Color primary,
            Color surface,
            StatusColors statuses,
          })
        >[
          (
            name: 'light',
            mode: ThemeMode.light,
            brightness: Brightness.light,
            primary: AppPalette.azure700,
            surface: AppPalette.stone50,
            statuses: StatusColors.light,
          ),
          (
            name: 'dark',
            mode: ThemeMode.dark,
            brightness: Brightness.dark,
            primary: AppPalette.azure300,
            surface: AppPalette.navy950,
            statuses: StatusColors.dark,
          ),
        ]) {
      testWidgets('${testCase.name} theme boots with the branded system', (
        tester,
      ) async {
        await tester.pumpWidget(
          themed(
            themeMode: testCase.mode,
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Scaffold(
                  body: Text(
                    '${theme.brightness.name} presentation',
                    style: theme.textTheme.titleLarge,
                  ),
                );
              },
            ),
          ),
        );

        final context = tester.element(find.byType(Scaffold));
        final theme = Theme.of(context);

        expect(theme.brightness, testCase.brightness);
        expect(theme.colorScheme.primary, testCase.primary);
        expect(theme.scaffoldBackgroundColor, testCase.surface);
        expect(
          theme.textTheme.titleLarge?.fontFamily,
          AppTypography.fontFamily,
        );
        expect(theme.navigationBarTheme.height, 72);
        expect(theme.extension<StatusColors>(), testCase.statuses);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('login remains scrollable at 360x640 with large text', (
    tester,
  ) async {
    usePhoneViewport(tester, const Size(360, 640), textScale: 2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            _UnauthenticatedAuthController.new,
          ),
        ],
        child: themed(child: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // The greeting says the name in words; the mark is not repeated over it.
    expect(find.byType(AppBrandMark), findsNothing);
    expect(tester.takeException(), isNull);

    // The lower actions remain reachable rather than being clipped by the
    // compact viewport or the accessibility text scale.
    await tester.scrollUntilVisible(
      find.text('Create an account'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AmountText keeps a long amount complete without ellipsis', (
    tester,
  ) async {
    usePhoneViewport(tester, const Size(360, 640), textScale: 2);
    const amount = Money(987654321012345, 'KES');

    await tester.pumpWidget(
      themed(
        child: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: AmountText(amount, scale: AmountScale.title),
            ),
          ),
        ),
      ),
    );

    final amountFinder = find.descendant(
      of: find.byType(AmountText),
      matching: find.byType(Text),
    );
    final amountText = tester.widget<Text>(amountFinder);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(AmountText),
        matching: find.byType(RichText),
      ),
    );

    expect(amountText.textSpan!.toPlainText(), amount.format());
    expect(amountText.overflow, isNot(TextOverflow.ellipsis));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusChip exposes its status and survives large text', (
    tester,
  ) async {
    usePhoneViewport(tester, const Size(360, 640), textScale: 2);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      themed(
        child: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: StatusChip(
              label: 'Awaiting payment',
              tone: StatusTone.progress,
              icon: Icons.schedule_rounded,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.bySemanticsLabel('Status: Awaiting payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  group('AppMedia', () {
    testWidgets('renders a bundled presentation asset', (tester) async {
      await tester.pumpWidget(
        themed(
          child: const Scaffold(
            body: AppMedia(
              source: 'assets/images/property_sarit_mall.jpg',
              semanticLabel: 'Sarit Mall exterior',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/property_sarit_mall.jpg',
      );
      expect(find.bySemanticsLabel('Sarit Mall exterior'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the branded fallback when no source is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          child: const Scaffold(
            body: AppMedia(
              source: null,
              fallbackIcon: Icons.storefront_rounded,
              semanticLabel: 'Property image unavailable',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(
        find.bySemanticsLabel('Property image unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a focused booking route hides shell navigation', (tester) async {
    usePhoneViewport(tester, const Size(390, 844));
    await tester.pumpWidget(signedInApp(includeTransactionStubs: true));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    GoRouter.of(tester.element(find.byType(HomeScreen))).goNamed(
      Routes.booking,
      pathParameters: {'propertyId': 'prp_sarit', 'blockId': 'bld_sarit_main'},
      queryParameters: {Routes.bookingSizeQuery: '5000'},
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookingScreen), findsOneWidget);
    expect(find.text('Confirm your booking'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flagship signed-in home is safe at 390x844 with scaled text', (
    tester,
  ) async {
    usePhoneViewport(tester, const Size(390, 844), textScale: 1.4);
    await tester.pumpWidget(signedInApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Sarit Mall'), findsOneWidget);
    expect(find.text('Unit SHOP-101'), findsOneWidget);
    expect(find.text('KES 150,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Sarit Mall property'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home survives a small phone at an accessibility text size', (
    tester,
  ) async {
    // The home screen puts two figures on one line, four actions in a row and
    // a balance card over a photograph. Each of those has a stacked fallback;
    // this is the viewport that has to reach all of them at once.
    usePhoneViewport(tester, const Size(320, 640), textScale: 2);
    await tester.pumpWidget(signedInApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('KES 150,000'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Everything below the header stays reachable rather than being clipped.
    await tester.scrollUntilVisible(
      find.text('Documents'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the balance card overlaps the header it sits on', (
    tester,
  ) async {
    usePhoneViewport(tester, const Size(390, 844));
    await tester.pumpWidget(signedInApp());
    await tester.pumpAndSettle();

    final headerBottom = tester.getRect(find.byType(HomeHero)).bottom;
    final card = tester.getRect(find.byType(BalanceCard));

    // The card rides up onto the photograph rather than queueing below it.
    expect(card.top, lessThan(headerBottom));

    // And a touch inside the overlap still lands on the card. The card is
    // translated out of its layout box to get there, so this is only true
    // because hit testing follows the transform rather than the box.
    final probe = tester.hitTestOnBinding(Offset(card.center.dx, card.top + 8));
    expect(
      probe.path.map((entry) => entry.target),
      contains(tester.renderObject(find.byType(BalanceCard))),
    );
    expect(tester.takeException(), isNull);
  });

  group('MoneyCountUp', () {
    const amount = Money(15000000, 'KES');

    testWidgets('settles on exactly the amount it was given', (tester) async {
      await tester.pumpWidget(
        themed(
          child: const Scaffold(body: Center(child: MoneyCountUp(amount))),
        ),
      );

      // Mid-count it is showing something else entirely; that is the point.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text(amount.format()), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text(amount.format()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the amount directly under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: MoneyCountUp(amount))),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(amount.format()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
