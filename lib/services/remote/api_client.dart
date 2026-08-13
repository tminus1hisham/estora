import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../storage/token_store.dart';
import '../json.dart';
import 'endpoints.dart';

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
  Future<Result<void>> command(
    String path, {
    Json? body,
    String method = 'POST',
    String? idempotencyKey,
  }) => _send<void>(
    path,
    method: method,
    body: body,
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

      if (status == 401 && !isRetry) {
        final refreshed = await _refresh();
        if (refreshed == null) {
          onAuthLost?.call();
          return const Err(UnauthorizedFailure());
        }
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

      if (status >= 400) return Err(_failureFromResponse(status, response.data));

      final data = response.data;
      final json = switch (data) {
        // The documented envelope: the payload under `data`, list metadata
        // alongside it.
        Map<String, dynamic> map when map.containsKey('data') =>
          map['data'] is Map<String, dynamic>
              ? map['data'] as Json
              : <String, dynamic>{'data': map['data'], 'meta': map['meta']},
        Map<String, dynamic> map => map,
        _ => <String, dynamic>{},
      };

      return Ok(parse(json));
    } on DioException catch (e) {
      return Err(_failureFromDio(e));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
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
    if (tokens == null) return null;

    try {
      final response = await _dio.post<dynamic>(
        Endpoints.refresh,
        data: {'refreshToken': tokens.refreshToken},
        options: Options(headers: {'Authorization': null}),
      );

      if ((response.statusCode ?? 0) >= 400) {
        await _tokenStore.clear();
        return null;
      }

      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? (data['data'] as Json? ?? data)
          : <String, dynamic>{};

      final access = payload['accessToken']?.toString();
      final refresh = payload['refreshToken']?.toString();
      final expiresAt = DateTime.tryParse(
        payload['expiresAt']?.toString() ?? '',
      );
      if (access == null || refresh == null || expiresAt == null) {
        await _tokenStore.clear();
        return null;
      }

      final updated = AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt,
      );
      await _tokenStore.write(updated);
      return updated;
    } on DioException {
      // A network blip is not a reason to destroy the session; only an explicit
      // rejection above clears the tokens.
      return null;
    }
  }

  Failure _failureFromResponse(int status, Object? data) {
    final envelope = data is Map<String, dynamic>
        ? (data['error'] as Json? ?? data)
        : const <String, dynamic>{};
    final message = envelope['message']?.toString();

    return switch (status) {
      400 => ValidationFailure(
        message ?? 'That request could not be processed.',
        fieldErrors: _fieldErrors(envelope),
      ),
      401 => UnauthorizedFailure(
        message ?? 'Your session has expired. Please sign in again.',
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

  Map<String, String> _fieldErrors(Json envelope) {
    final fields = envelope['fields'];
    if (fields is! Map) return const {};
    return fields.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List ? value.first.toString() : value.toString(),
      ),
    );
  }

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
    ),
    _ => const UnknownFailure(),
  };
}
