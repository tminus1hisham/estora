import 'dart:math' as math;
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/error/failure.dart';
import 'package:estora/services/json.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/services/remote/remote_repositories.dart';
import 'package:estora/storage/token_store.dart';

void main() {
  test(
    'identity coalesces reads and rejects old account completions',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.invalid',
          validateStatus: (_) => true,
        ),
      );
      addTearDown(dio.close);
      var calls = 0;
      var status = 200;
      var gate = Completer<void>();
    var entered = Completer<void>();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            calls++;
            if (!entered.isCompleted) entered.complete();
            await gate.future;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: status,
                data: request.path == Endpoints.account
                    ? {'userId': 'old-user'}
                    : [
                        {'id': 7, 'userId': 'old-user'},
                      ],
              ),
            );
          },
        ),
      );
      final identity = AccountIdentity(
        ApiClient(tokenStore: _Tokens(), dio: dio),
      );
      final loads = List.generate(20, (_) => identity.load());
      await entered.future;
      expect(calls, 1);
      gate.complete();
      expect((await Future.wait(loads)).every((r) => r.isOk), isTrue);
      calls = 0;
      gate = Completer<void>();
    entered = Completer<void>();
      final tenants = List.generate(20, (_) => identity.tenantId());
      await entered.future;
      expect(calls, 1);
      await identity.forget();
      await identity.remember(<String, dynamic>{
        'userId': 'new-user',
        'tenantId': 9,
      });
      gate.complete();
      for (final result in await Future.wait(tenants)) {
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      }
      expect((await identity.tenantId()).valueOrNull, '9');
      identity.expire();
      gate = Completer<void>();
    entered = Completer<void>();
      final oldLoad = identity.load();
      await entered.future;
      await identity.forget();
      await identity.remember(<String, dynamic>{'userId': 'new-user'});
      gate.complete();
      expect((await oldLoad).failureOrNull, isA<UnauthorizedFailure>());
      expect((await identity.load()).valueOrNull!['userId'], 'new-user');
      identity.expire();
      status = 500;
      expect((await identity.load()).isOk, isFalse);
      status = 200;
      expect((await identity.load()).valueOrNull, isA<Json>());
    },
  );

  for (final count in [1, 20, 100]) {
    test('report benchmark: $count properties, 10ms per request', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      addTearDown(dio.close);
      var active = 0;
      var peak = 0;
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests++;
            final isInvoice = request.path.startsWith(
              '/payments/get/invoices/property/',
            );
            if (isInvoice) peak = math.max(peak, ++active);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            if (isInvoice) active--;
            final Object data = request.path == Endpoints.properties
                ? List.generate(
                    count,
                    (i) => {'id': i + 1, 'propertyName': 'Property $i'},
                  )
                : isInvoice
                ? [
                    {
                      'id': request.path.split('/').last,
                      'propertyId': request.path.split('/').last,
                      'totalAmount': 1000,
                      'balanceDue': 1000,
                    },
                  ]
                : <Object>[];
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final api = ApiClient(tokenStore: _Tokens(), dio: dio);
      final clock = Stopwatch()..start();
      final result = await RemoteOwnerRepository(api).getReport();
      clock.stop();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.invoices.length, count);
      expect(requests, count + 3);
      expect(peak, math.min(count, 4));
      // Printed by the explicit benchmark command, never by the application.
      // ignore: avoid_print
      print(
        'REPORT properties=$count elapsed_ms=${clock.elapsedMilliseconds} requests=$requests peak_invoices=$peak',
      );
    });
  }
}

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
