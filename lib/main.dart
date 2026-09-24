import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/debug/debug_log.dart';
import 'services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before the app starts so the rest of the provider graph — the token
  // store and the persisted idempotency keys — can depend on it synchronously.
  final prefs = await SharedPreferences.getInstance();

  // The two things a build can be asked to do differently, written where
  // whoever is holding the handset can check them: which server this build
  // talks to, and whether the three unserved screens are on fixtures.
  DebugLog.write(
    'config',
    'API ${AppConfig.apiRoot}; demo data '
        '${AppConfig.demoData ? 'ON (--dart-define=DEMO_DATA=true)' : 'off'}',
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const EstoraApp(),
    ),
  );
}
