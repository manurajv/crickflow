import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/generated/admin_localizations.dart';
import '../locale/admin_locale_catalog.dart';

/// MaterialApp localization wiring for both admin host apps.
abstract final class AdminL10nConfig {
  static List<Locale> get supportedLocales =>
      AdminLocaleCatalog.materialSupported;

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AdminLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Prefer explicit override, then device match, else English.
  static Locale? resolutionCallback(
    Locale? locale,
    Iterable<Locale> supported,
  ) {
    if (locale == null) return const Locale('en');
    for (final s in supported) {
      if (s.languageCode == locale.languageCode) return s;
    }
    return const Locale('en');
  }
}
