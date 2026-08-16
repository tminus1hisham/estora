import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../services/providers.dart';

/// A demo-only switch that shows the owner side of the app to a tenant account.
///
/// Section 88 gives an account one role, and in a real deployment that is the
/// whole story — you are an owner or you are a tenant, and the router sends you
/// where you belong. But a demo has one device and two audiences to show, and
/// signing out and back in to see the other half makes the point badly.
///
/// Gated on [AppConfig.isMock] in the controller itself rather than only at the
/// call sites, so pointing the app at a real server disables it even if a
/// screen forgets to check. The stored preference survives a restart, which
/// matters when the thing being demonstrated is a launch.
final viewAsOwnerProvider = NotifierProvider<ViewAsOwnerController, bool>(
  ViewAsOwnerController.new,
);

class ViewAsOwnerController extends Notifier<bool> {
  static const _key = 'demo:view-as-owner';

  @override
  bool build() {
    if (!AppConfig.isMock) return false;
    return _prefs?.getBool(_key) ?? false;
  }

  Future<void> set({required bool value}) async {
    if (!AppConfig.isMock) return;
    state = value;
    await _prefs?.setBool(_key, value);
  }

  Future<void> toggle() => set(value: !state);

  /// Preferences, or null if they are not available in this scope.
  ///
  /// The same degradation [ThemeModeController] performs, and for a stronger
  /// reason. The router's redirect reads this provider on every navigation, so
  /// it now sits on the path of every frame the app draws. A widget harness
  /// that renders a screen without providing the preference override — there
  /// are several in `test/` — would otherwise be taken down by a demo toggle,
  /// which is an absurd thing to be able to crash an app.
  ///
  /// Broad on purpose: Riverpod wraps a failing provider in a
  /// ProviderException and then marks it errored, so catching the underlying
  /// UnimplementedError would miss both.
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }
}
