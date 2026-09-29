/// Persisted [ThemeMode] (System / Dark / Light).
///
/// [sharedPreferencesProvider] is overridden in `main.dart` with an instance
/// already loaded before `runApp`, so [ThemeModeNotifier.build] can read the
/// stored value synchronously — the very first frame already uses the right
/// theme (no light/dark flash on launch).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main.dart` with the pre-loaded [SharedPreferences].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// Active theme mode; persists to [SharedPreferences].
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// SharedPreferences key; values are `system` | `dark` | `light`.
  static const String key = 'gymly.theme_mode';

  @override
  ThemeMode build() =>
      _decode(ref.read(sharedPreferencesProvider).getString(key));

  /// Applies [mode] and persists it. No-op when unchanged.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(key, _encode(mode));
  }

  static ThemeMode _decode(String? raw) => switch (raw) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };
}
