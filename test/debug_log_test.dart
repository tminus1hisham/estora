import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/debug/debug_log.dart';

/// The two promises the logger makes.
///
/// That an entry is actually visible — it goes through `debugPrint`, which
/// the consoles read, rather than `dart:developer`, which they can silently
/// drop — and that a payload handed to it cannot carry a secret out. The
/// second is the one worth a test: redaction is keyed on the field name, so
/// the day a route starts sending `password` inside a nested object, this
/// fails rather than the password reaching a log file.

void main() {
  final captured = <String>[];
  late DebugPrintCallback original;

  setUp(() {
    captured.clear();
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) captured.add(message);
    };
    DebugLog.enabled = true;
  });

  tearDown(() {
    debugPrint = original;
    DebugLog.enabled = false;
  });

  test('an entry reaches debugPrint under its scope', () {
    DebugLog.write('auth', 'Creating a business tenant account');
    expect(captured.single, '[estora.auth] Creating a business tenant account');
  });

  test('a payload is redacted by key, keeping its shape', () {
    DebugLog.write(
      'http',
      'body',
      detail: {
        'phoneNumber': '254712345678',
        'password': 'hunter2',
        'refreshToken': '',
        'nested': {'accessToken': 'abcdef'},
      },
    );

    final entry = captured.single;
    expect(entry, contains('254712345678'));
    expect(entry, isNot(contains('hunter2')));
    expect(entry, contains('<redacted, 7 chars>'));
    expect(entry, contains('<empty>'));
    expect(entry, isNot(contains('abcdef')));
  });

  test('nothing is written when disabled', () {
    DebugLog.enabled = false;
    DebugLog.write('auth', 'should not appear');
    expect(captured, isEmpty);
  });
}
