import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences for admin login UX (email remember / theme later).
class SessionPreferences {
  static const _emailKey = 'admin.remembered_email';
  static const _rememberKey = 'admin.remember_me';

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

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_rememberKey);
  }
}
