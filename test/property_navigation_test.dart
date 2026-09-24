import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estora/modules/owner/presentation/owner_properties_screen.dart';
import 'package:estora/modules/owner/presentation/owner_property_screen.dart';
import 'package:estora/navigation/routes.dart';
import 'package:estora/services/providers.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/storage/token_store.dart';

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
  for (final failsFirst in [false, true]) {
    testWidgets('property tap loads its API record (retry: $failsFirst)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final paths = <String>[];
      var fail = failsFirst;
      final record = {
        'id': 7,
        'propertyName': 'Riverside Court',
        'city': 'Nairobi',
        'country': 'Kenya',
        'description': 'Shops beside the river',
        'totalUnits': 12,
        'totalAreaSqFeet': 2400,
      };
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
            final detail = request.path == Endpoints.property('7');
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: detail && fail ? 500 : 200,
                data: detail && fail
                    ? {'message': 'Please retry'}
                    : detail
                    ? record
                    : request.path == Endpoints.properties
                    ? [record]
                    : [],
              ),
            );
          },
        ),
      );
      addTearDown(dio.close);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const OwnerPropertiesScreen()),
          GoRoute(
            path: '/properties/:propertyId',
            name: Routes.ownerProperty,
            builder: (_, state) => OwnerPropertyScreen(
              propertyId: state.pathParameters['propertyId']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(
              ApiClient(tokenStore: _Tokens(), dio: dio),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riverside Court'));
      await tester.pumpAndSettle();
      expect(paths, contains(Endpoints.property('7')));
      if (failsFirst) {
        expect(find.text('Shops beside the river'), findsNothing);
        fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Shops beside the river'), findsOneWidget);
      expect(find.text('Nairobi, Kenya'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('View blocks and units'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final requestsBeforeRefresh = paths
          .where((path) => path == Endpoints.property('7'))
          .length;
      record['description'] = 'Updated property description';
      await tester.drag(find.byType(ListView).last, const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(
        paths.where((path) => path == Endpoints.property('7')).length,
        requestsBeforeRefresh + 1,
      );
      expect(find.text('Updated property description'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OwnerPropertiesScreen), findsOneWidget);
    });
  }
}
