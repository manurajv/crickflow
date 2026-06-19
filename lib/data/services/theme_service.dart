import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/prefs_keys.dart';

/// Persists and restores the user's theme preference locally.
class ThemeService {
  ThemeService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Reads saved theme synchronously when [prefs] was injected at startup.
  ThemeMode readThemeMode([SharedPreferences? prefs]) {
    final storage = prefs ?? _prefs;
    if (storage == null) return ThemeMode.light;
    final raw = storage.getString(PrefsKeys.themeMode);
    return _parseThemeMode(raw) ?? ThemeMode.light;
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _storage;
    return readThemeMode(prefs);
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _storage;
    await prefs.setString(PrefsKeys.themeMode, _themeModeToString(mode));
  }

  /// Future-ready: system theme is stored but not exposed in UI yet.
  static ThemeMode? _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
