import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/debug/debug_log.dart';
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../storage/token_store.dart';
import '../json.dart';
import 'endpoints.dart';
import 'logging_interceptor.dart';

/// The HTTP transport for the remote repositories.
///
/// Responsibilities kept here rather than in each repository:
///
/// * attaching the bearer token,
/// * refreshing it with rotation on a 401 (section 74),
/// * attaching `Idempotency-Key` on financial writes (section 66),
/// * unwrapping the `data` envelope,
/// * mapping transport and HTTP errors onto [Failure].
///
/// Repositories therefore contain only endpoint choice and mapping.
class ApiClient {
  ApiClient({required TokenStore tokenStore, Dio? dio, this.onAuthLost})
    : _tokenStore = tokenStore,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiRoot,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              contentType: Headers.jsonContentType,
              // Non-2xx is handled below rather than thrown as a surprise.
              validateStatus: (status) => status != null && status < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final tokens = await _tokenStore.read();
          if (tokens != null) {
            options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
          }
          handler.next(options);
        },
      ),
    );

    // Added after the auth interceptor so it logs the request as it actually
    // goes out, bearer token and all.
    //
    // Guarded rather than left to disable itself: an interceptor that is never
    // installed cannot spend a release build's time formatting a payload that
    // would then be discarded.
    if (DebugLog.enabled) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Called when the refresh token is rejected and the session cannot be
  /// recovered. The app listens for this to route back to login.
  final void Function()? onAuthLost;

  /// Guards against a burst of concurrent 401s each firing its own refresh.
  Future<AuthTokens?>? _inFlightRefresh;

  Dio get raw => _dio;

  Future<Result<T>> get<T>(
    String path, {
    Json? query,
    required T Function(Json json) parse,
  }) => _send(path, parse: parse, method: 'GET', query: query);

  Future<Result<T>> post<T>(
    String path, {
    Json? body,
    Json? query,
    String? idempotencyKey,
    required T Function(Json json) parse,
  }) => _send(
    path,
    parse: parse,
    method: 'POST',
    body: body,
    query: query,
    idempotencyKey: idempotencyKey,
  );

  Future<Result<T>> put<T>(
    String path, {
    Json? body,
    required T Function(Json json) parse,
  }) => _send(path, parse: parse, method: 'PUT', body: body);

  /// For endpoints that return no meaningful body.
  ///
  /// Several of the contract's writes take their arguments in the query string
  /// rather than in a body — the role and claim routes especially — hence
  /// [query] alongside [body].
  Future<Result<void>> command(
    String path, {
    Json? body,
    Json? query,
    String method = 'POST',
    String? idempotencyKey,
  }) => _send<void>(
    path,
    method: method,
    body: body,
    query: query,
    idempotencyKey: idempotencyKey,
    parse: (_) {},
  );

  Future<Result<T>> upload<T>(
    String path, {
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    Json? fields,
    required T Function(Json json) parse,
  }) async {
    final formData = FormData.fromMap({
      ...?fields,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    return _send(path, method: 'POST', formData: formData, parse: parse);
  }

  Future<Result<T>> _send<T>(
    String path, {
    required String method,
    required T Function(Json json) parse,
    Json? body,
    Json? query,
    FormData? formData,
    String? idempotencyKey,
    bool isRetry = false,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: formData ?? body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            // Section 66. Present on every financial write so a retry over a
            // flaky mobile network cannot charge twice.
            'Idempotency-Key': ?idempotencyKey,
          },
        ),
      );

      final status = response.statusCode ?? 0;

      // A 401 on a route that runs before a session exists is the server
      // answering the request, not a token expiring: there is nothing to
      // refresh, and treating it as an expiry would sign out whoever was
      // already here over a mistyped password.
      if (status == 401 && !isRetry && !Endpoints.preSession.contains(path)) {
        DebugLog.write('auth', '401 on $method $path — refreshing the session');
        final refreshed = await _refresh();
        if (refreshed == null) {
          DebugLog.write(
            'auth',
            'Refresh did not recover the session; signing out',
          );
          onAuthLost?.call();
          return const Err(UnauthorizedFailure());
        }
        DebugLog.write('auth', 'Refreshed — retrying $method $path once');
        return _send(
          path,
          method: method,
          parse: parse,
          body: body,
          query: query,
          formData: formData,
          idempotencyKey: idempotencyKey,
          isRetry: true,
        );
      }

      if (status >= 400) {
        return Err(_failureFromResponse(status, response.data, path: path));
      }

      final data = response.data;
      final json = switch (data) {
        // The published contract returns bare objects and bare arrays: there
        // is no envelope. An array is boxed under `data` so that a parse
        // function has one shape to read either way — see `listFromJson`.
        //
        // A *one-element* array is also spread over the top level, because the
        // live server answers every GET with an array — the single-record
        // fetches included. `GET /properties/get/property/1` comes back as
        // `[{...}]`, not `{...}`, and boxing that under `data` alone left an
        // object parser like `propertyFromJson` reading fields off a map that
        // held only `data`: a property with an empty id, and a detail screen
        // that rendered blank under a list that had just rendered fine.
        //
        // `data` is written last so it always wins for the list parsers; the
        // record's own fields fill in around it for the object parsers.
        List list when list.length == 1 && list.first is Map<String, dynamic> =>
          <String, dynamic>{...list.first as Json, 'data': list},
        List list => <String, dynamic>{'data': list},
        // Accept response envelopes as well as the published bare responses.
        Map<String, dynamic> map when map.containsKey('data') =>
          map['data'] is Map<String, dynamic>
              ? map['data'] as Json
              : <String, dynamic>{'data': map['data'], 'meta': map['meta']},
        Map<String, dynamic> map => map,
        // A route that answers with a bare string or number — or with nothing
        // at all. `command` ignores this; anything that needed a value would
        // have failed on the status code first.
        null => <String, dynamic>{},
        _ => <String, dynamic>{'data': data},
      };

      return Ok(parse(json));
    } on DioException catch (e) {
      // The interceptor has already logged the transport's account of this.
      // What is added here is the failure the app will act on, which is the
      // half a screen's error state is built from.
      final failure = _failureFromDio(e);
      DebugLog.write('api', '$method $path -> $failure');
      return Err(failure);
    } catch (e, stackTrace) {
      // Nearly always a mapper reading a field the server did not send. The
      // stack trace names the line; without it this reaches the tenant as
      // "Something went wrong" and leaves no trace of where it came from.
      DebugLog.write(
        'api',
        '$method $path -> unhandled ${e.runtimeType} reading the response',
        error: e,
        stackTrace: stackTrace,
      );
      // A mapper that throws a FormatException wrote its message for the
      // tenant — "the request was received, but…" — so it is passed on as
      // written rather than prefixed with the exception's own name.
      return Err(
        UnknownFailure(
          e is FormatException && e.message.isNotEmpty
              ? e.message
              : e.toString(),
        ),
      );
    }
  }

  /// Section 74's refresh token rotation.
  ///
  /// The server is expected to return a *new* refresh token, invalidating the
  /// old one, so a stolen token has a short useful life. Concurrent callers
  /// share one in-flight refresh rather than racing.
  Future<AuthTokens?> _refresh() {
    return _inFlightRefresh ??= _performRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<AuthTokens?> _performRefresh() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) {
      DebugLog.write(
        'auth',
        'Nothing stored to refresh; no session to recover',
      );
      return null;
    }

    try {
      final response = await _dio.post<dynamic>(
        Endpoints.refresh,
        // The contract's refresh takes *both* tokens: the expired one names
        // the session, the refresh token authorises renewing it.
        data: {
          'token': tokens.accessToken,
          'refreshToken': tokens.refreshToken,
        },
        options: Options(headers: {'Authorization': null}),
      );

      if ((response.statusCode ?? 0) >= 400) {
        DebugLog.write(
          'auth',
          'Refresh refused with ${response.statusCode} — clearing the session',
          detail: response.data,
        );
        await _tokenStore.clear();
        return null;
      }

      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? (data['data'] as Json? ?? data)
          : <String, dynamic>{};

      final access = (payload['token'] ?? payload['accessToken'])?.toString();
      final refresh = payload['refreshToken']?.toString();
      if (access == null || access.isEmpty) {
        DebugLog.write(
          'auth',
          'Refresh answered without a token — clearing the session',
          detail: payload,
        );
        await _tokenStore.clear();
        return null;
      }

      final updated = AuthTokens(
        accessToken: access,
        // A server that rotates the refresh token sends a new one; one that
        // does not leaves the existing token in force rather than blanking it.
        refreshToken: (refresh == null || refresh.isEmpty)
            ? tokens.refreshToken
            : refresh,
        // No expiry on the wire. Assumed short, and re-checked on the next
        // 401 regardless — the same assumption `RemoteAuthRepository` makes
        // when it first stores a token.
        expiresAt:
            DateTime.tryParse(payload['expiresAt']?.toString() ?? '') ??
            DateTime.now().add(const Duration(hours: 1)),
      );
      await _tokenStore.write(updated);
      DebugLog.write(
        'auth',
        'Session refreshed; the refresh token '
            '${refresh == null || refresh.isEmpty ? 'was not rotated' : 'rotated'}'
            ', access expires ${updated.expiresAt.toIso8601String()}',
      );
      return updated;
    } on DioException catch (e) {
      // A network blip is not a reason to destroy the session; only an explicit
      // rejection above clears the tokens.
      DebugLog.write(
        'auth',
        'Refresh could not reach the server (${e.type.name}); leaving the '
            'stored session alone',
      );
      return null;
    }
  }

  Failure _failureFromResponse(int status, Object? data, {String? path}) {
    final envelope = data is Map<String, dynamic>
        ? (data['error'] as Json? ?? data)
        : const <String, dynamic>{};
    final message = _message(envelope);

    return switch (status) {
      400 => ValidationFailure(
        message ?? 'That request could not be processed.',
        fieldErrors: _fieldErrors(envelope),
      ),
      401 => UnauthorizedFailure(
        message ??
            // No session has expired on the way *in* — the route asked for was
            // the one that would have started it. The server usually declines
            // these without a word, so the fallback carries the whole message.
            (path != null && Endpoints.preSession.contains(path)
                ? 'Those details were not accepted. Please check them and '
                      'try again.'
                : 'Your session has expired. Please sign in again.'),
      ),
      // Section 74: a tenant reaching another tenant's record must be refused
      // outright, not retried.
      403 => ForbiddenFailure(
        message ?? 'You do not have access to this item.',
      ),
      404 => NotFoundFailure(message ?? 'We could not find that item.'),
      409 => ConflictFailure(
        message ?? 'That is no longer possible. Please refresh and try again.',
      ),
      422 => ValidationFailure(
        message ?? 'Please check the details you entered.',
        fieldErrors: _fieldErrors(envelope),
      ),
      429 => ServerFailure(
        message ?? 'Too many attempts. Please wait a moment and try again.',
      ),
      _ => ServerFailure(
        message ?? 'Something went wrong on our side. Please try again.',
      ),
    };
  }

  /// The server's own words, whichever of its three shapes carried them.
  ///
  /// The API states a failure in three different ways, and only one of them
  /// uses `message`:
  ///
  /// * `{"message": "User not found"}` — the hand-written responses.
  /// * `{"success": false, "errors": ["User not found"]}` — the auth routes,
  ///   which answer sign-in failures this way rather than with `message`.
  /// * `{"title": "...", "errors": {"Password": ["..."]}}` — ASP.NET's
  ///   built-in model validation, when a required field is missing.
  ///
  /// Reading only the first turned every sign-in failure into the generic
  /// fallback, which told the tenant nothing.
  String? _message(Json envelope) {
    final message = envelope['message']?.toString();
    if (message != null && message.isNotEmpty) return message;

    // The auth routes' flat list. The first entry is the reason; any others
    // are detail the sign-in screen has nowhere to put.
    final errors = envelope['errors'];
    if (errors is List && errors.isNotEmpty) return errors.first.toString();

    // Validation's own summary is vague on its own ("One or more validation
    // errors occurred"), so the field messages beneath it say more. They also
    // reach the form through [_fieldErrors].
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      return first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
    }

    final title = envelope['title']?.toString();
    return (title != null && title.isNotEmpty) ? title : null;
  }

  Map<String, String> _fieldErrors(Json envelope) {
    // Accept field maps alongside ASP.NET validation errors. Auth errors
    // can also be a flat list, handled in [_message].
    final fields = envelope['errors'] is Map
        ? envelope['errors']
        : envelope['fields'];
    if (fields is! Map) return const {};

    return fields.map(
      (key, value) => MapEntry(
        // Validation names a field as the DTO property does — `Password` —
        // while the form knows it as it was sent, `password`.
        _lowerFirst(key.toString()),
        value is List && value.isNotEmpty
            ? value.first.toString()
            : value.toString(),
      ),
    );
  }

  String _lowerFirst(String value) =>
      value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);

  Failure _failureFromDio(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkFailure(
      'The connection timed out. Check your network and try again.',
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => const NetworkFailure(),
    DioExceptionType.cancel => const UnknownFailure(
      'The request was cancelled.',
    ),
    DioExceptionType.badCertificate => const NetworkFailure(
      'The connection is not secure.',
    ),
    DioExceptionType.badResponse => _failureFromResponse(
      e.response?.statusCode ?? 500,
      e.response?.data,
      path: e.requestOptions.path,
    ),
    _ => const UnknownFailure(),
  };
}
