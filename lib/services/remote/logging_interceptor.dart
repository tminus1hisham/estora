import 'package:dio/dio.dart';

import '../../core/debug/debug_log.dart';

/// Logs each request and whatever became of it.
///
/// `ApiClient` installs this only when `DebugLog.enabled`, so none of the
/// formatting below runs in a release build.
///
/// Every line carries a sequence number — `#12` — because requests overlap.
/// The dashboard alone fans out into several at once, and without the number
/// there is no telling which response belongs to which request, nor which of
/// them the 404 came from.
///
/// The arrows read: `→` sent, `←` answered, `✗` never answered.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.logPayloads = true});

  /// Whether request and response bodies are logged, or only the status line
  /// and timing.
  ///
  /// A rejection is logged either way: a 4xx body is the server explaining
  /// itself, which is the one payload always worth having.
  final bool logPayloads;

  static const String _idKey = 'debugLogSequence';
  static const String _clockKey = 'debugLogClock';

  static int _sequence = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = ++_sequence;
    options.extra[_idKey] = id;
    options.extra[_clockKey] = Stopwatch()..start();

    DebugLog.write('http', '→ #$id ${options.method} ${_target(options)}');

    if (logPayloads) {
      final headers = _notableHeaders(options);
      if (headers.isNotEmpty) {
        DebugLog.write('http', '  #$id headers', detail: headers);
      }

      final body = _loggableBody(options.data);
      if (body != null) {
        DebugLog.write('http', '  #$id body', detail: body);
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final status = response.statusCode ?? 0;
    final line =
        '← #${_id(options)} $status ${options.method} ${_target(options)} '
        'in ${_elapsed(options)}';

    // The client's `validateStatus` lets everything under 500 through as a
    // response rather than an exception, so a 400, a 401 and a 404 all arrive
    // here and not in [onError]. They are the interesting ones, and their body
    // is logged whatever the verbosity.
    if (status >= 400) {
      DebugLog.write('http', '$line — rejected', detail: response.data);
    } else {
      DebugLog.write(
        'http',
        line,
        detail: logPayloads ? _loggableBody(response.data) : null,
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;

    DebugLog.write(
      'http',
      '✗ #${_id(options)} ${options.method} ${_target(options)} '
      'gave up after ${_elapsed(options)} (${err.type.name})',
      detail: err.response?.data,
      error: err.error ?? err.message ?? err.type.name,
      stackTrace: err.stackTrace,
    );

    handler.next(err);
  }

  /// The path as the contract names it, with the query string appended —
  /// redacted, since a reset-password link carries its token there.
  ///
  /// The host is left off: it is the same one all day and only pushes the
  /// interesting half of the line off the edge of the console.
  String _target(RequestOptions options) {
    final query = options.queryParameters;
    if (query.isEmpty) return options.path;

    final redacted = DebugLog.redact(query);
    final pairs = redacted is Map<String, Object?>
        ? redacted.entries.map((entry) => '${entry.key}=${entry.value}')
        : <String>[];
    return '${options.path}?${pairs.join('&')}';
  }

  /// The three headers that explain a request's fate.
  ///
  /// `Authorization` answers "was this sent signed in, and with which token";
  /// `Idempotency-Key` answers "would the server treat a retry of this as the
  /// same intent" (section 66); the content type catches a JSON body sent as a
  /// form or the reverse.
  Map<String, Object?> _notableHeaders(RequestOptions options) {
    const wanted = {'authorization', 'idempotency-key', 'content-type'};
    return <String, Object?>{
      for (final MapEntry(:key, :value) in options.headers.entries)
        if (value != null && wanted.contains(key.toLowerCase()))
          key: DebugLog.isSensitiveKey(key) ? DebugLog.maskSecret(value) : value,
    };
  }

  /// A body the log can hold.
  ///
  /// Multipart is summarised rather than printed: an uploaded lease scan is
  /// megabytes of bytes, and what a developer needs from it is the field names,
  /// the file name, the type and the size — which is also exactly what the
  /// server rejects an upload over.
  Object? _loggableBody(Object? data) => switch (data) {
    null => null,
    FormData form => <String, Object?>{
      'fields': <String, Object?>{
        for (final field in form.fields) field.key: field.value,
      },
      'files': <String>[
        for (final file in form.files)
          '${file.key}: ${file.value.filename ?? '<unnamed>'} '
              '(${file.value.contentType ?? 'no content type'}, '
              '${file.value.length} bytes)',
      ],
    },
    _ => data,
  };

  Object _id(RequestOptions options) => options.extra[_idKey] ?? '?';

  String _elapsed(RequestOptions options) {
    final clock = options.extra[_clockKey];
    return clock is Stopwatch ? '${clock.elapsedMilliseconds}ms' : 'unknown time';
  }
}
