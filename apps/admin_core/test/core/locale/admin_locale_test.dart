import 'package:crickflow_admin_core/core/l10n/admin_search_i18n.dart';
import 'package:crickflow_admin_core/core/locale/admin_locale_catalog.dart';
import 'package:crickflow_admin_core/core/locale/admin_regional_settings.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminLocaleCatalog', () {
    test('RTL detection for Arabic', () {
      expect(AdminLocaleCatalog.isRtl(const Locale('ar')), isTrue);
      expect(AdminLocaleCatalog.isRtl(const Locale('en')), isFalse);
    });

    test('materialSupported includes primary languages', () {
      final codes = AdminLocaleCatalog.materialSupported
          .map((l) => l.languageCode)
          .toSet();
      expect(codes, containsAll(['en', 'si', 'ta', 'hi', 'ar']));
    });
  });

  group('AdminSearchI18n', () {
    test('normalize collapses whitespace and lowercases latin', () {
      expect(AdminSearchI18n.normalize('  Foo   BAR '), 'foo bar');
    });

    test('matches is substring based', () {
      expect(AdminSearchI18n.matches('Colombo Grounds', 'ground'), isTrue);
      expect(AdminSearchI18n.matches('Colombo', 'xyz'), isFalse);
    });
  });

  group('AdminRegionalSettings', () {
    test('round-trips prefs map', () {
      const original = AdminRegionalSettings(
        languageCode: 'si',
        timeZoneMode: AdminTimeZoneMode.utc,
        dateFormat: AdminDateFormatStyle.iso,
        timeFormat: AdminTimeFormat.h12,
      );
      final restored =
          AdminRegionalSettings.fromPrefsMap(original.toPrefsMap());
      expect(restored, original);
    });
  });
}
