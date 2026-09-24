// How the app keeps a session alive once the access token runs out.
//
// The live server keeps `/auth/refresh/token` behind the same bearer gate as
// every other route, so a token that has *already* expired cannot be renewed
// at all: the renewal has to happen just before. These tests pin down that
// pre-flight renewal, the 401 fallback, and the one distinction that decides
// whether a tenant is signed out — a server that refused versus one that
// could not be reached.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/error/failure.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/storage/token_store.dart';

class _Tokens implements TokenStore {
  _Tokens([this.tokens]);
  AuthTokens? tokens;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}

/// A request as the fake server saw it: the path, the bearer it carried and
/// the body it sent.
typedef _Seen = ({String path, String? bearer, Object? body});

/// A client over a stand-in server. [answer] decides each response — or
/// rejects it, to stand in for a network that is down — and every request is
/// recorded in [seen] so a test can say what went out, carrying what, and in
/// what order.
///
/// The server is installed *after* the client's own interceptors, where a
/// real transport sits, so a request reaches it with its bearer attached.
({ApiClient api, Dio dio}) _client(
  TokenStore store,
  List<_Seen> seen,
  void Function(RequestOptions request, RequestInterceptorHandler handler)
  answer, {
  void Function()? onAuthLost,
}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
  );
  final api = ApiClient(tokenStore: store, dio: dio, onAuthLost: onAuthLost);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        seen.add((
          path: request.path,
          bearer: request.headers['Authorization'] as String?,
          body: request.data,
        ));
        answer(request, handler);
      },
    ),
  );
  return (api: api, dio: dio);
}

void _ok(RequestOptions request, RequestInterceptorHandler handler) =>
    handler.resolve(
      Response(requestOptions: request, statusCode: 200, data: {'id': 1}),
    );

void _renewed(RequestOptions request, RequestInterceptorHandler handler) =>
    handler.resolve(
      Response(
        requestOptions: request,
        statusCode: 200,
        data: {'token': 'a2', 'refreshToken': 'r2'},
      ),
    );

void _unauthorized(RequestOptions request, RequestInterceptorHandler handler) =>
    handler.resolve(
      Response(
        requestOptions: request,
        statusCode: 401,
        data: {'message': 'refused'},
      ),
    );

void _offline(RequestOptions request, RequestInterceptorHandler handler) =>
    handler.reject(
      DioException.connectionError(requestOptions: request, reason: 'offline'),
    );

AuthTokens _tokens({required Duration expiresIn, String refresh = 'r1'}) =>
    AuthTokens(
      accessToken: 'a1',
      refreshToken: refresh,
      expiresAt: DateTime.now().add(expiresIn),
    );

/// An unsigned JWT whose payload carries [claims].
String _jwt(Map<String, Object?> claims) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return '${segment({'alg': 'none'})}.${segment(claims)}.sig';
}

void main() {
  group('expiry', () {
    test('is read off the JWT when the response states none', () {
      final exp = DateTime.utc(2030, 1, 1, 12);
      final token = _jwt({
        'sub': '42',
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
      });
      expect(AuthTokens.jwtExpiry(token), exp);
      expect(AuthTokens.expiryOf(token), exp);
    });

    test('a stated expiry wins over the claim', () {
      final token = _jwt({'exp': 4102444800});
      expect(
        AuthTokens.expiryOf(token, stated: '2027-06-01T00:00:00Z'),
        DateTime.utc(2027, 6, 1),
      );
    });

    test('an opaque token falls back to the assumed life', () {
      final before = DateTime.now().add(AuthTokens.assumedLife);
      final expiry = AuthTokens.expiryOf('not-a-jwt');
      expect(AuthTokens.jwtExpiry('not-a-jwt'), isNull);
      expect(AuthTokens.jwtExpiry('a.b'), isNull);
      expect(AuthTokens.jwtExpiry('a.!!.c'), isNull);
      expect(expiry.isBefore(before), isFalse);
    });
  });

  group('renewal', () {
    test(
      'a nearly expired token is renewed before the request goes out',
      () async {
        final store = _Tokens(_tokens(expiresIn: const Duration(seconds: 30)));
        final seen = <_Seen>[];
        final (:api, :dio) = _client(store, seen, (request, handler) {
          request.path == Endpoints.refresh
              ? _renewed(request, handler)
              : _ok(request, handler);
        });

        final result = await api.get(Endpoints.account, parse: (json) => json);

        expect(result.isOk, isTrue);
        expect(seen.map((s) => s.path), [Endpoints.refresh, Endpoints.account]);
        // The renewal presents the expiring token both ways the server reads
        // it: the gate wants the bearer, the route wants the body.
        expect(seen.first.bearer, 'Bearer a1');
        expect(seen.first.body, {'token': 'a1', 'refreshToken': 'r1'});
        // The request itself carries the new one.
        expect(seen.last.bearer, 'Bearer a2');
        expect(store.tokens?.accessToken, 'a2');
        expect(store.tokens?.refreshToken, 'r2');
        dio.close();
      },
    );

    test('a token with time left is not renewed', () async {
      final store = _Tokens(_tokens(expiresIn: const Duration(minutes: 30)));
      final seen = <_Seen>[];
      final (:api, :dio) = _client(store, seen, _ok);

      await api.get(Endpoints.account, parse: (json) => json);

      expect(seen.map((s) => s.path), [Endpoints.account]);
      expect(seen.single.bearer, 'Bearer a1');
      dio.close();
    });

    test('a 401 renews the token and retries once', () async {
      final store = _Tokens(_tokens(expiresIn: const Duration(minutes: 30)));
      final seen = <_Seen>[];
      var lost = 0;
      final (:api, :dio) = _client(store, seen, (request, handler) {
        if (request.path == Endpoints.refresh) {
          _renewed(request, handler);
        } else if (request.headers['Authorization'] == 'Bearer a2') {
          _ok(request, handler);
        } else {
          _unauthorized(request, handler);
        }
      }, onAuthLost: () => lost++);

      final result = await api.get(Endpoints.account, parse: (json) => json);

      expect(result.isOk, isTrue);
      expect(seen.map((s) => s.path), [
        Endpoints.account,
        Endpoints.refresh,
        Endpoints.account,
      ]);
      expect(seen.last.bearer, 'Bearer a2');
      expect(lost, 0);
      dio.close();
    });

    test('a renewal the server refuses ends the session', () async {
      final store = _Tokens(_tokens(expiresIn: const Duration(seconds: 30)));
      final seen = <_Seen>[];
      var lost = 0;
      final (:api, :dio) = _client(
        store,
        seen,
        _unauthorized,
        onAuthLost: () => lost++,
      );

      final result = await api.get(Endpoints.account, parse: (json) => json);

      expect(result, isA<Err<Object?>>());
      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(store.tokens, isNull);
      // Once: the pre-flight refusal is left for the 401 path to act on, and
      // that path finds nothing stored rather than asking the server again.
      expect(lost, 1);
      expect(seen.where((s) => s.path == Endpoints.refresh).length, 1);
      dio.close();
    });

    test('a renewal that cannot reach the server keeps the session', () async {
      final store = _Tokens(_tokens(expiresIn: const Duration(minutes: 30)));
      final seen = <_Seen>[];
      var lost = 0;
      final (:api, :dio) = _client(store, seen, (request, handler) {
        request.path == Endpoints.refresh
            ? _offline(request, handler)
            : _unauthorized(request, handler);
      }, onAuthLost: () => lost++);

      final result = await api.get(Endpoints.account, parse: (json) => json);

      // A network error, so the screen offers a retry — not a sign-in.
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(store.tokens?.accessToken, 'a1');
      expect(lost, 0);
      dio.close();
    });

    test('concurrent expiries share one renewal', () async {
      final store = _Tokens(_tokens(expiresIn: const Duration(seconds: 30)));
      final seen = <_Seen>[];
      final (:api, :dio) = _client(store, seen, (request, handler) {
        request.path == Endpoints.refresh
            ? _renewed(request, handler)
            : _ok(request, handler);
      });

      final results = await Future.wait([
        api.get(Endpoints.account, parse: (json) => json),
        api.get(Endpoints.properties, parse: (json) => json),
        api.get(Endpoints.property('1'), parse: (json) => json),
      ]);

      expect(results.every((r) => r.isOk), isTrue);
      expect(seen.where((s) => s.path == Endpoints.refresh).length, 1);
      expect(
        seen.where((s) => s.path != Endpoints.refresh).map((s) => s.bearer),
        everyElement('Bearer a2'),
      );
      dio.close();
    });

    test('a sign-in never triggers a renewal', () async {
      // A stale token left behind is not a reason to renew on the way *in*,
      // and a 401 there is a wrong password, not an expiry.
      final store = _Tokens(_tokens(expiresIn: const Duration(seconds: 30)));
      final seen = <_Seen>[];
      var lost = 0;
      final (:api, :dio) = _client(
        store,
        seen,
        _unauthorized,
        onAuthLost: () => lost++,
      );

      await api.post(Endpoints.login, body: const {}, parse: (json) => json);

      expect(seen.map((s) => s.path), [Endpoints.login]);
      expect(lost, 0);
      expect(store.tokens, isNotNull);
      dio.close();
    });
  });
}
