import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/domain/repositories/repositories.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/services/remote/remote_repositories.dart';
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

/// The live route's own answer, verbatim: one block with stock, grouped by
/// size, and no unit ids anywhere.
const _availability = [
  {
    'propertyId': 2,
    'propertyName': 'Grace Mall',
    'blockId': 2,
    'blockName': 'North Wing',
    'availableUnitsGroupedBySize': [
      {'size': 480, 'count': 10},
    ],
  },
];

Map<String, Object?> _unit({
  required int id,
  required int blockId,
  required num area,
  int status = 0,
}) => {
  'id': id,
  'propertyId': 2,
  'blockId': blockId,
  'unitNumber': 'U$id',
  'areaSqFeet': area,
  'monthlyRent': 45000,
  'status': status,
};

/// North Wing has two 480 sq ft shops, a 480 one already let, and a 900 one
/// the engine did not list. South Wing is not in stock at all.
final _units = [
  _unit(id: 1, blockId: 2, area: 480),
  _unit(id: 2, blockId: 2, area: 480),
  _unit(id: 3, blockId: 2, area: 480, status: 3),
  _unit(id: 4, blockId: 2, area: 900),
  _unit(id: 5, blockId: 3, area: 480),
];

({RemoteUnitRepository units, List<String> paths}) _repository({
  List<Map<String, Object?>> availability = _availability,
  int engineStatus = 200,
}) {
  final paths = <String>[];
  final dio = Dio(
    BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        paths.add(request.path);
        final Object data;
        if (request.path == Endpoints.availableUnitsToBook) {
          data = engineStatus == 200
              ? availability
              : const {'message': 'Something went wrong'};
        } else if (request.path == Endpoints.blockUnits('2')) {
          data = _units.where((u) => u['blockId'] == 2).toList();
        } else if (request.path == Endpoints.propertyUnits('2')) {
          data = _units;
        } else {
          data = const {'message': 'Unauthorized'};
        }
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: data is! Map
                ? 200
                : request.path == Endpoints.availableUnitsToBook
                ? engineStatus
                : 401,
            data: data,
          ),
        );
      },
    ),
  );
  return (
    units: RemoteUnitRepository(ApiClient(tokenStore: _Tokens(), dio: dio)),
    paths: paths,
  );
}

void main() {
  test(
    'browse asks the availability engine, then fetches what it named',
    () async {
      final (:units, :paths) = _repository();

      final result = await units.listUnits(
        filter: const UnitFilter(propertyId: '2'),
      );

      final page = (result as Ok<Page<dynamic>>).value;
      expect(page.items.map((u) => u.id), ['1', '2']);
      // One block in stock, so the property-wide route was never paid for.
      expect(paths, [
        Endpoints.availableUnitsToBook,
        Endpoints.blockUnits('2'),
      ]);
    },
  );

  test('a property the engine does not name has nothing to fetch', () async {
    final (:units, :paths) = _repository();

    final result = await units.listUnits(
      filter: const UnitFilter(propertyId: '9'),
    );

    expect(result.valueOrNull!.items, isEmpty);
    expect(paths, [Endpoints.availableUnitsToBook]);
  });

  test(
    'a block filter outside the stock answers empty without a fetch',
    () async {
      final (:units, :paths) = _repository();

      final result = await units.listUnits(
        filter: const UnitFilter(propertyId: '2', buildingId: '3'),
      );

      expect(result.valueOrNull!.items, isEmpty);
      expect(paths, [Endpoints.availableUnitsToBook]);
    },
  );

  test('a listing that is not about booking never asks the engine', () async {
    final (:units, :paths) = _repository();

    final result = await units.listUnits(
      filter: const UnitFilter(propertyId: '2', availableOnly: false),
    );

    expect(result.valueOrNull!.items.length, 5);
    expect(paths, [Endpoints.propertyUnits('2')]);
  });

  test('an empty engine answer is nothing to book, not an error', () async {
    final (:units, :paths) = _repository(availability: const []);

    expect((await units.listUnits()).valueOrNull!.items, isEmpty);
    expect(paths, [Endpoints.availableUnitsToBook]);
  });

  test('the engine refusing is the browse failing', () async {
    final (:units, :paths) = _repository(engineStatus: 500);

    expect(await units.listUnits(), isA<Err<Page<dynamic>>>());
    expect(paths, [Endpoints.availableUnitsToBook]);
  });
}
