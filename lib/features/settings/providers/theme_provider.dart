import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/preferences/shared_prefs_service.dart';

/// Notifier that manages and persists the app theme mode.
/// SharedPrefsService must be initialized before this runs (done in main.dart).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_loadInitial());

  /// Read the persisted value synchronously (SharedPrefsService is already init'd).
  static ThemeMode _loadInitial() {
    switch (SharedPrefsService.themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// Toggle between light and dark mode.
  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await SharedPrefsService.setThemeMode(_modeToString(next));
    state = next;
  }

  /// Explicitly set a theme mode.
  Future<void> setMode(ThemeMode mode) async {
    await SharedPrefsService.setThemeMode(_modeToString(mode));
    state = mode;
  }

  static String _modeToString(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      };
}

/// Global provider for the app theme mode.
/// Watch this in MaterialApp to apply light/dark switching.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

/// Convenience computed provider: true when currently in dark mode.
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeModeProvider) == ThemeMode.dark;
});
