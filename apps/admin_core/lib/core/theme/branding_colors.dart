import 'package:flutter/material.dart';

import '../../features/settings/models/platform_settings.dart';

/// Parses a CSS hex color (`#RGB`, `#RRGGBB`, or `#AARRGGBB`).
Color? parseCssHexColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    s = s.split('').map((c) => '$c$c').join();
  }
  if (s.length != 6 && s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  if (s.length == 6) return Color(0xFF000000 | value);
  return Color(value);
}

class BrandingThemeColors {
  const BrandingThemeColors({this.primary, this.secondary, this.accent});

  final Color? primary;
  final Color? secondary;
  final Color? accent;
}

/// Resolves branding colors for the Super Admin panel.
/// Returns nulls when the document has no usable hex values (keep built-in theme).
BrandingThemeColors brandingColorsFor(
  PlatformBrandingSettings? branding, {
  required bool isDark,
}) {
  if (branding == null) return const BrandingThemeColors();
  final primary = parseCssHexColor(
        isDark ? branding.darkPrimary : branding.lightPrimary,
      ) ??
      parseCssHexColor(branding.primaryColor);
  final secondary = parseCssHexColor(
        isDark ? branding.darkSecondary : branding.lightSecondary,
      ) ??
      parseCssHexColor(branding.secondaryColor);
  final accent = parseCssHexColor(
        isDark ? branding.darkAccent : branding.lightAccent,
      ) ??
      parseCssHexColor(branding.accentColor);
  return BrandingThemeColors(
    primary: primary,
    secondary: secondary,
    accent: accent,
  );
}
