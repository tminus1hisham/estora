import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estora/components/occupancy_meter.dart';
import 'package:estora/core/utils/money.dart';
import 'package:estora/domain/entities/owner.dart';
import 'package:estora/domain/entities/unit.dart';
import 'package:estora/domain/enums/domain_enums.dart';
import 'package:estora/modules/owner/presentation/owner_properties_screen.dart';
import 'package:estora/modules/owner/presentation/owner_property_screen.dart';
import 'package:estora/modules/structure/presentation/block_screen.dart';
import 'package:estora/navigation/routes.dart';
import 'package:estora/services/models/api_mappers.dart';
import 'package:estora/services/providers.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/storage/token_store.dart';

/// Occupancy for the owner: the contract publishes no figure, so the app
/// counts the unit records the server sends and shows the same share on the
/// property card, the property, the block list and the block.

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

Unit _unit(String id, String blockId, UnitStatus status) => Unit(
  id: id,
  propertyId: '7',
  buildingId: blockId,
  unitNumber: id,
  unitCode: id,
  category: UnitCategory.shop,
  baseRent: Money.fromMajor(1000, 'KES'),
  billingFrequency: BillingFrequency.monthly,
  status: status,
);

/// Twelve units across two blocks: North Wing lets 6 of 8, South Wing 1 of 4.
/// Seven of twelve let is 58%, which rounds the same way as the screen does.
List<Map<String, Object?>> _unitRows() {
  Map<String, Object?> row(int id, int block, int status) => {
    'id': id,
    'propertyId': 7,
    'blockId': block,
    'unitNumber': 'U$id',
    'type': 0,
    'status': status,
    'monthlyRent': 1000,
    'currencyCode': 'KES',
  };
  return [
    for (var i = 1; i <= 6; i++) row(i, 1, 3), // leased
    row(7, 1, 1), // booked
    row(8, 1, 0), // available
    row(9, 2, 3), // leased
    row(10, 2, 2), // reserved
    row(11, 2, 0), // available
    row(12, 2, 4), // blocked
  ];
}

void main() {
  group('UnitMix.of', () {
    test('counts each status into the bucket the strip draws', () {
      final mix = UnitMix.of([
        _unit('a', 'b1', UnitStatus.leased),
        _unit('b', 'b1', UnitStatus.leased),
        _unit('c', 'b1', UnitStatus.booked),
        _unit('d', 'b1', UnitStatus.reserved),
        _unit('e', 'b1', UnitStatus.available),
        _unit('f', 'b1', UnitStatus.underMaintenance),
        _unit('g', 'b1', UnitStatus.blocked),
        _unit('h', 'b1', UnitStatus.unknown),
      ]);
      expect(mix.leased, 2);
      expect(mix.booked, 2);
      expect(mix.available, 1);
      expect(mix.unavailable, 3);
      expect(mix.total, 8);
    });

    test('occupancy is let over all, and zero for nothing', () {
      const mix = UnitMix(leased: 7, booked: 2, available: 2, unavailable: 1);
      expect(mix.occupancy, closeTo(7 / 12, 0.0001));
      expect(mix.occupancyPercent, 58);
      expect(mix.occupancyLabel, '7 of 12 let');
      expect(const UnitMix().occupancy, 0);
      expect(const UnitMix().occupancyPercent, 0);
    });

    test('PropertyOccupancy splits the same count by block', () {
      final occupancy = PropertyOccupancy.of([
        _unit('a', 'north', UnitStatus.leased),
        _unit('b', 'north', UnitStatus.available),
        _unit('c', 'south', UnitStatus.leased),
        _unit('d', 'south', UnitStatus.leased),
        _unit('e', 'south', UnitStatus.booked),
        _unit('f', 'south', UnitStatus.blocked),
      ]);
      expect(occupancy.mix.total, 6);
      expect(occupancy.mix.leased, 3);
      expect(occupancy.forBlock('north')?.occupancyPercent, 50);
      expect(occupancy.forBlock('south')?.occupancyPercent, 50);
      expect(occupancy.forBlock('south')?.total, 4);
      expect(occupancy.forBlock('west'), isNull);
    });
  });

  group('propertyFromJson', () {
    test('counts the mix from the units the payload embeds', () {
      final property = propertyFromJson({
        'id': 7,
        'propertyName': 'Riverside Court',
        'city': 'Nairobi',
        'country': 'Kenya',
        'units': _unitRows(),
      });
      expect(property.mix, isNotNull);
      expect(property.mix!.total, 12);
      expect(property.mix!.leased, 7);
      expect(property.mix!.occupancyPercent, 58);
    });

    test('leaves the mix unstated when the payload has no units', () {
      final property = propertyFromJson({
        'id': 7,
        'propertyName': 'Riverside Court',
        'city': 'Nairobi',
        'country': 'Kenya',
      });
      expect(property.mix, isNull);
    });
  });

  testWidgets('OccupancyMeter states the share, the count and the bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OccupancyMeter(mix: UnitMix(leased: 9, available: 3)),
              OccupancyMeter(
                mix: UnitMix(leased: 9, available: 3),
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('9 of 12 let'), findsOneWidget);
    expect(find.text('75% let'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the owner sees occupancy on the card, the property, its blocks and a block',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final record = {
        'id': 7,
        'propertyName': 'Riverside Court',
        'city': 'Nairobi',
        'country': 'Kenya',
        'totalUnits': 12,
        'units': _unitRows(),
      };
      final blocks = [
        {'id': 1, 'propertyId': 7, 'blockName': 'North Wing', 'status': 0},
        {'id': 2, 'propertyId': 7, 'blockName': 'South Wing', 'status': 0},
      ];
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
            final path = request.path;
            final Object data;
            if (path == Endpoints.properties) {
              data = [record];
            } else if (path == Endpoints.property('7')) {
              // The single fetch carries no units, so the screen has to count
              // them itself rather than lean on the list payload.
              data = {...record}..remove('units');
            } else if (path == Endpoints.propertyUnits('7')) {
              data = _unitRows();
            } else if (path == Endpoints.propertyBlocks('7')) {
              data = blocks;
            } else if (path == Endpoints.block('1')) {
              data = blocks.first;
            } else if (path == Endpoints.blockUnits('1')) {
              data = _unitRows().where((row) => row['blockId'] == 1).toList();
            } else {
              data = <Object>[];
            }
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
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
          GoRoute(
            path: '/blocks/:blockId',
            name: Routes.blockDetail,
            builder: (_, state) =>
                BlockScreen(blockId: state.pathParameters['blockId']!),
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

      // The card: counted from the units the list embeds, no extra call.
      expect(find.text('58% let'), findsOneWidget);
      expect(paths, isNot(contains(Endpoints.propertyUnits('7'))));

      // The property: counted from its own unit records.
      await tester.tap(find.text('Riverside Court'));
      await tester.pumpAndSettle();
      expect(paths, contains(Endpoints.propertyUnits('7')));
      expect(find.text('Occupancy'), findsOneWidget);
      expect(find.text('58% let'), findsOneWidget);
      expect(find.text('7 of 12 let'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The blocks sit on the property screen, every one of them, open or
      // full — and again as the unit list's filter chips.
      expect(find.text('North Wing'), findsNWidgets(2));
      expect(find.text('South Wing'), findsNWidgets(2));
      expect(find.text('None available'), findsNWidgets(2));

      // The units line up beneath, narrowed by block name.
      final southChip = find.widgetWithText(ChoiceChip, 'South Wing');
      await tester.ensureVisible(southChip);
      await tester.pumpAndSettle();
      expect(find.text('12 UNITS'), findsOneWidget);
      await tester.tap(southChip);
      await tester.pumpAndSettle();
      expect(find.text('4 UNITS'), findsOneWidget);
      await tester.ensureVisible(find.text('North Wing').first);
      await tester.pumpAndSettle();

      // One block, in a sheet: counted from the units listed beneath it.
      await tester.tap(find.text('North Wing').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('6 of 8 let'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
