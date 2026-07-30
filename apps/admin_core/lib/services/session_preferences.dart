import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale/admin_regional_settings.dart';

/// Local preferences for admin login UX, theme, and regional settings.
class SessionPreferences {
  static const _emailKey = 'admin.remembered_email';
  static const _rememberKey = 'admin.remember_me';
  static const _themeKey = 'admin.theme_mode';
  static const _regionalPrefix = 'admin.regional.';

  Future<void> saveRememberedEmail({
    required bool rememberMe,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);
    if (rememberMe) {
      await prefs.setString(_emailKey, email.trim());
    } else {
      await prefs.remove(_emailKey);
    }
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? true;
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? true)) return null;
    return prefs.getString(_emailKey);
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
  }

  Future<void> saveRegionalSettings(AdminRegionalSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final map = settings.toPrefsMap();
    final keys = prefs.getKeys().where((k) => k.startsWith(_regionalPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
    for (final e in map.entries) {
      await prefs.setString('$_regionalPrefix${e.key}', e.value);
    }
  }

  Future<AdminRegionalSettings> getRegionalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(_regionalPrefix)) continue;
      final v = prefs.getString(k);
      if (v != null) {
        map[k.substring(_regionalPrefix.length)] = v;
      }
    }
    if (map.isEmpty) return AdminRegionalSettings.defaults;
    return AdminRegionalSettings.fromPrefsMap(map);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_rememberKey);
  }
}
