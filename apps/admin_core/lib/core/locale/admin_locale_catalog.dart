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
    final c = code.trim().toLowerCase();
    for (final loc in materialSupported) {
      if (loc.languageCode == c) return loc;
    }
    return Locale(c);
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
