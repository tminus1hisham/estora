import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

/// Plain-preferences token storage.
///
/// This exists so the app can be run and demoed on desktop and web, where
/// `flutter_secure_storage` either has no platform implementation or offers no
/// meaningful protection anyway.
///
/// It is **not** secure and must never be selected on Android or iOS —
/// [tokenStoreForPlatform] enforces that.
class PrefsTokenStore implements TokenStore {
  PrefsTokenStore(this._prefs);

  final SharedPreferences _prefs;

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';
  static const _expiryKey = 'auth.expires_at';
  static const _biometricKey = 'auth.biometric_enabled';

  @override
  Future<AuthTokens?> read() async {
    final access = _prefs.getString(_accessKey);
    final refresh = _prefs.getString(_refreshKey);
    final expiry = _prefs.getString(_expiryKey);
    if (access == null || refresh == null || expiry == null) return null;

    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null) return null;

    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _prefs.setString(_accessKey, tokens.accessToken);
    await _prefs.setString(_refreshKey, tokens.refreshToken);
    await _prefs.setString(_expiryKey, tokens.expiresAt.toIso8601String());
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
    await _prefs.remove(_expiryKey);
    await _prefs.remove(_biometricKey);
  }

  @override
  Future<bool> isBiometricEnabled() async =>
      _prefs.getBool(_biometricKey) ?? false;

  @override
  Future<void> setBiometricEnabled(bool enabled) =>
      _prefs.setBool(_biometricKey, enabled);
}
