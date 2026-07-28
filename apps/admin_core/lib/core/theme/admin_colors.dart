import 'package:flutter/material.dart';

/// CrickFlow brand tokens for admin SaaS dashboards.
@immutable
class AdminColors extends ThemeExtension<AdminColors> {
  const AdminColors({
    required this.isLight,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.sidebar,
    required this.sidebarHover,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final bool isLight;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color sidebar;
  final Color sidebarHover;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryBlueLight = Color(0xFF42A5F5);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFFFA000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkGray = Color(0xFF263238);

  static const light = AdminColors(
    isLight: true,
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    sidebar: Color(0xFF0F172A),
    sidebarHover: Color(0xFF1E293B),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    success: Color(0xFF43A047),
    warning: Color(0xFFFFA000),
    error: Color(0xFFE53935),
    info: primaryBlue,
  );

  static const dark = AdminColors(
    isLight: false,
    background: Color(0xFF0A0E17),
    surface: Color(0xFF141B2D),
    surfaceElevated: Color(0xFF1E2940),
    sidebar: Color(0xFF0A0E17),
    sidebarHover: Color(0xFF1A2332),
    card: Color(0xFF1A2332),
    border: Color(0xFF2A3F5F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    textMuted: Color(0xFF78909C),
    success: Color(0xFF66BB6A),
    warning: gold,
    error: Color(0xFFEF5350),
    info: primaryBlueLight,
  );

  @override
  AdminColors copyWith({
    bool? isLight,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? sidebar,
    Color? sidebarHover,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return AdminColors(
      isLight: isLight ?? this.isLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      sidebar: sidebar ?? this.sidebar,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  AdminColors lerp(ThemeExtension<AdminColors>? other, double t) {
    if (other is! AdminColors) return this;
    return t < 0.5 ? this : other;
  }
}
