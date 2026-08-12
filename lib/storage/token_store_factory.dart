import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_token_store.dart';
import 'secure_token_store.dart';
import 'token_store.dart';

/// Picks the right [TokenStore] for the platform the app is running on.
///
/// Android and iOS are the real targets and always get the keychain/keystore
/// backed store. Web and desktop fall back to preferences purely so the app is
/// runnable for development and demos — see [PrefsTokenStore] for the caveat.
TokenStore tokenStoreForPlatform(SharedPreferences prefs) {
  if (kIsWeb) return PrefsTokenStore(prefs);

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => SecureTokenStore(),
    _ => PrefsTokenStore(prefs),
  };
}
