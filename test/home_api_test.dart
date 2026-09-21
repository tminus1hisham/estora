import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:mall/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mall/modules/home/presentation/home_screen.dart';
import 'package:mall/modules/owner/presentation/owner_portfolio_screen.dart';
import 'package:mall/navigation/routes.dart';
import 'package:mall/services/providers.dart';
import 'package:mall/services/remote/api_client.dart';
import 'package:mall/services/remote/endpoints.dart';
import 'package:mall/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements TokenStore {
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens tokens) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final manager in [true, false]) {
    for (final status in [200, 204, 403]) {
      for (final scale in [1.0, 1.6]) {
        for (final desktop in manager ? [false, true] : [false]) {
          testWidgets(
            '${manager ? 'manager' : 'tenant'} home uses available operations ($status, text scale $scale, desktop $desktop)',
            (tester) async {
              tester.view.physicalSize = Size(
                desktop
                    ? 1440
                    : scale == 1
                    ? 390
                    : 320,
                844,
              );
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final tokens = _Tokens();
              SharedPreferences.setMockInitialValues({});
              final prefs = await SharedPreferences.getInstance();
              final paths = <String>[];
              final dio = Dio(
                BaseOptions(
                  baseUrl: 'https://test.invalid',
                  validateStatus: (_) => true,
                ),
              );
              dio.interceptors.add(
                InterceptorsWrapper(
                  onRequest: (request, handler) {
                    paths.add(request.path);
                    final account = request.path == Endpoints.account;
                    // The invoice route is keyed on the tenant record, which the
                    // app reads off the account's bookings.
                    final bookings = request.path == Endpoints.allBookings;
                    handler.resolve(
                      Response(
                        requestOptions: request,
                        statusCode: account || bookings || status == 204
                            ? 200
                            : status,
                        data: account
                            ? {'id': 1, 'userId': 'user-42'}
                            : bookings
                            ? [
                                {
                                  'id': 3,
                                  'tenant': {'id': 42, 'userId': 'user-42'},
                                },
                              ]
                            : status == 204
                            ? []
                            : status == 403
                            ? {'message': 'Access denied'}
                            : manager &&
                                  request.path == Endpoints.availableUnitsToBook
                            ? [
                                {
                                  'propertyId': 7,
                                  'blockId': 1,
                                  'availableUnitsGroupedBySize': [
                                    {'size': 100, 'count': 3},
                                    {'size': 200, 'count': 2},
                                  ],
                                },
                                {
                                  'propertyId': 7,
                                  'blockId': 2,
                                  'availableUnitsGroupedBySize': [
                                    {'size': 100, 'count': 3},
                                  ],
                                },
                                {
                                  'propertyId': 99,
                                  'blockId': 3,
                                  'availableUnitsGroupedBySize': [
                                    {'size': 100, 'count': 100},
                                  ],
                                },
                              ]
                            : manager
                            ? request.path != Endpoints.properties
                                  ? []
                                  : [
                                      {
                                        'id': 7,
                                        'propertyName': 'API Property',
                                        'city': 'Nairobi',
                                      },
                                    ]
                            : [
                                {
                                  'id': 8,
                                  'tenantId': 42,
                                  'invoiceDate': '2026-09-01',
                                  'dueDate': '2026-09-30',
                                  'totalAmount': 1000,
                                  'balanceDue': 1000,
                                },
                              ],
                      ),
                    );
                  },
                ),
              );
              addTearDown(dio.close);
              final router = GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => manager
                        ? const OwnerPortfolioScreen()
                        : const HomeScreen(),
                  ),
                  GoRoute(
                    path: '/destination',
                    name: manager ? Routes.ownerProperties : Routes.invoices,
                    builder: (_, _) =>
                        const Scaffold(body: Text('Destination')),
                  ),
                ],
              );
              addTearDown(router.dispose);
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    sharedPreferencesProvider.overrideWithValue(prefs),
                    tokenStoreProvider.overrideWithValue(tokens),
                    apiClientProvider.overrideWithValue(
                      ApiClient(tokenStore: tokens, dio: dio),
                    ),
                  ],
                  child: RepaintBoundary(
                    key: const ValueKey('home-preview'),
                    child: MaterialApp.router(
                      routerConfig: router,
                      debugShowCheckedModeBanner: false,
                      theme: scale == 1 ? AppTheme.light : AppTheme.dark,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.text(manager ? 'Your portfolio, at a glance.' : 'Welcome'),
                findsOneWidget,
              );
              expect(find.text('Feature unavailable'), findsNothing);
              if (manager && status != 403) {
                expect(
                  find.descendant(
                    of: find.byKey(const ValueKey('owner-available-spaces')),
                    matching: find.text(status == 200 ? '8' : '0'),
                  ),
                  findsOneWidget,
                );
                if (status == 200) {
                  expect(paths, contains(Endpoints.availableUnitsToBook));
                  expect(find.text('8 available'), findsOneWidget);
                }
              }
              if (status == 200) {
                expect(
                  find.text(manager ? 'API Property' : 'INV-8'),
                  findsOneWidget,
                );
              } else if (status == 204) {
                expect(
                  find.text(manager ? 'No properties yet' : 'No invoices yet'),
                  findsOneWidget,
                );
              } else {
                expect(
                  find.text(
                    manager
                        ? 'Properties could not be loaded.'
                        : 'Access denied',
                  ),
                  findsOneWidget,
                );
              }
              expect(
                paths,
                manager
                    ? containsAll([Endpoints.properties])
                    : [
                        Endpoints.account,
                        Endpoints.allBookings,
                        Endpoints.tenantInvoices('42'),
                      ],
              );
              expect(tester.takeException(), isNull);
              if (desktop && scale == 1 && status == 200) {
                final scrollable = tester.state<ScrollableState>(
                  find.byType(Scrollable).first,
                );
                expect(
                  scrollable.position.maxScrollExtent,
                  0,
                  reason:
                      'A small portfolio should fit on desktop without scrolling.',
                );
              }
              if (const bool.fromEnvironment('HOME_PREVIEWS') &&
                  scale == 1 &&
                  status != 403) {
                // Asset decoding runs outside the test clock. Wait for the
                // restored architectural image before capturing the banner.
                await tester.runAsync(
                  () => precacheImage(
                    const AssetImage('assets/images/property_sarit_mall.jpg'),
                    tester.element(find.byType(MaterialApp)),
                  ),
                );
                await tester.pumpAndSettle();
                await tester.runAsync(() async {
                  final boundary = tester.renderObject<RenderRepaintBoundary>(
                    find.byKey(const ValueKey('home-preview')),
                  );
                  final capture = await boundary.toImage();
                  final bytes = await capture.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory('artifacts/home').create(recursive: true);
                  await File(
                    'artifacts/home/${manager ? 'manager' : 'tenant'}-${status == 204 ? 'empty' : 'data'}-${desktop ? 'desktop' : 'phone'}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                  capture.dispose();
                });
              }
              if (manager) {
                expect(find.text('MAKE YOURSELF AT HOME'), findsNothing);
                expect(find.text('View properties'), findsNothing);
                expect(find.text('Add property'), findsNothing);
                return;
              }
              await tester.ensureVisible(find.text('View invoices'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('View invoices'));
              await tester.pumpAndSettle();
              expect(find.text('Destination'), findsOneWidget);
            },
          );
        }
      }
    }
  }
}
