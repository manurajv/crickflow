import 'package:flutter/material.dart';

/// Catalog of admin UI languages and regional expansion roadmap.
///
/// Fully translated UI: [en], [si], [ta], [hi].
/// RTL layout ready (English copy until translators fill ARBs): [ar].
/// Planned (formats only until ARBs ship): fr, es, zh, ja, de, pt, ur, he.
abstract final class AdminLocaleCatalog {
  static const Locale english = Locale('en');
  static const Locale sinhala = Locale('si');
  static const Locale tamil = Locale('ta');
  static const Locale hindi = Locale('hi');
  static const Locale arabic = Locale('ar');

  /// Locales with ARB resources (MaterialApp supportedLocales).
  static const List<Locale> materialSupported = [
    english,
    sinhala,
    tamil,
    hindi,
    arabic,
  ];

  /// Locales that should flip [TextDirection] (RTL).
  static const Set<String> rtlLanguageCodes = {'ar', 'he', 'ur', 'fa'};

  static bool isRtl(Locale locale) =>
      rtlLanguageCodes.contains(locale.languageCode);

  /// Selectable languages in the account menu (includes system).
  static const List<AdminLanguageOption> selectable = [
    AdminLanguageOption(code: null, nativeName: 'System / Browser', englishName: 'Automatic'),
    AdminLanguageOption(code: 'en', nativeName: 'English', englishName: 'English'),
    AdminLanguageOption(code: 'si', nativeName: 'සිංහල', englishName: 'Sinhala'),
    AdminLanguageOption(code: 'ta', nativeName: 'தமிழ்', englishName: 'Tamil'),
    AdminLanguageOption(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi'),
    AdminLanguageOption(code: 'ar', nativeName: 'العربية', englishName: 'Arabic (RTL)'),
  ];

  /// Future expansion — not yet in MaterialApp; date/number format locale only.
  static const List<AdminLanguageOption> planned = [
    AdminLanguageOption(code: 'fr', nativeName: 'Français', englishName: 'French'),
    AdminLanguageOption(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
    AdminLanguageOption(code: 'de', nativeName: 'Deutsch', englishName: 'German'),
    AdminLanguageOption(code: 'pt', nativeName: 'Português', englishName: 'Portuguese'),
    AdminLanguageOption(code: 'zh', nativeName: '中文', englishName: 'Chinese'),
    AdminLanguageOption(code: 'ja', nativeName: '日本語', englishName: 'Japanese'),
    AdminLanguageOption(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
    AdminLanguageOption(code: 'he', nativeName: 'עברית', englishName: 'Hebrew'),
  ];

  static Locale? tryParse(String? code) {
    if (code == null || code.trim().isEmpty || code == 'system') return null;
    final c = code.trim().toLowerCase().split(RegExp(r'[_-]')).first;
    if (c.isEmpty || c == 'und') return null;
    for (final loc in materialSupported) {
      if (loc.languageCode == c) return loc;
    }
    // Planned / unknown codes must not construct Locale(c) — empty or exotic
    // codes crash Flutter web (`Incorrect locale information provided`).
    return null;
  }

  /// Device/browser locale that is always safe for MaterialApp / intl.
  static Locale safeDeviceLocale() {
    try {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;
      for (final loc in locales) {
        final code = loc.languageCode.trim().toLowerCase();
        // Reject empty, und, and anything that is not a plain ISO 639 code
        // (headless Chromium can surface variants that already crashed Locale).
        if (code.isEmpty || code == 'und') continue;
        if (!RegExp(r'^[a-z]{2,3}$').hasMatch(code)) continue;
        for (final supported in materialSupported) {
          if (supported.languageCode == code) return supported;
        }
        // Unknown but well-formed → English (MaterialApp has ARBs only for
        // [materialSupported]).
        return english;
      }
    } catch (_) {
      // Headless browsers / odd environments can throw on Locale construction.
    }
    return english;
  }
}

@immutable
class AdminLanguageOption {
  const AdminLanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  /// Null = follow browser / OS.
  final String? code;
  final String nativeName;
  final String englishName;
}
