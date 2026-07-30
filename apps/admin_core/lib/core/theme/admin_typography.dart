import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_colors.dart';

/// Named type roles on top of Material 3 + Plus Jakarta Sans.
///
/// Use these helpers for consistency; prefer Theme.of(context).textTheme
/// roles where they already match (titleMedium, bodyMedium, etc.).
abstract final class AdminTypography {
  static TextTheme textTheme(TextTheme base, AdminColors colors) {
    final themed = GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return themed.copyWith(
      displayLarge: themed.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displayMedium: themed.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineLarge: themed.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      headlineMedium: themed.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      headlineSmall: themed.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: themed.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: themed.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleSmall: themed.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      bodyLarge: themed.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: themed.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodySmall: themed.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: colors.textSecondary,
      ),
      labelLarge: themed.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: themed.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: themed.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: colors.textMuted,
      ),
    );
  }

  /// KPI / statistic number style.
  static TextStyle? statistic(BuildContext context, {bool compact = false}) {
    final theme = Theme.of(context).textTheme;
    return (compact ? theme.titleLarge : theme.headlineMedium)?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );
  }

  /// Compact table cell text.
  static TextStyle? table(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        );
  }

  /// Sidebar section / nav labels.
  static TextStyle? sidebar(BuildContext context, {bool selected = false}) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          fontSize: 13.5,
          color: Colors.white.withValues(alpha: selected ? 1 : 0.86),
        );
  }

  /// Button label.
  static TextStyle? button(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
  }
}
