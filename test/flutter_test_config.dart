import 'dart:async';

import 'package:mall/core/debug/debug_log.dart';

/// Runs once around the whole suite.
///
/// `DebugLog` writes through `debugPrint`, which — unlike `dart:developer` —
/// the test runner shows. That is the point of it in the app and a nuisance
/// here: the acceptance tests alone drive enough of the auth flow to bury a
/// failure under a few hundred lines of diagnostics. A test that wants the
/// logging can turn it back on for its own duration.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DebugLog.enabled = false;
  await testMain();
}
