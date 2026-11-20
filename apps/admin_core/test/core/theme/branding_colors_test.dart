import 'package:crickflow_admin_core/core/theme/branding_colors.dart';
import 'package:crickflow_admin_core/features/settings/models/platform_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCssHexColor', () {
    test('parses #RRGGBB', () {
      expect(parseCssHexColor('#1565C0'), const Color(0xFF1565C0));
    });

    test('parses shorthand and bare hex', () {
      expect(parseCssHexColor('#0F0'), const Color(0xFF00FF00));
      expect(parseCssHexColor('1E88E5'), const Color(0xFF1E88E5));
    });

    test('rejects invalid values', () {
      expect(parseCssHexColor(''), isNull);
      expect(parseCssHexColor('blue'), isNull);
      expect(parseCssHexColor('#12'), isNull);
      expect(parseCssHexColor(null), isNull);
    });
  });

  test('brandingColorsFor returns nulls when branding is missing', () {
    final colors = brandingColorsFor(null, isDark: false);
    expect(colors.primary, isNull);
    expect(colors.secondary, isNull);
  });

  test('brandingColorsFor uses light and dark fields', () {
    const branding = PlatformBrandingSettings(
      lightPrimary: '#112233',
      darkPrimary: '#AABBCC',
      lightAccent: '#FF0000',
      darkAccent: '#00FF00',
      accentColor: '#0000FF',
    );
    expect(brandingColorsFor(branding, isDark: false).primary, const Color(0xFF112233));
    expect(brandingColorsFor(branding, isDark: true).primary, const Color(0xFFAABBCC));
    expect(brandingColorsFor(branding, isDark: false).accent, const Color(0xFFFF0000));
    expect(brandingColorsFor(branding, isDark: true).accent, const Color(0xFF00FF00));
  });
}
