import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Developer-facing diagnostics.
///
/// The app deliberately shows a tenant nothing but the tidied message on a
/// `Failure`, which is right for them and useless for whoever is holding the
/// handset trying to work out why a figure is wrong. This is the other half:
/// the transport's own account of what it sent, what came back, and how long
/// it took, written where only a developer can see it.
///
/// Three rules hold everywhere this is used.
///
/// **Nothing is logged in release.** [enabled] is [kDebugMode], and the
/// expensive callers — the Dio interceptor especially — are not even installed
/// unless it is true, so a release build does not format a payload it will
/// then throw away.
///
/// **Secrets are reduced to their shape, not dropped.** A redacted value is
/// replaced by its length, because the bug is almost never the content of a
/// token and quite often that the token is empty, truncated, or the stale one.
/// Losing the key entirely would hide exactly that.
///
/// **Output goes through [debugPrint].** `dart:developer`'s `log` is the
/// tidier instrument — DevTools can filter it by channel — but it is routed
/// through the VM service and is quietly dropped by consoles that are not
/// listening, `flutter test` among them. A diagnostic nobody can see is not a
/// diagnostic, so entries take the plainer route that reaches the `flutter
/// run` terminal and the IDE console alike, and carry a `[mall.<scope>]`
/// prefix so a console filter or a `grep` can still pick out one channel.
class DebugLog {
  const DebugLog._();

  /// The master switch.
  ///
  /// Left writable for the two callers that need it off while [kDebugMode] is
  /// on: `test/flutter_test_config.dart`, which silences the suite, and any
  /// test driving the real `ApiClient` that would rather not push a few
  /// hundred lines through the runner.
  static bool enabled = kDebugMode;

  /// Long payloads are cut here. Generous enough for an invoice or a unit
  /// list, short enough that one response does not bury the next.
  static const int maxDetailLength = 1200;

  /// Key fragments whose values never reach the log intact.
  ///
  /// Matched against the key with punctuation and case removed, so
  /// `refreshToken`, `refresh_token` and `Refresh-Token` are all caught by
  /// `token`. `signature` earns its place twice over: the drawn lease
  /// signature is a secret *and* a base64 image that would flood the log.
  static const Set<String> sensitiveKeyFragments = {
    'authorization',
    'cookie',
    'credential',
    'otp',
    'password',
    'pincode',
    'secret',
    'signature',
    'token',
  };

  /// Writes one entry under [scope].
  ///
  /// [detail] is run through [describe] — redacted, encoded and truncated — so
  /// callers can hand over a raw request body without thinking about it.
  static void write(
    String scope,
    String message, {
    Object? detail,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;

    final entry = StringBuffer('[mall.$scope] $message');
    if (detail != null) entry.write('\n${describe(detail)}');
    if (error != null) entry.write('\n  error: $error');
    if (stackTrace != null) entry.write('\n$stackTrace');

    debugPrint(entry.toString());
  }

  /// [value] as a single readable, redacted, length-capped string.
  static String describe(Object? value) {
    if (value == null) return 'null';

    final redacted = redact(value);
    final text = redacted is String ? redacted : _encode(redacted);
    return text.length <= maxDetailLength
        ? text
        : '${text.substring(0, maxDetailLength)}'
              '… (${text.length - maxDetailLength} more characters)';
  }

  /// Recursively replaces the values of sensitive keys, leaving the structure
  /// intact so the shape of a body is still legible.
  static Object? redact(Object? value) => switch (value) {
    Map<Object?, Object?> map => <String, Object?>{
      for (final MapEntry(:key, :value) in map.entries)
        key.toString(): isSensitiveKey(key.toString())
            ? maskSecret(value)
            : redact(value),
    },
    // Strings and the other scalars are not unpacked: a bare value has no key
    // to judge it by, and the keyed case above has already handled the ones
    // that matter.
    Iterable<Object?> items => items.map(redact).toList(),
    _ => value,
  };

  /// What is printed in place of a secret: enough to tell a missing token from
  /// a present one, and a truncated one from a whole one.
  static String maskSecret(Object? value) {
    if (value == null) return '<absent>';
    final text = value.toString();
    return text.isEmpty ? '<empty>' : '<redacted, ${text.length} chars>';
  }

  static bool isSensitiveKey(String key) {
    final normalised = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    return sensitiveKeyFragments.any(normalised.contains);
  }

  /// Pretty JSON where the value allows it. Anything the encoder cannot take —
  /// a `DateTime`, an entity, an enum — falls back to its `toString` rather
  /// than throwing, because a logger that can fail is a logger that takes the
  /// app down over a diagnostic.
  static String _encode(Object? value) =>
      JsonEncoder.withIndent('  ', (object) => object.toString()).convert(value);
}
