import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/providers.dart';

/// The tenant's appearance choice, remembered across launches.
///
/// The app follows the system by default, which is the right default. It is
/// not sufficient on its own: dark mode is fully built here, and without an
/// in-app control the only way to see it is to leave the app and change an OS
/// setting.
///
/// Stored in plain preferences rather than with the tokens — it is a display
/// preference, survives sign-out, and belongs to the device rather than to the
/// tenant's session.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'appearance.theme_mode';

  @override
  ThemeMode build() => _decode(_prefs?.getString(_key));

  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _prefs?.setString(_key, mode.name);
  }

  /// Preferences, or null if they are not available in this scope.
  ///
  /// This provider is read while `MaterialApp` is being built, which puts it
  /// on the path of every frame the app will ever draw. Letting a missing
  /// preference store throw here would mean an unreadable display setting
  /// takes down the entire app rather than falling back to following the
  /// system — so it degrades instead. `main()` always provides the override;
  /// a harness that only wants to render a screen need not.
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      // Deliberately broad. Riverpod wraps a failing provider in a
      // ProviderException, so catching the underlying UnimplementedError here
      // would miss it, and there is no failure to read a display preference
      // that should be worth more than falling back to the system setting.
      return null;
    }
  }

  static ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// How the current choice is described in the UI.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  IconData get icon => switch (this) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };
}
